import 'dart:io';

import 'package:esen_seo/server.dart';
import 'package:flutter_test/flutter_test.dart';

const _template = '''
<!DOCTYPE html>
<html>
<head>
  <base href="/">
  <meta charset="UTF-8">
  <meta name="description" content="A new Flutter project.">
  <title>example</title>
</head>
<body>
  <script src="flutter_bootstrap.js" async></script>
</body>
</html>
''';

List<SeoRoute> _routes() => [
      SeoRoute(
        path: '/',
        lang: 'de',
        meta: (_) => const SeoMeta(title: 'Home', description: 'Startseite'),
        body: (_) => [SeoNode(tag: 'h1', text: 'Willkommen')],
      ),
      SeoRoute(
        path: '/demo',
        meta: (_) => const SeoMeta(title: 'Demo'),
      ),
      SeoRoute(
        path: '/blog/:slug',
        meta: (params) => SeoMeta(title: 'Blog — ${params['slug']}'),
        body: (params) => [SeoNode(tag: 'h1', text: params['slug']!)],
      ),
    ];

void main() {
  group('prerenderSite', () {
    late Directory buildDir;

    setUp(() async {
      buildDir = await Directory.systemTemp.createTemp('esen_seo_prerender');
      File('${buildDir.path}/index.html').writeAsStringSync(_template);
    });

    tearDown(() => buildDir.delete(recursive: true));

    test('bakes meta, body and app bootstrap into static files', () async {
      final written = await prerenderSite(
        routes: _routes(),
        siteBase: 'https://x.dev',
        buildDir: buildDir.path,
        additionalPaths: ['/blog/hallo'],
      );

      final index = File('${buildDir.path}/index.html').readAsStringSync();
      // Neue Meta-Daten drin, Template-Reste raus:
      expect(index, contains('<title>Home</title>'));
      expect(index, isNot(contains('<title>example</title>')));
      expect(index, isNot(contains('A new Flutter project.')));
      expect(index, contains('<html lang="de">'));
      expect(
        index,
        contains('<link rel="canonical" href="https://x.dev/"/>'),
      );
      // Semantischer Body im versteckten Container:
      expect(index, contains('id="esen-seo-content"'));
      expect(index, contains('<h1>Willkommen</h1>'));
      // Die Flutter-App bleibt vollständig funktionsfähig:
      expect(index, contains('flutter_bootstrap.js'));
      expect(index, contains('<base href="/">'));

      // Pfad-Seiten als eigene index.html (Deep-Links auf Statik-Hosts):
      expect(
        File('${buildDir.path}/demo/index.html').readAsStringSync(),
        contains('<title>Demo</title>'),
      );
      expect(
        File('${buildDir.path}/blog/hallo/index.html').readAsStringSync(),
        contains('<h1>hallo</h1>'),
      );

      // Infrastruktur-Dateien:
      final sitemap = File('${buildDir.path}/sitemap.xml').readAsStringSync();
      expect(sitemap, contains('<loc>https://x.dev/blog/hallo</loc>'));
      expect(
        File('${buildDir.path}/robots.txt').readAsStringSync(),
        contains('Sitemap: https://x.dev/sitemap.xml'),
      );

      // AI-Crawler-Manifeste:
      expect(
        File('${buildDir.path}/llms.txt').readAsStringSync(),
        contains('- [Demo](https://x.dev/demo)'),
      );
      final llmsFull =
          File('${buildDir.path}/llms-full.txt').readAsStringSync();
      expect(llmsFull, contains('## Home\nhttps://x.dev/'));
      expect(llmsFull, contains('# Willkommen'));

      // 404-Seite für Statik-Hosts (Firebase & Co. liefern sie mit
      // echtem 404-Status aus):
      final notFound = File('${buildDir.path}/404.html').readAsStringSync();
      expect(notFound, contains('<title>404 — Page not found</title>'));
      expect(notFound, contains('<meta name="robots" content="noindex"/>'));
      expect(notFound, contains('<h1>404 — Page not found</h1>'));
      // Die Flutter-App bootet auch auf der 404-Seite:
      expect(notFound, contains('flutter_bootstrap.js'));

      // /, /demo, /blog/hallo + sitemap + robots + llms + llms-full + 404:
      expect(written, hasLength(8));
    });

    test('writes the IndexNow key file when a key is set', () async {
      await prerenderSite(
        routes: _routes(),
        siteBase: 'https://x.dev',
        buildDir: buildDir.path,
        indexNowKey: 'abc123def456',
      );
      expect(
        File('${buildDir.path}/abc123def456.txt').readAsStringSync(),
        'abc123def456',
      );
    });

    test('throws a clear error when the build is missing', () async {
      expect(
        () => prerenderSite(
          routes: _routes(),
          siteBase: 'https://x.dev',
          buildDir: '${buildDir.path}/gibtsnicht',
        ),
        throwsStateError,
      );
    });
  });
}
