import 'dart:io';

import 'package:esen_seo/server.dart';
import 'package:esen_seo/src/renderer/tag_policy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shelf/shelf.dart';

const _template = '''
<!DOCTYPE html>
<html>
<head><title>example</title></head>
<body></body>
</html>
''';

List<SeoRoute> _routes() => [
      SeoRoute(
        path: '/',
        meta: (_) => const SeoMeta(title: 'Home'),
        body: (_) => [SeoNode(tag: 'h1', text: 'Hallo')],
      ),
    ];

void main() {
  group('style attribute policy', () {
    test('refuses CSS that escapes the clipped mirror or executes', () {
      // position:fixed entkommt dem overflow:hidden des Containers und
      // könnte die laufende App überdecken.
      for (final css in [
        'position:fixed;top:0;left:0;width:100vw;height:100vh',
        'position : STICKY ; top:0',
        'position:relative;top:-100vh;height:200vh;z-index:2147483647',
        'width:expression(alert(1))',
        'behavior:url(evil.htc)',
        'background:url("javascript:alert(1)")',
      ]) {
        expect(
          isAllowedSeoAttribute('style', css),
          isFalse,
          reason: 'accepted: $css',
        );
      }
    });

    test('leaves the styling the widget library needs alone', () {
      for (final css in [
        'text-align:center',
        'display:flex;align-items:flex-end;gap:8px;height:220px',
        'flex:1;border-radius:3px 3px 0 0;background:#2563eb;height:100%',
        'width:180px;height:180px;border-radius:50%;'
            'background:conic-gradient(#2563eb 0% 46%,#f59e0b 46% 100%)',
        'background:url(/bild.png)',
      ]) {
        expect(
          isAllowedSeoAttribute('style', css),
          isTrue,
          reason: 'refused: $css',
        );
      }
    });
  });

  group('llms.txt link targets', () {
    test('an executable scheme becomes plain text, not a link', () async {
      final txt = await seoLlmsFullTxt(
        routes: [
          SeoRoute(
            path: '/',
            meta: (_) => const SeoMeta(title: 'Home'),
            body: (_) => [
              SeoNode(
                tag: 'a',
                text: 'Klick',
                attributes: {'href': 'javascript:alert(1)'},
              ),
            ],
          ),
        ],
        siteBase: 'https://x.dev',
      );
      expect(txt, contains('Klick'));
      expect(txt, isNot(contains('javascript:')));
      expect(txt, isNot(contains('](')));
    });
  });

  group('seoRedirectMiddleware', () {
    Future<Response> call(String forwardedProto) async {
      final handler = const Pipeline()
          .addMiddleware(seoRedirectMiddleware(canonicalHost: 'x.dev'))
          .addHandler((_) => Response.ok('app'));
      return handler(Request(
        'GET',
        Uri.parse('http://www.x.dev/seite'),
        headers: {'x-forwarded-proto': forwardedProto},
      ));
    }

    test('a garbage x-forwarded-proto does not break the request', () async {
      for (final value in ['foo bar', '1', '', 'javascript']) {
        final response = await call(value);
        expect(response.statusCode, 301, reason: 'value: "$value"');
        expect(response.headers['location'], startsWith('http://x.dev'));
      }
    });

    test('a legitimate value is still honoured', () async {
      final response = await call('https');
      expect(response.headers['location'], startsWith('https://x.dev'));
    });
  });

  group('bot middleware caching and status', () {
    Future<Response> ask(
      String path, {
      required List<SeoRoute> routes,
      bool asBot = true,
      Map<String, String> appHeaders = const {},
    }) async {
      final handler = const Pipeline()
          .addMiddleware(
              seoBotMiddleware(routes: routes, siteBase: 'https://x.dev'))
          .addHandler((_) => Response.ok('app', headers: appHeaders));
      return handler(Request(
        'GET',
        Uri.parse('http://localhost$path'),
        headers: {'user-agent': asBot ? 'Googlebot/2.1' : 'Mozilla/5.0'},
      ));
    }

    test('a route without a body serves the app, never a 404', () async {
      // Die Route existiert — sie hat nur nichts zu spiegeln. Ein 404
      // wäre für Google schlimmer als die App auszuliefern.
      final response = await ask(
        '/nur-meta',
        routes: [
          SeoRoute(path: '/nur-meta', meta: (_) => const SeoMeta(title: 'M')),
        ],
      );
      expect(response.statusCode, 200);
      expect(await response.readAsString(), 'app');
    });

    test('an unknown page path still gets a real 404', () async {
      final response = await ask(
        '/gibtsnicht',
        routes: [SeoRoute(path: '/', meta: (_) => const SeoMeta())],
      );
      expect(response.statusCode, 404);
    });

    test('every answer says it depends on the User-Agent', () async {
      final routes = [
        SeoRoute(
          path: '/',
          meta: (_) => const SeoMeta(title: 'Home'),
          body: (_) => [SeoNode(tag: 'h1', text: 'Hallo')],
        ),
      ];
      final bot = await ask('/', routes: routes);
      final human = await ask('/', routes: routes, asBot: false);
      expect(bot.headers['vary'], contains('User-Agent'));
      expect(human.headers['vary'], contains('User-Agent'));
    });

    test('an existing Vary is extended, not replaced', () async {
      // Sonst verliert ein CDN die Kompressions- oder Origin-Variante.
      final response = await ask(
        '/',
        routes: [SeoRoute(path: '/', meta: (_) => const SeoMeta())],
        asBot: false,
        appHeaders: {'vary': 'Accept-Encoding, Origin'},
      );
      final vary = response.headers['vary']!;
      expect(vary, contains('Accept-Encoding'));
      expect(vary, contains('Origin'));
      expect(vary, contains('User-Agent'));
    });
  });

  group('sitemap stays parseable', () {
    test('one control character does not take the whole document down', () {
      // XML 1.0 verbietet diese Zeichen; ein einziges macht die Datei
      // unlesbar — dann fehlen dem Crawler ALLE URLs, nicht nur die eine.
      final xml = seoSitemapXml(
        routes: [
          SeoRoute(path: '/', meta: (_) => const SeoMeta()),
          SeoRoute(path: '/blog/ab', meta: (_) => const SeoMeta()),
        ],
        siteBase: 'https://x.dev',
      );
      final forbidden = xml.codeUnits
          .where((c) => c < 0x20 && c != 0x09 && c != 0x0A && c != 0x0D);
      expect(forbidden, isEmpty);
      expect(xml, contains('<loc>https://x.dev/</loc>'));
      expect(xml, contains('<loc>https://x.dev/blog/ab</loc>'));
    });
  });

  group('prerenderSite reserved names', () {
    late Directory buildDir;

    setUp(() async {
      buildDir = await Directory.systemTemp.createTemp('esen_seo_reserved');
      File('${buildDir.path}/index.html').writeAsStringSync(_template);
    });

    tearDown(() => buildDir.delete(recursive: true));

    test('a slug may not overwrite the generated infrastructure files',
        () async {
      for (final reserved in ['/robots.txt', '/sitemap.xml', '/llms.txt']) {
        expect(
          () => prerenderSite(
            routes: _routes(),
            siteBase: 'https://x.dev',
            buildDir: buildDir.path,
            additionalPaths: [reserved],
          ),
          throwsArgumentError,
          reason: 'accepted: $reserved',
        );
      }
    });

    test('a slug may not be the file every page is written to', () async {
      // /a schreibt die Datei a/index.html, /a/index.html/b will darin
      // ein Verzeichnis anlegen — je nach Reihenfolge stirbt der Build
      // mit einem FileSystemException statt mit einer Erklärung.
      for (final slug in ['/index.html', '/a/index.html/b', '/A/INDEX.HTML']) {
        expect(
          () => prerenderSite(
            routes: _routes(),
            siteBase: 'https://x.dev',
            buildDir: buildDir.path,
            additionalPaths: [slug],
          ),
          throwsArgumentError,
          reason: 'accepted: $slug',
        );
      }
    });

    test('the IndexNow key reserves its file name too', () async {
      // Der Key steht erst zur Laufzeit fest, belegt aber genauso einen
      // Dateinamen wie robots.txt — und wird zuletzt geschrieben, träfe
      // also auf ein Verzeichnis, das eine Route vorher angelegt hat.
      for (final slug in [
        '/abcdefgh.txt',
        '/abcdefgh.txt/foo',
        '/ABCDEFGH.TXT'
      ]) {
        expect(
          () => prerenderSite(
            routes: _routes(),
            siteBase: 'https://x.dev',
            buildDir: buildDir.path,
            indexNowKey: 'abcdefgh',
            additionalPaths: [slug],
          ),
          throwsArgumentError,
          reason: 'accepted: $slug',
        );
      }
    });

    test('a bad IndexNow key fails before anything is written', () async {
      // Sonst steht am Ende ein halb erneuertes build/web da: neue
      // Seiten, alte Sitemap, kein Key.
      expect(
        () => prerenderSite(
          routes: _routes(),
          siteBase: 'https://x.dev',
          buildDir: buildDir.path,
          indexNowKey: 'zu kurz',
        ),
        throwsArgumentError,
      );
      expect(File('${buildDir.path}/sitemap.xml').existsSync(), isFalse);
    });

    test('a valid key still writes its file', () async {
      final written = await prerenderSite(
        routes: _routes(),
        siteBase: 'https://x.dev',
        buildDir: buildDir.path,
        indexNowKey: 'abcdefgh',
      );
      expect(written, contains('${buildDir.path}/abcdefgh.txt'));
      expect(
        File('${buildDir.path}/abcdefgh.txt').readAsStringSync(),
        'abcdefgh',
      );
    });

    test('robots.txt keeps its real content', () async {
      await prerenderSite(
        routes: _routes(),
        siteBase: 'https://x.dev',
        buildDir: buildDir.path,
      );
      expect(
        File('${buildDir.path}/robots.txt').readAsStringSync(),
        contains('Sitemap:'),
      );
    });
  });
}
