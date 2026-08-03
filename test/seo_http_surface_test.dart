import 'package:esen_seo/server.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shelf/shelf.dart';

const _googlebot = 'Mozilla/5.0 (compatible; Googlebot/2.1)';
const _human = 'Mozilla/5.0';

Handler _handler(
  List<SeoRoute> routes, {
  SeoRedirectScope scope = SeoRedirectScope.all,
  Duration? ttl = seoAutoInfrastructureCacheTtl,
  void Function(String, Object, StackTrace)? onError,
}) =>
    const Pipeline()
        .addMiddleware(seoBotMiddleware(
          routes: routes,
          siteBase: 'https://x.dev',
          applyResolverRedirects: scope,
          infrastructureCacheTtl: ttl,
          onResolveError: onError,
        ))
        .addHandler((_) => Response.ok('app'));

Future<Response> _get(
  Handler handler,
  String path, {
  bool asBot = true,
}) =>
    Future.value(handler(Request(
      'GET',
      Uri.parse('http://localhost$path'),
      headers: {'user-agent': asBot ? _googlebot : _human},
    )));

List<SeoRoute> _redirectTable() => [
      SeoRoute.dynamic(
        path: '/old',
        resolve: (_) async => const SeoRedirect('/new'),
      ),
    ];

void main() {
  group('request methods', () {
    test('non-reading methods always reach the application handler', () async {
      final routes = [
        SeoRoute(
          path: '/account',
          meta: (_) => const SeoMeta(title: 'Account'),
          body: (_) => [SeoNode(tag: 'h1', text: 'Account')],
        ),
      ];
      final handler = const Pipeline()
          .addMiddleware(
            seoBotMiddleware(routes: routes, siteBase: 'https://x.dev'),
          )
          .addHandler((request) => Response.ok('app ${request.method}'));

      for (final method in const ['POST', 'PUT', 'PATCH', 'DELETE']) {
        final response = await handler(Request(
          method,
          Uri.parse('https://x.dev/account'),
          headers: {'user-agent': _googlebot},
        ));
        expect(await response.readAsString(), 'app $method');
        expect(response.headers['x-esen-seo'], isNull);
      }

      final sitemap = await handler(Request(
        'POST',
        Uri.parse('https://x.dev/sitemap.xml'),
        headers: {'user-agent': _googlebot},
      ));
      expect(await sitemap.readAsString(), 'app POST');
    });
  });

  group('resolver redirects and cloaking', () {
    test('all (default): human AND bot get the 301', () async {
      final handler = _handler(_redirectTable());
      final bot = await _get(handler, '/old');
      final human = await _get(handler, '/old', asBot: false);
      expect(bot.statusCode, 301);
      expect(bot.headers['location'], '/new');
      expect(human.statusCode, 301);
      expect(human.headers['location'], '/new');
    });

    test('botsOnly: only the bot is redirected, the human gets the app',
        () async {
      final handler =
          _handler(_redirectTable(), scope: SeoRedirectScope.botsOnly);
      expect((await _get(handler, '/old')).statusCode, 301);
      final human = await _get(handler, '/old', asBot: false);
      expect(human.statusCode, 200);
      expect(await human.readAsString(), 'app');
    });

    test('off: neither is redirected, both fall through to the app', () async {
      final handler = _handler(_redirectTable(), scope: SeoRedirectScope.off);
      final bot = await _get(handler, '/old');
      final human = await _get(handler, '/old', asBot: false);
      expect(bot.statusCode, 200);
      expect(await bot.readAsString(), 'app');
      expect(human.statusCode, 200);
    });

    test('a dotted legacy path redirects humans too', () async {
      // /old-page.html → clean URL is the commonest relaunch mapping
      // there is. Filtering the human branch by "looks like a page"
      // sent the bot to the new URL and left the human on the old one —
      // cloaking produced by the anti-cloaking code itself.
      final handler = _handler([
        SeoRoute.dynamic(
          path: '/old-page.html',
          resolve: (_) async => const SeoRedirect('/old-page'),
        ),
      ]);
      final bot = await _get(handler, '/old-page.html');
      final human = await _get(handler, '/old-page.html', asBot: false);
      expect(bot.statusCode, 301);
      expect(human.statusCode, 301);
      expect(human.headers['location'], bot.headers['location']);
    });

    test('an asset path costs no resolution', () async {
      // matchSeoRoute is the filter: /main.dart.js matches no route, so
      // dropping the _looksLikePage guard costs nothing.
      var reads = 0;
      final handler = _handler([
        SeoRoute.dynamic(
          path: '/p',
          resolve: (_) async {
            reads++;
            return const SeoDocument();
          },
        ),
      ]);
      await _get(handler, '/main.dart.js', asBot: false);
      expect(reads, 0);
    });

    test('in a MIXED table a classic route costs no human resolve', () async {
      // The bug was here, not in a purely classic table: the check was a
      // property of the whole table, so one dynamic route anywhere made
      // every classic route rebuild its meta on each human page view.
      var metaCalls = 0;
      final handler = _handler([
        SeoRoute(
          path: '/statisch',
          meta: (_) {
            metaCalls++;
            return const SeoMeta(title: 'Statisch');
          },
        ),
        SeoRoute.dynamic(
          path: '/dynamisch',
          resolve: (_) async => const SeoRedirect('/neu'),
        ),
      ]);

      await _get(handler, '/statisch', asBot: false);
      expect(metaCalls, 0, reason: 'a classic route cannot be a redirect');

      // The dynamic route in the same table still redirects the human.
      final human = await _get(handler, '/dynamisch', asBot: false);
      expect(human.statusCode, 301);
    });

    test('a classic route with an enumerator costs no human resolve', () async {
      // It needs the async pass for the sitemap, but a static resolution
      // can never be a redirect — so the human branch must skip it.
      var metaCalls = 0;
      final handler = _handler([
        SeoRoute(
          path: '/blog/:slug',
          meta: (p) {
            metaCalls++;
            return SeoMeta(title: p['slug']);
          },
          enumeratePaths: () async => ['/blog/a'],
        ),
      ]);
      await _get(handler, '/blog/a', asBot: false);
      expect(metaCalls, 0);
    });

    test('a human hitting a 404 document keeps the app, not an SSR stub',
        () async {
      // Status codes stay bot-only even under `all` — a human must not
      // get the SSR error page in place of the Flutter app.
      final handler = _handler([
        SeoRoute.dynamic(
          path: '/gone',
          resolve: (_) async => SeoDocument.notFound(),
        ),
      ]);
      final human = await _get(handler, '/gone', asBot: false);
      expect(human.statusCode, 200);
      expect(await human.readAsString(), 'app');
      // The bot does get the real 404.
      expect((await _get(handler, '/gone')).statusCode, 404);
    });

    test('a resolver failure does not 5xx a human', () async {
      final failures = <String>[];
      final handler = _handler(
        [
          SeoRoute.dynamic(
            path: '/boom',
            resolve: (_) async => throw StateError('db down'),
          ),
        ],
        onError: (p, _, __) => failures.add(p),
      );
      final human = await _get(handler, '/boom', asBot: false);
      expect(human.statusCode, 200);
      expect(await human.readAsString(), 'app');
      expect(failures, ['/boom']);
    });
  });

  group('resolver response headers', () {
    Future<Response> serve(Map<String, String> headers) => _get(
          _handler([
            SeoRoute.dynamic(
              path: '/p',
              resolve: (_) async => SeoDocument(
                meta: const SeoMeta(title: 'P'),
                body: [SeoNode(tag: 'h1', text: 'P')],
                headers: headers,
              ),
            ),
          ]),
          '/p',
        );

    test('the SEO and caching headers a mirror needs pass through', () async {
      final res = await serve({
        'cache-control': 'public, max-age=600',
        'x-robots-tag': 'noarchive',
        'link': '<https://x.dev/p>; rel="canonical"',
        'content-language': 'de',
        'etag': 'W/"abc"',
      });
      expect(res.headers['cache-control'], 'public, max-age=600');
      expect(res.headers['x-robots-tag'], 'noarchive');
      expect(res.headers['link'], contains('rel="canonical"'));
      expect(res.headers['content-language'], 'de');
      expect(res.headers['etag'], 'W/"abc"');
    });

    test('anything outside the allow list is refused', () async {
      // A block list of the obvious protocol headers still let
      // set-cookie and content-encoding through; CORS, CSP and HSTS
      // would have been the next omissions. The names are an allow list.
      final res = await serve({
        'set-cookie': 'session=attacker; HttpOnly',
        'content-encoding': 'gzip',
        'access-control-allow-origin': '*',
        'content-security-policy': "default-src 'none'",
        'strict-transport-security': 'max-age=0',
        'x-custom': 'value',
      });
      for (final name in [
        'set-cookie',
        'content-encoding',
        'access-control-allow-origin',
        'content-security-policy',
        'strict-transport-security',
        'x-custom',
      ]) {
        expect(res.headers[name], isNull, reason: 'leaked: $name');
      }
      // The page itself is unaffected.
      expect(res.statusCode, 200);
    });

    test('a CRLF in a header value is dropped whole (no response split)',
        () async {
      final res = await serve({'x-evil': 'a\r\nSet-Cookie: pwned=1'});
      expect(res.headers['x-evil'], isNull);
      expect(res.headers.keys.any((k) => k.toLowerCase() == 'set-cookie'),
          isFalse);
    });

    test('a CRLF in a header NAME is dropped', () async {
      final res = await serve({'x-a\r\nSet-Cookie: x=1': 'v'});
      expect(res.headers.keys.any((k) => k.toLowerCase() == 'set-cookie'),
          isFalse);
    });

    test('non-CRLF control chars in a value are dropped too', () async {
      // The guard matches the renderer's URL policy: every control char,
      // not just CR/LF, so safety never depends on how a shelf adapter
      // treats a stray NUL, vertical tab or DEL.
      final res = await serve({
        'cache-control': 'a\x00b',
        'x-robots-tag': 'a\x0bb',
        'content-language': 'a\x7fb',
        'etag': 'clean',
      });
      expect(res.headers['cache-control'], isNull);
      expect(res.headers['x-robots-tag'], isNull);
      expect(res.headers['content-language'], isNull);
      expect(res.headers['etag'], 'clean');
    });

    test('package-controlled headers cannot be overridden', () async {
      final res = await serve({
        'content-type': 'text/plain',
        'content-length': '9999',
        'location': '/evil',
        'transfer-encoding': 'chunked',
      });
      expect(res.headers['content-type'], 'text/html; charset=utf-8');
      expect(res.headers['location'], isNull);
    });

    test('an error document keeps its own metadata when it has no body',
        () async {
      // SeoDocument.notFound accepts meta:, so swapping in a generic
      // page would silently discard a title and description the caller
      // deliberately supplied.
      final res = await _get(
        _handler([
          SeoRoute.dynamic(
            path: '/weg',
            resolve: (_) async => SeoDocument.gone(
              meta: const SeoMeta(
                title: 'Produkt eingestellt',
                description: 'Dieses Modell wird nicht mehr gefertigt.',
              ),
            ),
          ),
        ]),
        '/weg',
      );
      expect(res.statusCode, 410);
      final body = await res.readAsString();
      expect(body, contains('<title>Produkt eingestellt</title>'));
      expect(body, contains('nicht mehr gefertigt'));
      // noindex from the factory survives too.
      expect(body, contains('noindex'));
    });

    test('an error document with no metadata still gets a sensible page',
        () async {
      final res = await _get(
        _handler([
          SeoRoute.dynamic(
            path: '/weg',
            resolve: (_) async => SeoDocument.notFound(),
          ),
        ]),
        '/weg',
      );
      expect(res.statusCode, 404);
      expect(await res.readAsString(), contains('404'));
    });

    test('a resolver vary is merged with User-Agent, not replaced', () async {
      final res = await serve({'vary': 'Accept-Language'});
      final vary = res.headers['vary']!;
      expect(vary, contains('User-Agent'));
      expect(vary, contains('Accept-Language'));
    });

    test('without resolver headers the response still varies on User-Agent',
        () async {
      final res = await serve(const {});
      expect(res.headers['vary'], contains('User-Agent'));
    });
  });

  group('infrastructure cache TTL', () {
    test('a dynamic table re-resolves after the TTL expires', () async {
      var reads = 0;
      final handler = _handler(
        [
          SeoRoute.dynamic(
            path: '/p/:id',
            enumeratePaths: () async => ['/p/a'],
            resolve: (r) async {
              reads++;
              return SeoDocument(meta: SeoMeta(title: r['id']));
            },
          ),
        ],
        ttl: const Duration(milliseconds: 50),
      );

      await _get(handler, '/sitemap.xml');
      await _get(handler, '/sitemap.xml');
      expect(reads, 1, reason: 'within the TTL the table is resolved once');

      await Future<void>.delayed(const Duration(milliseconds: 80));
      await _get(handler, '/sitemap.xml');
      expect(reads, 2, reason: 'after the TTL it re-resolves');
    });

    test('a classic async body is not frozen for the process lifetime',
        () async {
      // "Classic" does not mean "immutable": a classic body builder may
      // read a database. Only llms-full.txt renders bodies, so only it
      // must drop the forever-cache.
      var reads = 0;
      final handler = _handler([
        SeoRoute(
          path: '/',
          meta: (_) => const SeoMeta(title: 'Home'),
          body: (_) async {
            reads++;
            return [SeoNode(tag: 'p', text: 'read $reads')];
          },
        ),
      ], ttl: const Duration(milliseconds: 50));

      await _get(handler, '/llms-full.txt');
      await Future<void>.delayed(const Duration(milliseconds: 80));
      final second = await _get(handler, '/llms-full.txt');
      expect(reads, 2, reason: 'a database-backed body must not be frozen');
      expect(await second.readAsString(), contains('read 2'));
    });

    test('a failing classic async body degrades instead of killing the file',
        () async {
      // It also has to take the async path, or its failure would fail
      // the whole endpoint instead of dropping one page.
      final failures = <String>[];
      final handler = _handler(
        [
          SeoRoute(path: '/', meta: (_) => const SeoMeta(title: 'Home')),
          SeoRoute(
            path: '/kaputt',
            meta: (_) => const SeoMeta(title: 'Kaputt'),
            body: (_) async => throw StateError('db down'),
          ),
        ],
        onError: (p, _, __) => failures.add(p),
      );
      final res = await _get(handler, '/llms-full.txt');
      expect(res.statusCode, 200, reason: 'the file survives one bad page');
      expect(await res.readAsString(), contains('Home'));
      expect(failures, contains('/kaputt'));
    });

    test('a static table caches forever (never re-resolves)', () async {
      // A static resolution cannot change, so the default is no TTL.
      final handler = _handler([
        SeoRoute(path: '/', meta: (_) => const SeoMeta(title: 'Home')),
      ]);
      final a = await _get(handler, '/sitemap.xml');
      final b = await _get(handler, '/sitemap.xml');
      expect(await a.readAsString(), await b.readAsString());
    });

    test('twenty concurrent requests resolve the table once', () async {
      var reads = 0;
      final handler = _handler([
        SeoRoute.dynamic(
          path: '/p/:id',
          enumeratePaths: () async => ['/p/a'],
          resolve: (r) async {
            reads++;
            await Future<void>.delayed(const Duration(milliseconds: 5));
            return SeoDocument(meta: SeoMeta(title: r['id']));
          },
        ),
      ]);
      await Future.wait([
        for (var i = 0; i < 20; i++) _get(handler, '/sitemap.xml'),
      ]);
      expect(reads, 1);
    });

    test('a DEGRADED resolution is served once but not cached', () async {
      // A database blip drops rows into onError and produces a partial
      // sitemap. It must be served (better than a 500) but NOT frozen in
      // the cache: the next request retries and picks up the recovered
      // database, instead of advertising an incomplete sitemap for the
      // whole TTL.
      var attempts = 0;
      final handler = _handler(
        [
          SeoRoute.dynamic(
            path: '/p/:id',
            enumeratePaths: () async {
              attempts++;
              if (attempts == 1) throw StateError('first call fails');
              return ['/p/a'];
            },
            resolve: (r) async => SeoDocument(meta: SeoMeta(title: r['id'])),
          ),
        ],
        onError: (_, __, ___) {},
      );
      final first = await _get(handler, '/sitemap.xml');
      expect(first.statusCode, 200, reason: 'degraded still serves');
      final second = await _get(handler, '/sitemap.xml');
      expect(attempts, 2, reason: 'the degraded pass was not cached');
      expect(await second.readAsString(), contains('/p/a'),
          reason: 'the retry picks up the recovered enumerator');
    });
  });
}
