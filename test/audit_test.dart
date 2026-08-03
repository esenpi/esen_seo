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
