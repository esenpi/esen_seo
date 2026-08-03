import 'package:esen_seo/server.dart';
import 'package:flutter_test/flutter_test.dart';

const _base = 'https://x.dev';

Future<SeoAuditReport> _audit(
  List<SeoRoute> routes, {
  List<String> additionalPaths = const [],
  SeoAuditPolicy policy = const SeoAuditPolicy(),
}) =>
    auditSeoRoutes(
      routes: routes,
      siteBase: _base,
      additionalPaths: additionalPaths,
      policy: policy,
    );

/// The ids the report actually raised — comparing ids rather than
/// prose keeps these tests from breaking on wording changes.
Set<String> _ids(SeoAuditReport r) => {for (final f in r.findings) f.check.id};

/// A route with enough metadata to pass the checks under test, so a
/// case only ever fires the finding it is about.
SeoRoute _ok(String path, {String? title, List<SeoNode>? body}) => SeoRoute(
      path: path,
      meta: (_) => SeoMeta(
        title: title ?? 'A perfectly ordinary page title',
        description: 'A description long enough to sit inside the window '
            'that search engines actually show to a reader.',
      ),
      body: (_) => body ?? [SeoNode(tag: 'h1', text: 'Heading')],
    );

void main() {
  group('the four defects that justify the audit', () {
    // Each of these is a legal use of the API that the renderer cannot
    // refuse — which is exactly why a separate audit has to exist.

    test('noindex page still listed in the sitemap', () async {
      final report = await _audit([
        SeoRoute(
          path: '/geheim',
          meta: (_) => const SeoMeta(title: 'Geheim', robots: 'noindex'),
          body: (_) => [SeoNode(tag: 'h1', text: 'Geheim')],
        ),
      ]);
      expect(_ids(report), contains('robots.noindex-in-sitemap'));
      // And the contradiction is real: the sitemap does list it.
      final xml = seoSitemapXml(
        routes: [
          SeoRoute(
            path: '/geheim',
            meta: (_) => const SeoMeta(title: 'G', robots: 'noindex'),
          ),
        ],
        siteBase: _base,
      );
      expect(xml, contains('/geheim'));
    });

    test('a concrete route shadowed by an earlier :param pattern', () async {
      final routes = [
        SeoRoute(
          path: '/blog/:slug',
          meta: (p) => SeoMeta(title: 'Post ${p['slug']}'),
        ),
        _ok('/blog/archive', title: 'The blog archive page'),
      ];
      final report = await _audit(routes);
      expect(_ids(report), contains('route.shadowed'));
      // The shadowing is real: the concrete route never runs.
      final match = matchSeoRoute(routes, '/blog/archive')!;
      final doc = match.resolveSync()! as SeoDocument;
      expect(doc.meta.title, 'Post archive');
    });

    test('a canonical the URL policy refuses leaves no canonical at all',
        () async {
      final report = await _audit([
        SeoRoute(
          path: '/p',
          meta: (_) => const SeoMeta(
            title: 'A product page with a bad canonical',
            canonicalUrl: 'javascript:alert(1)',
          ),
        ),
      ]);
      expect(_ids(report), contains('url.rejected-by-policy'));
      // Worse than nothing: the head has no canonical, and the
      // non-null value also suppressed the derived one.
      final match = matchSeoRoute([
        SeoRoute(
          path: '/p',
          meta: (_) => const SeoMeta(
            title: 'P',
            canonicalUrl: 'javascript:alert(1)',
          ),
        ),
      ], '/p')!;
      final doc = match.resolveSync(canonicalBase: _base)! as SeoDocument;
      expect(doc.meta.toHtml(), isNot(contains('canonical')));
    });

    test('a schema value JSON cannot encode', () async {
      final report = await _audit([
        SeoRoute(
          path: '/rezept',
          meta: (_) => SeoMeta(
            title: 'How to cook a lentil soup',
            schemas: [
              SeoSchema('Recipe', {'cookTime': const Duration(minutes: 45)}),
            ],
          ),
        ),
      ]);
      expect(_ids(report), contains('schema.invalid-json'));
    });
  });

  group('metadata', () {
    test('a missing title is an error, a missing description a warning',
        () async {
      final report = await _audit([
        SeoRoute(path: '/', meta: (_) => const SeoMeta()),
      ]);
      expect(
          _ids(report), containsAll(['title.missing', 'description.missing']));
      expect(
        report.findings
            .firstWhere((f) => f.check == SeoCheck.titleMissing)
            .severity,
        SeoSeverity.error,
      );
      expect(
        report.findings
            .firstWhere((f) => f.check == SeoCheck.descriptionMissing)
            .severity,
        SeoSeverity.warning,
      );
    });

    test('duplicate titles across pages', () async {
      final report = await _audit([
        _ok('/a', title: 'Exactly the same title here'),
        _ok('/b', title: 'Exactly the same title here'),
      ]);
      expect(_ids(report), contains('title.duplicate'));
      // Reported on both pages, so either one leads to the fix.
      expect(
        report.findings.where((f) => f.check == SeoCheck.titleDuplicate).length,
        2,
      );
    });

    test('a noindex page is exempt from the content checks', () async {
      // A deliberately hidden page has no business being nagged about
      // its description.
      final report = await _audit([
        SeoRoute(
          path: '/intern',
          meta: (_) => const SeoMeta(robots: 'noindex'),
          includeInSitemap: false,
        ),
      ]);
      expect(_ids(report), isNot(contains('title.missing')));
      expect(_ids(report), isNot(contains('description.missing')));
    });
  });

  group('structure, images and links', () {
    test('multiple h1 elements', () async {
      final report = await _audit([
        _ok('/', body: [
          SeoNode(tag: 'h1', text: 'Erste'),
          SeoNode(tag: 'h1', text: 'Zweite'),
        ]),
      ]);
      expect(_ids(report), contains('heading.multiple-h1'));
    });

    test('a body with content but no h1', () async {
      final report = await _audit([
        _ok('/', body: [SeoNode(tag: 'p', text: 'Nur ein Absatz')]),
      ]);
      expect(_ids(report), contains('heading.no-h1'));
    });

    test('an image without alt, and one with alt passing', () async {
      final bad = await _audit([
        _ok('/', body: [
          SeoNode(tag: 'h1', text: 'H'),
          SeoNode(tag: 'img', attributes: {'src': '/a.png'}),
        ]),
      ]);
      expect(_ids(bad), contains('image.alt-missing'));

      final good = await _audit([
        _ok('/', body: [
          SeoNode(tag: 'h1', text: 'H'),
          SeoNode(tag: 'img', attributes: {'src': '/a.png', 'alt': 'Ein Foto'}),
        ]),
      ]);
      expect(_ids(good), isNot(contains('image.alt-missing')));
    });

    test('a link to a path no route serves', () async {
      final report = await _audit([
        _ok('/', body: [
          SeoNode(tag: 'h1', text: 'H'),
          SeoNode(tag: 'a', text: 'AGB', attributes: {'href': '/agb'}),
        ]),
      ]);
      expect(_ids(report), contains('link.broken'));
    });

    test('an external link and a :param target are not broken', () async {
      final report = await _audit([
        SeoRoute(
          path: '/blog/:slug',
          meta: (p) => SeoMeta(title: 'Post ${p['slug']}'),
          enumeratePaths: () => ['/blog/a'],
        ),
        _ok('/', body: [
          SeoNode(tag: 'h1', text: 'H'),
          SeoNode(
              tag: 'a',
              text: 'Extern',
              attributes: {'href': 'https://y.dev/x'}),
          SeoNode(tag: 'a', text: 'Post', attributes: {'href': '/blog/a'}),
          SeoNode(tag: 'a', text: 'Anker', attributes: {'href': '#top'}),
        ]),
      ]);
      expect(_ids(report), isNot(contains('link.broken')));
    });

    test('a link with no anchor text', () async {
      final report = await _audit([
        _ok('/', body: [
          SeoNode(tag: 'h1', text: 'H'),
          SeoNode(tag: 'a', attributes: {'href': '/'}),
        ]),
      ]);
      expect(_ids(report), contains('link.no-text'));
    });
  });

  group('hreflang', () {
    test('a one-way cluster is not reciprocal', () async {
      final report = await _audit([
        SeoRoute(
          path: '/de',
          meta: (_) => const SeoMeta(
            title: 'Die deutsche Startseite hier',
            alternates: {'de': '$_base/de', 'en': '$_base/en'},
          ),
        ),
        // /en does not link back.
        _ok('/en', title: 'The English home page here'),
      ]);
      expect(_ids(report), contains('hreflang.not-reciprocal'));
    });

    test('a cluster without the page itself is discarded by Google', () async {
      final report = await _audit([
        SeoRoute(
          path: '/de',
          meta: (_) => const SeoMeta(
            title: 'Die deutsche Startseite hier',
            alternates: {'en': '$_base/en'},
          ),
        ),
        _ok('/en', title: 'The English home page here'),
      ]);
      expect(_ids(report), contains('hreflang.missing-self'));
    });

    test('a well-formed reciprocal cluster is silent', () async {
      const both = {'de': '$_base/de', 'en': '$_base/en'};
      final report = await _audit([
        SeoRoute(
          path: '/de',
          meta: (_) => const SeoMeta(
            title: 'Die deutsche Startseite hier',
            description: 'Eine ausreichend lange Beschreibung, damit dieser '
                'Test nur den hreflang-Teil prüft und nichts anderes.',
            alternates: both,
          ),
        ),
        SeoRoute(
          path: '/en',
          meta: (_) => const SeoMeta(
            title: 'The English home page here',
            description: 'A description long enough that this test only '
                'exercises the hreflang checks and nothing else at all.',
            alternates: both,
          ),
        ),
      ]);
      expect(
        _ids(report).where((id) => id.startsWith('hreflang')),
        isEmpty,
        reason: report.describe(),
      );
    });
  });

  group('the report itself', () {
    test('a resolver failure is reported and suppresses cross-page checks',
        () async {
      // The run must not abort on one bad page — but "this title is
      // unique" is unprovable with a page missing, so those checks are
      // skipped rather than reported wrongly.
      final report = await _audit([
        _ok('/a', title: 'Exactly the same title here'),
        _ok('/b', title: 'Exactly the same title here'),
        SeoRoute.dynamic(
          path: '/boom',
          resolve: (_) async => throw StateError('db down'),
        ),
      ]);
      expect(_ids(report), contains('resolver.failed'));
      expect(report.partial, isTrue);
      expect(
        _ids(report),
        isNot(contains('title.duplicate')),
        reason: 'cross-page checks are unsound on an incomplete set',
      );
      expect(report.describe(), contains('cross-page checks'));
    });

    test('passes() draws the line at severity', () async {
      final clean = await _audit([_ok('/')]);
      expect(clean.passes(), isTrue);
      expect(clean.errorCount, 0);

      final broken = await _audit([
        SeoRoute(path: '/', meta: (_) => const SeoMeta()),
      ]);
      expect(broken.passes(), isFalse);
      expect(broken.passes(threshold: SeoSeverity.error), isFalse);
    });

    test('a policy can silence a check', () async {
      const noisy = SeoAuditPolicy(ignore: {SeoCheck.titleLength});
      final report = await _audit(
        [_ok('/', title: 'Kurz')],
        policy: noisy,
      );
      expect(_ids(report), isNot(contains('title.length')));
    });

    test('findings are ordered worst first and carry a stable id', () async {
      final report = await _audit([
        SeoRoute(path: '/', meta: (_) => const SeoMeta()),
      ]);
      expect(report.findings.first.severity, SeoSeverity.error);
      expect(report.findings.first.fingerprint, startsWith('title.missing|/'));
      expect(report.toJson()['findings'], isA<List<Object?>>());
    });
  });

  group('legitimate sites must not produce errors', () {
    // An error-severity finding on a correct site is the worst bug this
    // tool can have: it teaches the team to switch the audit off. Each
    // of these shapes triggered one.

    test('a deep link into a :param route without enumeratePaths', () async {
      // The commonest shape a real app has. The engine itself calls an
      // un-enumerated :param route a *warning* whose message says "its
      // URLs work for visitors" — so calling a link to one of those
      // URLs a broken link contradicted its own verdict.
      final report = await _audit([
        _ok('/', body: [
          SeoNode(tag: 'h1', text: 'Start'),
          SeoNode(
              tag: 'a', text: 'Doku', attributes: {'href': '/docs/install'}),
        ]),
        SeoRoute(
          path: '/docs/:page',
          meta: (p) => SeoMeta(title: 'Doku ${p['page']} lesen und lernen'),
        ),
      ]);
      expect(_ids(report), isNot(contains('link.broken')));
      expect(report.errorCount, 0, reason: report.describe());
      // The route-level warning is still raised — it is the right one.
      expect(_ids(report), contains('route.not-enumerated'));
    });

    test('a partially enumerated route still serves its other URLs', () async {
      final report = await _audit([
        _ok('/', body: [
          SeoNode(tag: 'h1', text: 'Start'),
          SeoNode(tag: 'a', text: 'Alt', attributes: {'href': '/blog/2019'}),
        ]),
        SeoRoute(
          path: '/blog/:slug',
          meta: (p) => SeoMeta(title: 'Post ${p['slug']} lesen und lernen'),
          enumeratePaths: () => ['/blog/neu'],
        ),
      ]);
      expect(_ids(report), isNot(contains('link.broken')));
    });

    test('links to static assets are not pages', () async {
      final report = await _audit([
        _ok('/', body: [
          SeoNode(tag: 'h1', text: 'Start'),
          SeoNode(tag: 'a', text: 'PDF', attributes: {'href': '/x.pdf'}),
          SeoNode(tag: 'a', text: 'Logo', attributes: {'href': '/logo.png'}),
        ]),
      ]);
      expect(_ids(report), isNot(contains('link.broken')));
    });

    test('a canonical with a query string or fragment', () async {
      final report = await _audit([
        SeoRoute(
          path: '/suche',
          meta: (_) => const SeoMeta(
            title: 'Die Suche auf dieser Seite',
            description: 'Eine Beschreibung, die bequem in das Fenster passt, '
                'das Suchmaschinen tatsaechlich anzeigen und darstellen.',
            canonicalUrl: '$_base/suche?q=schuhe',
          ),
          body: (_) => [SeoNode(tag: 'h1', text: 'Suche')],
        ),
      ]);
      expect(_ids(report), isNot(contains('canonical.unknown-path')));
      expect(report.errorCount, 0, reason: report.describe());
    });

    test('a look-alike host is external, not a broken internal link', () async {
      // https://x.dev.evil.com starts with the base string but is a
      // different site; a prefix comparison called it internal.
      final report = await _audit([
        _ok('/', body: [
          SeoNode(tag: 'h1', text: 'Start'),
          SeoNode(
            tag: 'a',
            text: 'Fremd',
            attributes: {'href': 'https://x.dev.evil.com/nope'},
          ),
        ]),
      ]);
      expect(_ids(report), isNot(contains('link.broken')));
    });

    test('a language variant kept out of the sitemap is still reciprocal',
        () async {
      const both = {'de': '$_base/de', 'en': '$_base/en'};
      final report = await _audit([
        SeoRoute(
          path: '/de',
          meta: (_) => const SeoMeta(
            title: 'Die deutsche Startseite hier',
            description: 'Eine Beschreibung, die bequem in das Fenster passt, '
                'das Suchmaschinen tatsaechlich anzeigen und darstellen.',
            alternates: both,
          ),
          body: (_) => [SeoNode(tag: 'h1', text: 'Hallo')],
        ),
        SeoRoute(
          path: '/en',
          // Deliberately out of the sitemap — still a real page that
          // links back.
          includeInSitemap: false,
          meta: (_) => const SeoMeta(
            title: 'The English home page here',
            description: 'A description that sits comfortably inside the '
                'window search engines actually show to a human reader.',
            alternates: both,
          ),
          body: (_) => [SeoNode(tag: 'h1', text: 'Hello')],
        ),
      ]);
      expect(
        _ids(report).where((id) => id.startsWith('hreflang')),
        isEmpty,
        reason: report.describe(),
      );
    });

    test('every check can be suppressed, including the errors', () async {
      // Suppression was wired into 3 of 30 checks and none of the
      // errors, so a team hitting a false positive could only delete
      // the audit. It is filtered centrally now.
      final broken = [
        SeoRoute(
          path: '/',
          meta: (_) => const SeoMeta(),
          body: (_) => [
            SeoNode(tag: 'a', text: 'Weg', attributes: {'href': '/nirgends'}),
          ],
        ),
      ];
      final loud = await _audit(broken);
      expect(loud.errorCount, greaterThan(0));

      final quiet = await _audit(
        broken,
        policy: const SeoAuditPolicy(ignore: {
          SeoCheck.titleMissing,
          SeoCheck.linkBroken,
          SeoCheck.descriptionMissing,
          SeoCheck.headingNoH1,
        }),
      );
      expect(_ids(quiet), isNot(contains('title.missing')));
      expect(_ids(quiet), isNot(contains('link.broken')));
      expect(quiet.errorCount, 0, reason: quiet.describe());
    });
  });

  group('checks the review found missing', () {
    test('a canonical pointing at a gone page', () async {
      // The README calls this the flagship case, and it was not
      // implemented: the page asks Google to index a URL that is 410.
      final report = await _audit([
        SeoRoute(
          path: '/alt',
          meta: (_) => const SeoMeta(
            title: 'Die alte Produktseite hier',
            description: 'Eine Beschreibung, die bequem in das Fenster passt, '
                'das Suchmaschinen tatsaechlich anzeigen und darstellen.',
            canonicalUrl: '$_base/weg',
          ),
          body: (_) => [SeoNode(tag: 'h1', text: 'Alt')],
        ),
        SeoRoute.dynamic(
          path: '/weg',
          resolve: (_) async => SeoDocument.gone(),
        ),
      ]);
      expect(_ids(report), contains('canonical.non-indexable'));
      expect(report.describe(), contains('410'));
    });

    test('a canonical pointing at a redirect', () async {
      final report = await _audit([
        SeoRoute(
          path: '/a',
          meta: (_) => const SeoMeta(
            title: 'Eine ganz normale Seite',
            description: 'Eine Beschreibung, die bequem in das Fenster passt, '
                'das Suchmaschinen tatsaechlich anzeigen und darstellen.',
            canonicalUrl: '$_base/b',
          ),
          body: (_) => [SeoNode(tag: 'h1', text: 'A')],
        ),
        SeoRoute.dynamic(
          path: '/b',
          resolve: (_) async => const SeoRedirect('/c'),
        ),
        _ok('/c', title: 'Das eigentliche Ziel hier'),
      ]);
      expect(_ids(report), contains('canonical.non-indexable'));
    });

    test("robots: 'none' means noindex", () async {
      final report = await _audit([
        SeoRoute(
          path: '/geheim',
          meta: (_) => const SeoMeta(title: 'Geheime Seite', robots: 'none'),
          body: (_) => [SeoNode(tag: 'h1', text: 'Geheim')],
        ),
      ]);
      expect(_ids(report), contains('robots.noindex-in-sitemap'));
    });

    test('a pathologically deep body does not crash the audit', () async {
      // An audit that takes the build down with a StackOverflowError is
      // worse than no audit.
      SeoNode deep(int n) => n == 0
          ? SeoNode(tag: 'p', text: 'Grund')
          : SeoNode(tag: 'div', children: [deep(n - 1)]);
      final report = await _audit([
        _ok('/', body: [SeoNode(tag: 'h1', text: 'H'), deep(5000)]),
      ]);
      expect(report.pagesAudited, 1);
    });

    test('an empty route table is reported, not silently clean', () async {
      final report = await _audit([]);
      expect(_ids(report), contains('sitemap.empty'));
      expect(report.passes(), isFalse);
    });
  });

  group('the second review round', () {
    test('a relative link to nowhere is caught, not skipped', () async {
      // These were dropped on the floor: only `/`-rooted hrefs were
      // examined, so `about` and `../agb` could point anywhere.
      final report = await _audit([
        _ok('/docs/intro', body: [
          SeoNode(tag: 'h1', text: 'Intro'),
          SeoNode(tag: 'a', text: 'Weiter', attributes: {'href': 'gibtsnicht'}),
        ]),
      ]);
      expect(_ids(report), contains('link.broken'));
      expect(report.describe(), contains('/docs/gibtsnicht'));
    });

    test('a relative link is resolved against its own page', () async {
      // `weiter` on /docs/intro means /docs/weiter — resolving it
      // against the site root instead would report a working link as
      // broken and miss a broken one as working.
      final report = await _audit([
        _ok('/docs/intro', body: [
          SeoNode(tag: 'h1', text: 'Intro'),
          SeoNode(tag: 'a', text: 'Weiter', attributes: {'href': 'weiter'}),
          SeoNode(tag: 'a', text: 'Hoch', attributes: {'href': '../start'}),
        ]),
        _ok('/docs/weiter', title: 'Die zweite Doku-Seite'),
        _ok('/start', title: 'Die Startseite von hier'),
      ]);
      expect(_ids(report), isNot(contains('link.broken')),
          reason: report.describe());
    });

    test('a javascript: link is reported, not silently dropped', () async {
      final report = await _audit([
        _ok('/', body: [
          SeoNode(tag: 'h1', text: 'H'),
          SeoNode(
            tag: 'a',
            text: 'Klick',
            attributes: {'href': 'javascript:alert(1)'},
          ),
        ]),
      ]);
      // The renderer strips the href, so the crawler gets a bare <a>
      // that leads nowhere — invisible unless the audit says so.
      expect(_ids(report), contains('url.rejected-by-policy'));
    });

    test('two patterns of the same shape: the second is dead', () async {
      final report = await _audit([
        SeoRoute(
          path: '/blog/:slug',
          meta: (_) => const SeoMeta(title: 'Ein Blogartikel hier'),
          body: (_) => [SeoNode(tag: 'h1', text: 'Artikel')],
        ),
        SeoRoute(
          path: '/blog/:id',
          meta: (_) => const SeoMeta(title: 'Nie erreichbar hier'),
          body: (_) => [SeoNode(tag: 'h1', text: 'Tot')],
        ),
      ]);
      expect(_ids(report), contains('route.shadowed'));
      expect(report.describe(), contains('/blog/:slug'));
    });

    test('a relative hreflang URL is reported', () async {
      final report = await _audit([
        SeoRoute(
          path: '/',
          meta: (_) => const SeoMeta(
            title: 'Die deutsche Startseite',
            description: 'Eine Beschreibung, die bequem in das Fenster passt, '
                'das Suchmaschinen tatsaechlich anzeigen und darstellen.',
            alternates: {'de': '/', 'en': '/en'},
          ),
          body: (_) => [SeoNode(tag: 'h1', text: 'Start')],
        ),
      ]);
      expect(_ids(report), contains('hreflang.relative'));
    });

    test('an hreflang to an un-enumerated :param route is fine', () async {
      // The old check asked the enumerated page set and called a
      // perfectly working URL unserved — the same false positive
      // link.broken had.
      final report = await _audit([
        SeoRoute(
          path: '/produkt/:slug',
          meta: (_) => const SeoMeta(
            title: 'Eine deutsche Produktseite',
            description: 'Eine Beschreibung, die bequem in das Fenster passt, '
                'das Suchmaschinen tatsaechlich anzeigen und darstellen.',
            alternates: {
              'de': '$_base/produkt/x',
              'en': '$_base/en/product/x',
            },
          ),
          body: (_) => [SeoNode(tag: 'h1', text: 'Produkt')],
        ),
        SeoRoute(
          path: '/en/product/:slug',
          meta: (_) => const SeoMeta(title: 'An English product page'),
          body: (_) => [SeoNode(tag: 'h1', text: 'Product')],
        ),
      ], additionalPaths: const [
        '/produkt/x'
      ]);
      expect(_ids(report), isNot(contains('hreflang.unknown-target')),
          reason: report.describe());
      expect(_ids(report), isNot(contains('hreflang.not-reciprocal')),
          reason: report.describe());
    });

    test('a Product with only a name gets no snippet', () async {
      final report = await _audit([
        SeoRoute(
          path: '/p',
          meta: (_) => SeoMeta(
            title: 'Eine ganz normale Produktseite',
            description: 'Eine Beschreibung, die bequem in das Fenster passt, '
                'das Suchmaschinen tatsaechlich anzeigen und darstellen.',
            schemas: [
              SeoSchema('Product', const {'name': 'Ding'})
            ],
          ),
          body: (_) => [SeoNode(tag: 'h1', text: 'Ding')],
        ),
      ]);
      expect(_ids(report), contains('schema.missing-required'));
      expect(report.describe(), contains('offers'));
    });

    test('an Article without a headline is a warning, not an error', () async {
      // Google's Article documentation no longer lists any required
      // property, so failing a build on this would be wrong.
      final report = await _audit([
        SeoRoute(
          path: '/a',
          meta: (_) => SeoMeta(
            title: 'Ein Artikel ohne Headline',
            description: 'Eine Beschreibung, die bequem in das Fenster passt, '
                'das Suchmaschinen tatsaechlich anzeigen und darstellen.',
            schemas: [
              SeoSchema('Article', const {'author': 'Yahya'})
            ],
          ),
          body: (_) => [SeoNode(tag: 'h1', text: 'A')],
        ),
      ]);
      expect(_ids(report), contains('schema.missing-recommended'));
      expect(report.passes(), isTrue, reason: report.describe());
    });

    test('a Review without an author is ineligible', () async {
      final report = await _audit([
        SeoRoute(
          path: '/r',
          meta: (_) => SeoMeta(
            title: 'Eine Rezension ohne Autor',
            description: 'Eine Beschreibung, die bequem in das Fenster passt, '
                'das Suchmaschinen tatsaechlich anzeigen und darstellen.',
            schemas: [
              SeoSchema('Review', const {
                'itemReviewed': {'@type': 'Thing', 'name': 'Ding'},
                'reviewRating': {'@type': 'Rating', 'ratingValue': 5},
              }),
            ],
          ),
          body: (_) => [SeoNode(tag: 'h1', text: 'R')],
        ),
      ]);
      expect(report.describe(), contains('author'));
      expect(report.passes(), isFalse);
    });

    test('an Event without a location is ineligible', () async {
      final report = await _audit([
        SeoRoute(
          path: '/e',
          meta: (_) => SeoMeta(
            title: 'Ein Termin ohne Ortsangabe',
            description: 'Eine Beschreibung, die bequem in das Fenster passt, '
                'das Suchmaschinen tatsaechlich anzeigen und darstellen.',
            schemas: [
              SeoSchema.event(
                name: 'Meetup',
                startDate: DateTime.utc(2026, 9, 1),
              ),
            ],
          ),
          body: (_) => [SeoNode(tag: 'h1', text: 'E')],
        ),
      ]);
      expect(report.describe(), contains('location'));
    });

    test('assertSeoHealthy actually throws on a broken site', () async {
      // The documented hand-written alternative,
      // `isNot(contains('[error]'))`, passed here — describe() writes
      // `x`, not `[error]`.
      final report = await _audit([
        SeoRoute(
          path: '/',
          meta: (_) => const SeoMeta(),
          body: (_) => [SeoNode(tag: 'h1', text: 'Ohne Titel')],
        ),
      ]);
      expect(report.describe(), isNot(contains('[error]')));
      expect(() => assertSeoHealthy(report), throwsA(isA<SeoAuditFailure>()));
      expect(
        () => assertSeoHealthy(report),
        throwsA(
          isA<SeoAuditFailure>()
              .having((e) => e.toString(), 'message', contains('title')),
        ),
      );
    });

    test('assertSeoHealthy stays silent on a healthy site', () {
      final clean = SeoAuditReport(findings: const [], pagesAudited: 1);
      expect(() => assertSeoHealthy(clean), returnsNormally);
    });
  });

  group('no false positives on a healthy site', () {
    test('a well-formed table produces nothing at all', () async {
      final report = await _audit([
        SeoRoute(
          path: '/',
          meta: (_) => const SeoMeta(
            title: 'A perfectly ordinary home page',
            description: 'A description comfortably inside the window that '
                'search engines actually show to a human reader.',
          ),
          body: (_) => [
            SeoNode(tag: 'h1', text: 'Willkommen'),
            SeoNode(tag: 'a', text: 'Zum Blog', attributes: {'href': '/blog'}),
            SeoNode(tag: 'img', attributes: {'src': '/a.png', 'alt': 'Foto'}),
          ],
        ),
        SeoRoute(
          path: '/blog',
          meta: (_) => const SeoMeta(
            title: 'The blog index page here',
            description: 'Another description comfortably inside the window '
                'that search engines actually show to a human reader.',
          ),
          body: (_) => [SeoNode(tag: 'h1', text: 'Blog')],
        ),
      ]);
      expect(report.findings, isEmpty, reason: report.describe());
      expect(report.passes(), isTrue);
      expect(report.pagesAudited, 2);
    });
  });
}
