import 'package:esen_seo/core.dart';
import 'package:esen_seo/server.dart'
    show seoLlmsFullTxt, seoLlmsTxt, seoSitemapXml;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('the static convenience route stays synchronous', () {
    test('head resolves in the same turn even with an async body', () {
      // The whole design rests on this line: a route whose body builder
      // is async must still answer a head request without a microtask,
      // or the sitemap, llms.txt and the observer would all go async.
      final match = matchSeoRoute([
        SeoRoute(
          path: '/',
          meta: (_) => const SeoMeta(title: 'Home'),
          body: (_) async => [SeoNode(tag: 'h1', text: 'late')],
        ),
      ], '/')!;

      final head = match.resolveSync(detail: SeoDetail.head);
      expect(head, isA<SeoDocument>());
      expect((head! as SeoDocument).meta.title, 'Home');
      // full needs the async body, so it is NOT available synchronously.
      expect(match.resolveSync(detail: SeoDetail.full), isNull);
    });

    test('full carries the async body once awaited', () async {
      final match = matchSeoRoute([
        SeoRoute(
          path: '/',
          meta: (_) => const SeoMeta(title: 'Home'),
          body: (_) async => [SeoNode(tag: 'h1', text: 'late')],
        ),
      ], '/')!;
      final full = await match.resolve(detail: SeoDetail.full) as SeoDocument;
      expect(full.body.single.text, 'late');
    });

    test('a dynamic route never resolves synchronously', () {
      final match = matchSeoRoute([
        SeoRoute.dynamic(
          path: '/p/:id',
          resolve: (r) async => SeoDocument(meta: SeoMeta(title: r['id'])),
        ),
      ], '/p/7')!;
      expect(match.resolveSync(detail: SeoDetail.head), isNull);
    });
  });

  group('memoisation reads a URL once', () {
    test('two head resolves share one read; full is a separate read', () async {
      var reads = 0;
      final match = matchSeoRoute([
        SeoRoute.dynamic(
          path: '/p/:id',
          resolve: (r) async {
            reads++;
            return SeoDocument(
              meta: SeoMeta(title: 'P ${r['id']}'),
              body: r.detail == SeoDetail.head
                  ? const []
                  : [SeoNode(tag: 'p', text: 'body')],
            );
          },
        ),
      ], '/p/1')!;

      await match.resolve(detail: SeoDetail.head);
      await match.resolve(detail: SeoDetail.head);
      expect(reads, 1, reason: 'two head reads must share one resolver call');

      final full = await match.resolve(detail: SeoDetail.full) as SeoDocument;
      expect(reads, 2, reason: 'full is a distinct read');
      // The invariant: a full request is never served the head result,
      // so the body the head skipped is really here.
      expect(full.body.single.text, 'body');
    });
  });

  group('the chokepoint finishes every resolution', () {
    test('canonical is derived for a 200 without one', () {
      final r = finishSeoResolution(
        const SeoDocument(meta: SeoMeta(title: 'X')),
        path: '/x',
        canonicalBase: 'https://x.dev',
      ) as SeoDocument;
      expect(r.meta.canonicalUrl, 'https://x.dev/x');
    });

    test('a 404 gets no canonical to itself', () {
      final r = finishSeoResolution(
        SeoDocument.notFound(),
        path: '/gone',
        canonicalBase: 'https://x.dev',
      ) as SeoDocument;
      expect(r.meta.canonicalUrl, isNull);
      expect(r.statusCode, 404);
      expect(r.meta.robots, 'noindex');
    });

    test('an explicit canonical is never overwritten', () {
      final r = finishSeoResolution(
        const SeoDocument(meta: SeoMeta(canonicalUrl: 'https://x.dev/keep')),
        path: '/x',
        canonicalBase: 'https://x.dev',
      ) as SeoDocument;
      expect(r.meta.canonicalUrl, 'https://x.dev/keep');
    });

    test('an unsafe redirect target becomes a 404, never a Location', () {
      var warned = '';
      for (final bad in [
        'javascript:alert(1)',
        '/ok\r\nSet-Cookie: x=1',
        'vbscript:msgbox(1)',
      ]) {
        final r = finishSeoResolution(
          SeoRedirect(bad),
          path: '/p',
          onWarning: (_, w) => warned = w,
        );
        expect(r, isA<SeoDocument>(), reason: 'accepted: $bad');
        expect((r as SeoDocument).statusCode, 404);
        expect(warned, isNotEmpty);
      }
    });

    test('a trailing CRLF is caught, not trimmed away before the check', () {
      // Checking the TRIMMED value and emitting the RAW one let a
      // trailing CRLF pass the guard and reach the Location header.
      for (final bad in ['/neu\r\n', '/neu\n', '/neu\r\nSet-Cookie: x=1']) {
        final r = finishSeoResolution(SeoRedirect(bad), path: '/alt');
        expect(r, isA<SeoDocument>(), reason: 'accepted: ${bad.codeUnits}');
        expect((r as SeoDocument).statusCode, 404);
      }
    });

    test('surrounding whitespace is normalised out of what is emitted', () {
      // Plain spaces are harmless but must not reach the header
      // unchecked — emit exactly the value that was validated.
      final r = finishSeoResolution(
        const SeoRedirect('  /neu  '),
        path: '/alt',
      );
      expect(r, isA<SeoRedirect>());
      expect((r as SeoRedirect).location, '/neu');
    });

    test('a safe redirect passes through', () {
      final r = finishSeoResolution(
        const SeoRedirect('/neu'),
        path: '/alt',
      );
      expect(r, isA<SeoRedirect>());
      expect((r as SeoRedirect).location, '/neu');
      expect(r.statusCode, 301);
    });
  });

  group('resolveSeoPages', () {
    List<SeoRoute> table() => [
          SeoRoute(path: '/', meta: (_) => const SeoMeta(title: 'Home')),
          SeoRoute.dynamic(
            path: '/p/:id',
            enumeratePaths: () async => ['/p/a', '/p/b', '/p/gone', '/p/old'],
            resolve: (r) async {
              switch (r['id']) {
                case 'gone':
                  return SeoDocument.gone();
                case 'old':
                  return const SeoRedirect('/p/a');
                default:
                  return SeoDocument(
                    meta: SeoMeta(title: 'P ${r['id']}'),
                    lastModified: DateTime.utc(2026, 8, r['id'] == 'a' ? 1 : 2),
                  );
              }
            },
          ),
        ];

    test('enumerates and resolves every concrete URL once', () async {
      final pages = await resolveSeoPages(
        routes: table(),
        canonicalBase: 'https://x.dev',
      );
      expect(pages.map((p) => p.path),
          containsAll(['/', '/p/a', '/p/b', '/p/gone', '/p/old']));
    });

    test('sitemap drops redirects, gone pages, keeps per-record lastmod',
        () async {
      final pages = await resolveSeoPages(
        routes: table(),
        canonicalBase: 'https://x.dev',
      );
      final xml = seoSitemapXml(pages: pages, siteBase: 'https://x.dev');
      expect(xml, contains('<loc>https://x.dev/p/a</loc>'));
      expect(xml, contains('<lastmod>2026-08-01</lastmod>'));
      // The 410 and the redirect are not indexable.
      expect(xml, isNot(contains('/p/gone')));
      expect(xml, isNot(contains('/p/old')));
    });

    test('llms-full reads meta and body from one resolution', () async {
      // The drift the whole feature exists to remove: a resolver whose
      // output changes between reads must show ONE consistent read.
      var counter = 0;
      final txt = await seoLlmsFullTxt(
        siteBase: 'https://x.dev',
        routes: [
          SeoRoute.dynamic(
            path: '/p',
            resolve: (r) async {
              final n = ++counter;
              return SeoDocument(
                meta: SeoMeta(title: 'Read $n'),
                body: [SeoNode(tag: 'p', text: 'Body $n')],
              );
            },
          ),
        ],
      );
      // Title and body carry the SAME read number.
      expect(txt, contains('## Read 1'));
      expect(txt, contains('Body 1'));
      expect(txt, isNot(contains('Read 2')));
    });

    test('debugCheckMetaStability catches a resolver that lies for head',
        () async {
      Future<void> run() => resolveSeoPages(
            routes: [
              SeoRoute.dynamic(
                path: '/p',
                resolve: (r) async => SeoDocument(
                  meta: SeoMeta(
                    title: r.detail == SeoDetail.head ? 'Head' : 'Full',
                  ),
                ),
              ),
            ],
            debugCheckMetaStability: true,
          );
      expect(run, throwsStateError);
    });

    test('an enumerator that fails ASYNCHRONOUSLY goes through onError',
        () async {
      // A database enumerator fails this way, not by throwing from the
      // call. The error used to surface out of Future.wait, past the
      // error policy, and take the whole pass with it.
      final failed = <String>[];
      final pages = await resolveSeoPages(
        routes: [
          SeoRoute(path: '/', meta: (_) => const SeoMeta(title: 'Home')),
          SeoRoute(
            path: '/p/:id',
            meta: (_) => const SeoMeta(),
            enumeratePaths: () async => throw StateError('db down'),
          ),
        ],
        onError: (path, _, __) => failed.add(path),
      );
      expect(failed, ['/p/:id']);
      // The rest of the site still resolves.
      expect(pages.map((p) => p.path), ['/']);
    });

    test('without onError an async enumerator failure still surfaces',
        () async {
      // A build must fail loudly rather than ship a sitemap missing a
      // whole section.
      expect(
        () => resolveSeoPages(
          routes: [
            SeoRoute(
              path: '/p/:id',
              meta: (_) => const SeoMeta(),
              enumeratePaths: () async => throw StateError('db down'),
            ),
          ],
        ),
        throwsStateError,
      );
    });

    test('onError skips a failing page instead of aborting', () async {
      final pages = await resolveSeoPages(
        routes: [
          SeoRoute(path: '/', meta: (_) => const SeoMeta(title: 'Home')),
          SeoRoute.dynamic(
            path: '/boom',
            resolve: (_) async => throw StateError('db down'),
          ),
        ],
        additionalPaths: const ['/boom'],
        onError: (_, __, ___) {},
      );
      expect(pages.map((p) => p.path), contains('/'));
      expect(pages.map((p) => p.path), isNot(contains('/boom')));
    });
  });

  group('enumeration order does not depend on timing', () {
    // `explicit` decides whether a route's includeInSitemap is honoured,
    // so if an additionalPath could win a duplicate URL from an
    // enumerator, adding `async` to that enumerator would silently move
    // a page into the sitemap.
    Future<List<SeoResolvedPage>> run({required bool asyncEnumerator}) =>
        resolveSeoPages(
          routes: [
            SeoRoute(
              path: '/blog/:slug',
              meta: (p) => SeoMeta(title: p['slug']),
              includeInSitemap: false, // the pattern opts out
              enumeratePaths:
                  asyncEnumerator ? () async => ['/blog/a'] : () => ['/blog/a'],
            ),
          ],
          additionalPaths: const ['/blog/a'], // same URL, explicitly
        );

    test('a sync and an async enumerator produce the same ownership', () async {
      final sync = await run(asyncEnumerator: false);
      final async = await run(asyncEnumerator: true);
      expect(sync.map((p) => p.path), async.map((p) => p.path));
      expect(
        sync.single.explicit,
        async.single.explicit,
        reason: 'adding async must not flip who owns the URL',
      );
      // The enumerator claimed it first, so the route's opt-out applies.
      expect(sync.single.explicit, isFalse);
      expect(sync.single.isIndexable, isFalse);
    });

    test('multiple async enumerators keep table order', () async {
      final pages = await resolveSeoPages(
        routes: [
          SeoRoute(
            path: '/a/:x',
            meta: (_) => const SeoMeta(),
            enumeratePaths: () async {
              await Future<void>.delayed(const Duration(milliseconds: 20));
              return ['/a/1'];
            },
          ),
          SeoRoute(
            path: '/b/:x',
            meta: (_) => const SeoMeta(),
            enumeratePaths: () async => ['/b/1'], // completes first
          ),
        ],
      );
      // Table order, not completion order.
      expect(pages.map((p) => p.path).toList(), ['/a/1', '/b/1']);
    });
  });

  group('the stability check covers more than the title', () {
    test('a differing status between head and full is caught', () async {
      expect(
        () => resolveSeoPages(
          routes: [
            SeoRoute.dynamic(
              path: '/p',
              resolve: (r) async => r.detail == SeoDetail.head
                  ? const SeoDocument(meta: SeoMeta(title: 'X'))
                  : SeoDocument.gone(meta: const SeoMeta(title: 'X')),
            ),
          ],
          debugCheckMetaStability: true,
        ),
        throwsStateError,
      );
    });

    test('a differing lastModified is caught', () async {
      expect(
        () => resolveSeoPages(
          routes: [
            SeoRoute.dynamic(
              path: '/p',
              resolve: (r) async => SeoDocument(
                meta: const SeoMeta(title: 'X'),
                lastModified: r.detail == SeoDetail.head
                    ? DateTime.utc(2026, 1, 1)
                    : DateTime.utc(2026, 2, 2),
              ),
            ),
          ],
          debugCheckMetaStability: true,
        ),
        throwsStateError,
      );
    });

    test('skipping only the body is allowed', () async {
      final pages = await resolveSeoPages(
        routes: [
          SeoRoute.dynamic(
            path: '/p',
            resolve: (r) async => SeoDocument(
              meta: const SeoMeta(title: 'X'),
              body: r.detail == SeoDetail.head
                  ? const []
                  : [SeoNode(tag: 'p', text: 'body')],
            ),
          ),
        ],
        debugCheckMetaStability: true,
      );
      expect(pages.single.document!.body, isNotEmpty);
    });
  });

  group('the sync generators refuse a dynamic table loudly', () {
    final dynamicTable = [
      SeoRoute.dynamic(
        path: '/p/:id',
        resolve: (r) async => SeoDocument(meta: SeoMeta(title: r['id'])),
      ),
    ];

    test('seoSitemapXml(routes:) throws with the fix in the message', () {
      expect(
        () => seoSitemapXml(routes: dynamicTable, siteBase: 'https://x.dev'),
        throwsA(isA<StateError>().having(
            (e) => e.toString(), 'message', contains('resolveSeoPages'))),
      );
    });

    test('seoLlmsTxt(routes:) throws too', () {
      expect(
        () => seoLlmsTxt(routes: dynamicTable, siteBase: 'https://x.dev'),
        throwsStateError,
      );
    });

    test('passing both routes and pages is an ArgumentError', () {
      expect(
        () => seoSitemapXml(
          routes: dynamicTable,
          pages: const [],
          siteBase: 'https://x.dev',
        ),
        throwsArgumentError,
      );
    });
  });
}
