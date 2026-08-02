import 'dart:io';

import 'package:esen_seo/server.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shelf/shelf.dart';

const _googlebot = 'Mozilla/5.0 (compatible; Googlebot/2.1)';
const _human = 'Mozilla/5.0';

const _template = '''
<!DOCTYPE html>
<html>
<head><title>example</title></head>
<body></body>
</html>
''';

List<SeoRoute> _dynamicTable() => [
      SeoRoute(path: '/', meta: (_) => const SeoMeta(title: 'Home')),
      SeoRoute.dynamic(
        path: '/p/:id',
        enumeratePaths: () async => ['/p/a', '/p/gone', '/p/old'],
        resolve: (r) async {
          switch (r['id']) {
            case 'gone':
              return SeoDocument.gone();
            case 'old':
              return const SeoRedirect('/p/a');
            default:
              return SeoDocument(
                meta: SeoMeta(title: 'Product ${r['id']}'),
                body: r.detail == SeoDetail.head
                    ? const []
                    : [SeoNode(tag: 'h1', text: 'Product ${r['id']}')],
              );
          }
        },
      ),
    ];

Future<Response> _ask(
  List<SeoRoute> routes,
  String path, {
  bool asBot = true,
}) async {
  final handler = const Pipeline()
      .addMiddleware(
          seoBotMiddleware(routes: routes, siteBase: 'https://x.dev'))
      .addHandler((_) => Response.ok('app'));
  return handler(Request(
    'GET',
    Uri.parse('http://localhost$path'),
    headers: {'user-agent': asBot ? _googlebot : _human},
  ));
}

void main() {
  group('bot middleware serves resolver output', () {
    test('a dynamic page is rendered for a bot', () async {
      final res = await _ask(_dynamicTable(), '/p/a');
      expect(res.statusCode, 200);
      final body = await res.readAsString();
      expect(body, contains('<h1>Product a</h1>'));
      expect(res.headers['x-esen-seo'], 'ssr');
    });

    test('a gone page answers 410 for a bot', () async {
      final res = await _ask(_dynamicTable(), '/p/gone');
      expect(res.statusCode, 410);
    });

    test('a resolver redirect answers 301 for a bot', () async {
      final res = await _ask(_dynamicTable(), '/p/old');
      expect(res.statusCode, 301);
      expect(res.headers['location'], '/p/a');
    });

    test('a human still gets the app for a dynamic page', () async {
      final res = await _ask(_dynamicTable(), '/p/a', asBot: false);
      expect(res.statusCode, 200);
      expect(await res.readAsString(), 'app');
    });

    test('the served sitemap resolves the dynamic table', () async {
      final handler = const Pipeline()
          .addMiddleware(seoBotMiddleware(
              routes: _dynamicTable(), siteBase: 'https://x.dev'))
          .addHandler((_) => Response.ok('app'));
      final res = await handler(Request(
        'GET',
        Uri.parse('http://localhost/sitemap.xml'),
      ));
      final xml = await res.readAsString();
      expect(xml, contains('<loc>https://x.dev/p/a</loc>'));
      // The 410 and the redirect never reach the sitemap.
      expect(xml, isNot(contains('/p/gone')));
      expect(xml, isNot(contains('/p/old')));
    });

    test('an unsafe resolver redirect never becomes a Location header',
        () async {
      final routes = [
        SeoRoute.dynamic(
          path: '/evil',
          resolve: (_) async => const SeoRedirect('javascript:alert(1)'),
        ),
      ];
      final res = await _ask(routes, '/evil');
      expect(res.headers['location'], isNull);
      expect(res.statusCode, 404);
    });
  });

  group('prerenderSite bakes resolver output', () {
    late Directory buildDir;

    setUp(() async {
      buildDir = await Directory.systemTemp.createTemp('esen_seo_resolver');
      File('${buildDir.path}/index.html').writeAsStringSync(_template);
    });

    tearDown(() => buildDir.delete(recursive: true));

    test('writes a file per resolved page, skips redirect and gone', () async {
      final skipped = <String>[];
      await prerenderSite(
        routes: _dynamicTable(),
        siteBase: 'https://x.dev',
        buildDir: buildDir.path,
        onSkipped: (path, _) => skipped.add(path),
      );
      expect(File('${buildDir.path}/p/a/index.html').existsSync(), isTrue);
      expect(
        File('${buildDir.path}/p/a/index.html').readAsStringSync(),
        contains('Product a'),
      );
      // A static host cannot emit a 301 or a 410 status from a file.
      expect(File('${buildDir.path}/p/old/index.html').existsSync(), isFalse);
      expect(File('${buildDir.path}/p/gone/index.html').existsSync(), isFalse);
      expect(skipped, containsAll(['/p/old', '/p/gone']));
    });

    test('the baked sitemap lists only the indexable pages', () async {
      await prerenderSite(
        routes: _dynamicTable(),
        siteBase: 'https://x.dev',
        buildDir: buildDir.path,
      );
      final xml = File('${buildDir.path}/sitemap.xml').readAsStringSync();
      expect(xml, contains('https://x.dev/p/a'));
      expect(xml, isNot(contains('/p/gone')));
    });

    test('a throwing resolver fails the build by default', () async {
      expect(
        () => prerenderSite(
          routes: [
            SeoRoute.dynamic(
              path: '/boom',
              resolve: (_) async => throw StateError('db down'),
            ),
          ],
          siteBase: 'https://x.dev',
          buildDir: buildDir.path,
        ),
        throwsStateError,
      );
    });

    test('an enumerated path that escapes the build dir is refused', () async {
      // enumeratePaths hands URL generation to (eventually) a database,
      // and those strings become file paths here for the first time.
      expect(
        () => prerenderSite(
          routes: [
            SeoRoute.dynamic(
              path: '/p/:id',
              enumeratePaths: () async => ['/p/../../etc/passwd'],
              resolve: (_) async => const SeoDocument(),
            ),
          ],
          siteBase: 'https://x.dev',
          buildDir: buildDir.path,
        ),
        throwsArgumentError,
      );
      // Nothing was written before the check failed.
      expect(File('${buildDir.path}/p').existsSync(), isFalse);
    });
  });
}
