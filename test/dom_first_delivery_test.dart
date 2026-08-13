import 'dart:convert';
import 'dart:io';

import 'package:esen_seo/server.dart';
import 'package:esen_seo/src/renderer/seo_dom_first_collection_runtime.g.dart';
import 'package:esen_seo/src/renderer/seo_dom_first_tabs_runtime.g.dart';
import 'package:esen_seo/src/renderer/seo_dom_first_theme_toggle_runtime.g.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shelf/shelf.dart';

const _template = '''
<!DOCTYPE html>
<html>
<head><base href="/"><title>Flutter</title></head>
<body><script src="flutter_bootstrap.js" async></script></body>
</html>
''';

List<SeoNode> _tabs({String label = 'Overview'}) => buildSeoTabsNodes(
      tabs: [
        (
          label: label,
          nodes: [SeoNode(tag: 'p', text: 'Everything at a glance.')],
        ),
        (
          label: 'Details',
          nodes: [SeoNode(tag: 'p', text: 'All technical details.')],
        ),
      ],
      interactionId: 'product-tabs',
      initialIndex: 1,
    );

SeoRoute _domRoute({String path = '/dom'}) => SeoRoute(
      path: path,
      delivery: SeoRouteDelivery.domFirst,
      domFirstFeatures: const {SeoDomFirstFeature.tabs},
      meta: (_) => const SeoMeta(title: 'DOM tabs'),
      body: (_) => _tabs(),
    );

Future<Response> _get(Handler handler, String path, String userAgent) =>
    Future.value(handler(Request(
      'GET',
      Uri.parse('https://x.dev$path'),
      headers: {'user-agent': userAgent},
    )));

void main() {
  group('DOM-first route contract', () {
    test('requires its own route opt-in and freezes the feature set', () {
      expect(
        () => SeoRoute(
          path: '/',
          meta: (_) => const SeoMeta(),
          domFirstFeatures: const {SeoDomFirstFeature.tabs},
        ),
        throwsArgumentError,
      );

      final features = <SeoDomFirstFeature>{SeoDomFirstFeature.tabs};
      final route = SeoRoute(
        path: '/',
        meta: (_) => const SeoMeta(),
        delivery: SeoRouteDelivery.domFirst,
        domFirstFeatures: features,
      );
      features.clear();

      expect(route.isDomFirst, isTrue);
      expect(route.domFirstFeatures, {SeoDomFirstFeature.tabs});
      expect(
        () => route.domFirstFeatures.clear(),
        throwsUnsupportedError,
      );
    });

    test('standalone document is complete before its compiled runtime runs',
        () {
      final html = SeoPage.domFirstFromNodes(
        meta: const SeoMeta(title: 'DOM tabs'),
        body: _tabs(label: '<img src=x onerror=alert(1)>'),
        features: const {SeoDomFirstFeature.tabs},
        interactionNonce: ' one"<two ',
      ).toHtmlDocument();

      expect(html, contains('data-esen-seo-dom-first="true"'));
      expect(html, contains('&lt;img src=x onerror=alert(1)&gt;'));
      expect(html, contains('Everything at a glance.'));
      expect(html, contains('All technical details.'));
      expect(html, isNot(contains('<button')));
      expect(html, isNot(contains('data-esen-seo-shell')));
      expect(html, isNot(contains('data-esen-seo-interactions')));
      expect(html, isNot(contains('flutter_bootstrap.js')));
      expect(html, isNot(contains('main.dart.js')));
      expect(html, contains('data-esen-seo-dom-first-runtime'));
      expect(html, contains('nonce="one&quot;&lt;two"'));
    });

    test('compiled candidate stays inside its critical JavaScript budget', () {
      final gzipBytes = gzip.encode(utf8.encode(seoDomFirstTabsRuntime)).length;

      expect(gzipBytes, lessThanOrEqualTo(25 * 1024));
      expect(seoDomFirstTabsRuntime.toLowerCase(), isNot(contains('</script')));
      expect(seoDomFirstTabsRuntime, isNot(contains('innerHTML')));
      expect(seoDomFirstTabsRuntime, isNot(contains('outerHTML')));
      expect(seoDomFirstTabsRuntime, isNot(contains('document.write')));
      expect(seoDomFirstTabsRuntime, isNot(contains('eval(')));
    });

    test('compiled collection has an isolated runtime and style budget', () {
      final gzipBytes =
          gzip.encode(utf8.encode(seoDomFirstCollectionRuntime)).length;
      final html = seoDomFirstFeatureScriptHtml(
        const {SeoDomFirstFeature.collection},
        nonce: 'safe',
      );
      final style = seoDomFirstFeatureStyleHtml(
        const {SeoDomFirstFeature.collection},
      );

      expect(gzipBytes, lessThanOrEqualTo(25 * 1024));
      expect(html, contains('data-esen-seo-dom-first-runtime'));
      expect(html, contains('nonce="safe"'));
      expect(style, contains('data-esen-component="collection"'));
      expect(seoDomFirstCollectionRuntime.toLowerCase(),
          isNot(contains('</script')));
      expect(seoDomFirstCollectionRuntime, isNot(contains('innerHTML')));
      expect(seoDomFirstCollectionRuntime, isNot(contains('outerHTML')));
      expect(seoDomFirstCollectionRuntime, isNot(contains('document.write')));
      expect(seoDomFirstCollectionRuntime, isNot(contains('eval(')));
    });

    test('theme toggle has a pre-paint bootstrap and isolated budget', () {
      final gzipBytes =
          gzip.encode(utf8.encode(seoDomFirstThemeToggleRuntime)).length;
      final page = SeoPage.domFirstFromNodes(
        body: buildSeoThemeToggleNodes(),
        features: const {SeoDomFirstFeature.themeToggle},
        interactionNonce: 'safe',
      ).toHtmlDocument();
      final bootstrapIndex = page.indexOf('data-esen-seo-dom-first-bootstrap');
      final styleIndex = page.indexOf('data-esen-seo-style');
      final bodyIndex = page.indexOf('<body>');

      expect(gzipBytes, lessThanOrEqualTo(25 * 1024));
      expect(bootstrapIndex, greaterThan(0));
      expect(styleIndex, greaterThan(bootstrapIndex));
      expect(bodyIndex, greaterThan(styleIndex));
      expect(page, contains('localStorage.getItem("esen.theme")'));
      expect(page, contains('nonce="safe"'));
      expect(page, contains('data-esen-component="theme-toggle"'));
      expect(page, contains(seoDomFirstThemeToggleRuntime));
      expect(seoDomFirstThemeToggleRuntime.toLowerCase(),
          isNot(contains('</script')));
      expect(seoDomFirstThemeToggleRuntime, isNot(contains('innerHTML')));
      expect(seoDomFirstThemeToggleRuntime, isNot(contains('outerHTML')));
      expect(seoDomFirstThemeToggleRuntime, isNot(contains('document.write')));
      expect(seoDomFirstThemeToggleRuntime, isNot(contains('eval(')));
    });

    test('collection plus theme stays inside the route JavaScript budget', () {
      final page = SeoPage.domFirstFromNodes(
        body: buildSeoThemeToggleNodes(),
        features: const {
          SeoDomFirstFeature.collection,
          SeoDomFirstFeature.themeToggle,
        },
      ).toHtmlDocument();
      final scripts = RegExp(r'<script[^>]*>([\s\S]*?)</script>')
          .allMatches(page)
          .map((match) => match.group(1)!)
          .where((script) => script.isNotEmpty);
      final levelNineGzip = GZipCodec(level: 9);
      final gzipBytes = scripts.fold<int>(
        0,
        (sum, script) => sum + levelNineGzip.encode(utf8.encode(script)).length,
      );

      expect(gzipBytes, lessThanOrEqualTo(25 * 1024));
    });

    test('DOM-first feature runtimes remain independently selectable', () {
      final collectionOnly = seoDomFirstFeatureScriptHtml(
        const {SeoDomFirstFeature.collection},
      );
      final tabsOnly = seoDomFirstFeatureScriptHtml(
        const {SeoDomFirstFeature.tabs},
      );
      final both = seoDomFirstFeatureScriptHtml(
        const {SeoDomFirstFeature.tabs, SeoDomFirstFeature.collection},
      );
      final themeOnly = seoDomFirstFeatureScriptHtml(
        const {SeoDomFirstFeature.themeToggle},
      );

      expect(collectionOnly, contains(seoDomFirstCollectionRuntime));
      expect(collectionOnly, isNot(contains(seoDomFirstTabsRuntime)));
      expect(tabsOnly, contains(seoDomFirstTabsRuntime));
      expect(tabsOnly, isNot(contains(seoDomFirstCollectionRuntime)));
      expect(themeOnly, contains(seoDomFirstThemeToggleRuntime));
      expect(themeOnly, isNot(contains(seoDomFirstTabsRuntime)));
      expect(themeOnly, isNot(contains(seoDomFirstCollectionRuntime)));
      expect(both, contains(seoDomFirstTabsRuntime));
      expect(both, contains(seoDomFirstCollectionRuntime));
      expect('data-esen-seo-dom-first-runtime'.allMatches(both), hasLength(1));
    });
  });

  group('DOM-first server delivery', () {
    test('human and crawler receive the same final document', () async {
      var appHits = 0;
      final handler = const Pipeline()
          .addMiddleware(seoBotMiddleware(
        routes: [_domRoute()],
        siteBase: 'https://x.dev',
      ))
          .addHandler((_) {
        appHits++;
        return Response.ok('app');
      });

      final bot = await _get(handler, '/dom', 'Googlebot');
      final human = await _get(handler, '/dom', 'Mozilla/5.0');
      final botHtml = await bot.readAsString();
      final humanHtml = await human.readAsString();

      expect(botHtml, humanHtml);
      expect(bot.headers['x-esen-seo'], 'dom-first');
      expect(human.headers['x-esen-seo'], 'dom-first');
      expect(bot.headers['vary'], isNull);
      expect(human.headers['vary'], isNull);
      expect(appHits, 0);
    });

    test('redirects and errors remain final even when redirects are off',
        () async {
      final routes = [
        SeoRoute.dynamic(
          path: '/old',
          delivery: SeoRouteDelivery.domFirst,
          resolve: (_) => const SeoRedirect('/new'),
        ),
        SeoRoute.dynamic(
          path: '/missing',
          delivery: SeoRouteDelivery.domFirst,
          resolve: (_) => SeoDocument.notFound(),
        ),
      ];
      final handler = const Pipeline()
          .addMiddleware(seoBotMiddleware(
            routes: routes,
            siteBase: 'https://x.dev',
            applyResolverRedirects: SeoRedirectScope.off,
          ))
          .addHandler((_) => Response.ok('app'));

      for (final userAgent in const ['Googlebot', 'Mozilla/5.0']) {
        final redirect = await _get(handler, '/old', userAgent);
        expect(redirect.statusCode, 301);
        expect(redirect.headers['location'], '/new');

        final missing = await _get(handler, '/missing', userAgent);
        expect(missing.statusCode, 404);
        expect(missing.headers['x-esen-seo'], 'dom-first');
        expect(await missing.readAsString(), contains('Page not found'));
      }
    });

    test('keeps legitimate cache variants without varying on User-Agent',
        () async {
      final route = SeoRoute.dynamic(
        path: '/language',
        delivery: SeoRouteDelivery.domFirst,
        resolve: (_) => SeoDocument(
          body: [SeoNode(tag: 'h1', text: 'Language')],
          headers: const {'vary': 'Accept-Language'},
        ),
      );
      final handler = const Pipeline()
          .addMiddleware(seoBotMiddleware(
            routes: [route],
            siteBase: 'https://x.dev',
          ))
          .addHandler((_) => Response.ok('app'));

      final response = await _get(handler, '/language', 'Mozilla/5.0');
      expect(response.headers['vary'], 'Accept-Language');
    });

    test('an empty document stays final instead of falling into Flutter',
        () async {
      var appHits = 0;
      final route = SeoRoute.dynamic(
        path: '/empty',
        delivery: SeoRouteDelivery.domFirst,
        resolve: (_) => const SeoDocument(),
      );
      final handler = const Pipeline()
          .addMiddleware(seoBotMiddleware(
        routes: [route],
        siteBase: 'https://x.dev',
      ))
          .addHandler((_) {
        appHits++;
        return Response.ok('app');
      });

      final response = await _get(handler, '/empty', 'Mozilla/5.0');
      expect(response.statusCode, 200);
      expect(
          await response.readAsString(), contains('data-esen-seo-dom-first'));
      expect(appHits, 0);
    });

    test('resolver failures are reported and never disguised as the app',
        () async {
      var appHits = 0;
      var reports = 0;
      final route = SeoRoute.dynamic(
        path: '/failure',
        delivery: SeoRouteDelivery.domFirst,
        resolve: (_) => throw StateError('database unavailable'),
      );
      final handler = const Pipeline()
          .addMiddleware(seoBotMiddleware(
        routes: [route],
        siteBase: 'https://x.dev',
        onResolveError: (_, __, ___) => reports++,
      ))
          .addHandler((_) {
        appHits++;
        return Response.ok('app');
      });

      await expectLater(
        _get(handler, '/failure', 'Mozilla/5.0'),
        throwsA(isA<StateError>()),
      );
      expect(reports, 1);
      expect(appHits, 0);
    });
  });

  group('DOM-first prerendering', () {
    late Directory buildDir;

    setUp(() async {
      buildDir = await Directory.systemTemp.createTemp('esen_dom_first');
      File('${buildDir.path}/index.html').writeAsStringSync(_template);
    });

    tearDown(() => buildDir.delete(recursive: true));

    test('omits Flutter only on the opted-in route', () async {
      await prerenderSite(
        routes: [
          SeoRoute(
            path: '/flutter',
            meta: (_) => const SeoMeta(title: 'Flutter page'),
            body: (_) => [SeoNode(tag: 'h1', text: 'Flutter page')],
          ),
          _domRoute(),
        ],
        siteBase: 'https://x.dev',
        buildDir: buildDir.path,
        writeSitemap: false,
        writeRobotsTxt: false,
        writeLlmsTxt: false,
        write404Page: false,
      );

      final flutterHtml =
          File('${buildDir.path}/flutter/index.html').readAsStringSync();
      final domHtml =
          File('${buildDir.path}/dom/index.html').readAsStringSync();

      expect(flutterHtml, contains('flutter_bootstrap.js'));
      expect(flutterHtml, contains('aria-hidden="true" inert'));
      expect(flutterHtml, isNot(contains('data-esen-seo-dom-first')));
      expect(domHtml, isNot(contains('flutter_bootstrap.js')));
      expect(domHtml, isNot(contains('<base href="/">')));
      expect(domHtml, contains('data-esen-seo-dom-first="true"'));
      expect(domHtml, contains('data-esen-seo-dom-first-runtime'));
      expect(domHtml, contains('font-family:system-ui'));
      expect(domHtml, contains('All technical details.'));
    });

    test('keeps Flutter and DOM-first stylesheets independent', () async {
      await prerenderSite(
        routes: [
          SeoRoute(
            path: '/flutter',
            meta: (_) => const SeoMeta(title: 'Flutter page'),
            body: (_) => [SeoNode(tag: 'h1', text: 'Flutter page')],
          ),
          _domRoute(),
        ],
        siteBase: 'https://x.dev',
        buildDir: buildDir.path,
        stylesheet: '#esen-seo-content{--flutter-shell-only:1}',
        domFirstStylesheet: '#esen-seo-content{--dom-first-only:1}',
        writeSitemap: false,
        writeRobotsTxt: false,
        writeLlmsTxt: false,
        write404Page: false,
      );

      final flutterHtml =
          File('${buildDir.path}/flutter/index.html').readAsStringSync();
      final domHtml =
          File('${buildDir.path}/dom/index.html').readAsStringSync();

      expect(flutterHtml, contains('--flutter-shell-only:1'));
      expect(flutterHtml, isNot(contains('--dom-first-only:1')));
      expect(domHtml, contains('--dom-first-only:1'));
      expect(domHtml, isNot(contains('--flutter-shell-only:1')));
    });
  });
}
