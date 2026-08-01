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
        'position:relative',
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
