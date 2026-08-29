import 'dart:convert';
import 'dart:io';

import 'package:esen_seo/server.dart';
import 'package:esen_seo/src/renderer/seo_dom_first_navigation_runtime.g.dart';
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

const _navigation = {
  SeoDomFirstFeature.navigation,
  SeoDomFirstFeature.themeToggle,
};

const _tabsNavigation = {
  SeoDomFirstFeature.navigation,
  SeoDomFirstFeature.tabs,
  SeoDomFirstFeature.themeToggle,
};

SeoRoute _route(
  String path, {
  Set<SeoDomFirstFeature> features = _navigation,
}) =>
    SeoRoute(
      path: path,
      delivery: SeoRouteDelivery.domFirst,
      domFirstFeatures: features,
      meta: (_) => SeoMeta(
        title: 'Page $path',
        description: 'Description $path',
        canonicalUrl: 'https://x.dev$path',
      ),
      body: (_) => [
        SeoNode(tag: 'main', children: [
          SeoNode(tag: 'h1', text: 'Page $path'),
          SeoNode(
            tag: 'a',
            text: 'Home',
            attributes: const {'href': '/'},
          ),
        ]),
      ],
    );

SeoDomFirstNavigationPlan _plan(
  List<SeoRoute> routes,
  SeoRoute current, {
  String siteBase = 'https://x.dev',
}) =>
    buildSeoDomFirstNavigationPlan(
      routes: routes,
      currentRoute: current,
      siteBase: siteBase,
    )!;

Future<Response> _get(Handler handler, String uri) => Future.value(
      handler(
        Request(
          'GET',
          Uri.parse(uri),
          headers: const {'user-agent': 'Mozilla/5.0'},
        ),
      ),
    );

void main() {
  group('navigation route contract', () {
    test('accepts only the closed compatible feature profile', () {
      expect(
        () => SeoRoute(
          path: '/',
          meta: (_) => const SeoMeta(),
          domFirstFeatures: const {SeoDomFirstFeature.navigation},
        ),
        throwsArgumentError,
      );
      final tabs = _route('/', features: _tabsNavigation);
      expect(
        seoDomFirstNavigationProfile(tabs),
        'navigation.tabs.themeToggle',
      );
      expect(
        () => _route(
          '/carousel',
          features: const {
            SeoDomFirstFeature.navigation,
            SeoDomFirstFeature.carousel,
          },
        ),
        throwsArgumentError,
      );
      expect(
        () => SeoRoute(
          path: '/',
          delivery: SeoRouteDelivery.domFirst,
          domFirstFeatures: const {SeoDomFirstFeature.navigation},
          applicationRuntime:
              const SeoDomFirstApplicationRuntime.tabs('product-tabs'),
          meta: (_) => const SeoMeta(),
        ),
        throwsArgumentError,
      );

      final route = _route(
        '/',
        features: const {
          SeoDomFirstFeature.navigation,
          SeoDomFirstFeature.themeToggle,
          SeoDomFirstFeature.motion,
        },
      );
      expect(
        seoDomFirstNavigationProfile(route),
        'motion.navigation.themeToggle',
      );
    });

    test('preserves route order, profiles and a decoded site prefix', () {
      final home = _route('/');
      final article = _route('/blog/:slug');
      final motion = _route(
        '/motion',
        features: const {
          SeoDomFirstFeature.navigation,
          SeoDomFirstFeature.themeToggle,
          SeoDomFirstFeature.motion,
        },
      );
      final flutter = SeoRoute(
        path: '/app',
        meta: (_) => const SeoMeta(title: 'App'),
      );
      final routes = [home, article, motion, flutter];

      final plan = _plan(
        routes,
        article,
        siteBase: 'https://x.dev/%C3%BCber/',
      );
      final decoded = jsonDecode(plan.manifestJson) as Map<String, dynamic>;

      expect(plan.basePath, '/über');
      expect(plan.profile, 'navigation.themeToggle');
      expect(
        plan.entries.map((entry) => entry.pattern),
        ['/', '/blog/:slug', '/motion', '/app'],
      );
      expect(
        plan.entries.map((entry) => entry.profile),
        [
          'navigation.themeToggle',
          'navigation.themeToggle',
          'motion.navigation.themeToggle',
          null,
        ],
      );
      expect(decoded['base'], '/über');
      expect(decoded['routes'], [
        ['/', 'navigation.themeToggle'],
        ['/blog/:slug', 'navigation.themeToggle'],
        ['/motion', 'motion.navigation.themeToggle'],
        ['/app', null],
      ]);
      expect(() => plan.entries.clear(), throwsUnsupportedError);

      final escapedPercent = _plan(
        routes,
        home,
        siteBase: 'https://x.dev/%252F/',
      );
      expect(escapedPercent.basePath, '/%2F');
    });

    test('escapes manifest text for an inline JSON script', () {
      final route = _route('/a<b&c>');
      final plan = _plan([route], route);

      expect(plan.manifestJson, contains(r'/a\u003cb\u0026c\u003e'));
      expect(plan.manifestJson, isNot(contains('</script')));
      expect(
        (jsonDecode(plan.manifestJson) as Map<String, dynamic>)['routes'],
        [
          ['/a<b&c>', 'navigation.themeToggle'],
        ],
      );
    });

    test('rejects malformed origins, foreign route instances and bounds', () {
      final route = _route('/');
      final routes = [route];

      for (final siteBase in [
        '',
        '/relative',
        'ftp://x.dev',
        'https://user:pass@x.dev',
        'https://x.dev/?query=1',
        'https://x.dev/#fragment',
        'https://x.dev//repo',
        'https://x.dev/repo%2Fnested',
        'https://x.dev/repo%5Cnested',
        'https://x.dev/%2e%2e/repo',
        'https://x.dev/%zz',
        'https://x.dev/safe\u202Ehidden',
        'https://x.dev/${List.filled(257, 'x').join()}',
      ]) {
        expect(
          () => _plan(routes, route, siteBase: siteBase),
          throwsArgumentError,
          reason: siteBase,
        );
      }
      expect(
        () => _plan(routes, _route('/')),
        throwsArgumentError,
      );

      final tooMany = [
        route,
        for (var index = 0; index < seoDomFirstNavigationMaxRoutes; index++)
          SeoRoute(
            path: '/route-$index',
            meta: (_) => const SeoMeta(),
          ),
      ];
      expect(() => _plan(tooMany, route), throwsArgumentError);

      final longRoute = _route(
        '/${List.filled(seoDomFirstNavigationMaxPatternLength, 'a').join()}',
      );
      expect(() => _plan([longRoute], longRoute), throwsArgumentError);

      final bidiRoute = _route('/safe\u202Ehidden');
      expect(() => _plan([bidiRoute], bidiRoute), throwsArgumentError);

      for (final path in [
        '/%zz',
        '/%2e%2e',
        '/%0a',
        '/safe%E2%80%AEhidden',
        r'/bad\path',
      ]) {
        final invalid = _route(path);
        expect(
          () => _plan([invalid], invalid),
          throwsArgumentError,
          reason: path,
        );
      }
    });

    test('rejects a manifest that exceeds its byte budget', () {
      final routes = <SeoRoute>[];
      for (var index = 0; index < seoDomFirstNavigationMaxRoutes; index++) {
        routes.add(
          _route('/${List.filled(180, 'x').join()}-$index'),
        );
      }

      expect(() => _plan(routes, routes.first), throwsArgumentError);
    });
  });

  group('navigation document', () {
    test('runtime remains isolated, inert by default and inside budget', () {
      final gzipBytes =
          gzip.encode(utf8.encode(seoDomFirstNavigationRuntime)).length;
      final navigationOnly = seoDomFirstFeatureScriptHtml(
        const {SeoDomFirstFeature.navigation},
      );
      final themeOnly = seoDomFirstFeatureScriptHtml(
        const {SeoDomFirstFeature.themeToggle},
      );
      final tabsNavigation = utf8.encode(
        '$seoDomFirstNavigationRuntime$seoDomFirstTabsRuntime'
        '$seoDomFirstThemeToggleRuntime',
      );
      final tabsNavigationHtml = seoDomFirstFeatureScriptHtml(_tabsNavigation);

      expect(gzipBytes, lessThanOrEqualTo(25 * 1024));
      expect(
        gzip.encode(tabsNavigation).length,
        lessThanOrEqualTo(25 * 1024),
      );
      expect(
        tabsNavigationHtml.indexOf(seoDomFirstNavigationRuntime),
        lessThan(tabsNavigationHtml.indexOf(seoDomFirstTabsRuntime)),
      );
      expect(seoDomFirstFeatureScriptHtml(const {}), isEmpty);
      expect(navigationOnly, contains(seoDomFirstNavigationRuntime));
      expect(navigationOnly, isNot(contains('localStorage.getItem')));
      expect(themeOnly, isNot(contains(seoDomFirstNavigationRuntime)));
      expect(
        seoDomFirstFeatureScriptHtml(_navigation),
        allOf(
          contains(seoDomFirstNavigationRuntime),
          contains('localStorage.getItem'),
        ),
      );
      expect(
        seoDomFirstNavigationRuntime.toLowerCase(),
        isNot(contains('</script')),
      );
      expect(seoDomFirstNavigationRuntime, isNot(contains('innerHTML')));
      expect(seoDomFirstNavigationRuntime, isNot(contains('outerHTML')));
      expect(seoDomFirstNavigationRuntime, isNot(contains('document.write')));
      expect(seoDomFirstNavigationRuntime, isNot(contains('eval(')));
      expect(seoDomFirstNavigationRuntime, isNot(contains('.arrayBuffer()')));
      expect(seoDomFirstNavigationRuntime, contains('.body.getReader()'));
      expect(seoDomFirstNavigationRuntime, contains('samePlan('));
      expect(
        seoDomFirstNavigationRuntime.indexOf('if(push)history.pushState'),
        lessThan(
          seoDomFirstNavigationRuntime.indexOf('c.replaceWith(newContent)'),
        ),
      );
    });

    test('requires an exactly matching plan', () {
      final route = _route('/');
      final plan = _plan([route], route);

      expect(
        () => SeoPage.domFirstFromNodes(
          body: const [],
          features: _navigation,
        ),
        throwsArgumentError,
      );
      expect(
        () => SeoPage.domFirstFromNodes(
          body: const [],
          features: const {SeoDomFirstFeature.themeToggle},
          navigationPlan: plan,
        ),
        throwsArgumentError,
      );
    });

    test('marks replaceable head nodes and emits one bounded manifest', () {
      final route = _route('/');
      final plan = _plan([route], route);
      final html = SeoPage.domFirstFromNodes(
        meta: const SeoMeta(
          title: 'Home',
          description: 'Safe description',
          canonicalUrl: 'https://x.dev/',
          alternates: {'de': 'https://x.dev/'},
        ),
        body: [SeoNode(tag: 'main', text: 'Home')],
        features: _navigation,
        navigationPlan: plan,
        interactionNonce: 'safe',
      ).toHtmlDocument();

      expect(
        RegExp('<script[^>]*$seoDomFirstNavigationManifestAttribute')
            .allMatches(html),
        hasLength(1),
      );
      expect(
        RegExp('<script[^>]*$seoDomFirstNavigationManifestAttribute[^>]*'
                'nonce="safe"')
            .hasMatch(html),
        isTrue,
      );
      expect(html, contains('data-esen-navigation-profile='));
      expect(html, contains('<title data-esen-seo-navigation-head>Home'));
      expect(
        html,
        contains('<meta name="description" content="Safe description" '
            'data-esen-seo-navigation-head/>'),
      );
      expect(
        html,
        contains('<link rel="canonical" href="https://x.dev/" '
            'data-esen-seo-navigation-head/>'),
      );
      expect(html, contains(seoDomFirstNavigationRuntime));
      expect(html, contains('nonce="safe"'));
      expect(html, isNot(contains('flutter_bootstrap.js')));
      expect(html, isNot(contains('main.dart.js')));
    });

    test('does not change a document that did not opt in', () {
      final html = SeoPage.domFirstFromNodes(
        meta: const SeoMeta(title: 'Static'),
        body: [SeoNode(tag: 'p', text: 'Static body')],
        features: const {SeoDomFirstFeature.themeToggle},
      ).toHtmlDocument();

      expect(html, isNot(contains(seoDomFirstNavigationManifestAttribute)));
      expect(html, isNot(contains(seoDomFirstNavigationHeadAttribute)));
      expect(html, isNot(contains(seoDomFirstNavigationRuntime)));
      expect(html, startsWith('<!DOCTYPE html><html lang="en"><head>'));
    });
  });

  group('navigation delivery', () {
    test('requires siteBase when a route opts in', () {
      expect(
        () => seoBotMiddleware(routes: [_route('/')]),
        throwsArgumentError,
      );
    });

    test('SSR embeds the ordered manifest for dynamic subpath routes',
        () async {
      final home = _route('/');
      final article = SeoRoute.dynamic(
        path: '/blog/:slug',
        delivery: SeoRouteDelivery.domFirst,
        domFirstFeatures: _navigation,
        resolve: (request) => SeoDocument(
          meta: SeoMeta(title: request.param('slug')),
          body: [SeoNode(tag: 'h1', text: request.param('slug'))],
        ),
      );
      final flutter = SeoRoute(
        path: '/admin',
        meta: (_) => const SeoMeta(title: 'Admin'),
      );
      final handler = const Pipeline()
          .addMiddleware(
            seoBotMiddleware(
              routes: [home, article, flutter],
              siteBase: 'https://x.dev/repo',
            ),
          )
          .addHandler((_) => Response.ok('app'));

      final response = await _get(handler, 'https://x.dev/repo/blog/hello');
      final html = await response.readAsString();

      expect(response.statusCode, 200);
      expect(response.headers['x-esen-seo'], 'dom-first');
      expect(html, contains('"base":"/repo"'));
      expect(html, contains('/blog/:slug'));
      expect(html, contains('/admin'));
      expect(html, contains('hello'));
      expect(html, isNot(contains('flutter_bootstrap.js')));
    });

    test('prerender writes navigation only to compatible routes', () async {
      final buildDir = await Directory.systemTemp.createTemp(
        'esen_dom_first_navigation',
      );
      addTearDown(() => buildDir.delete(recursive: true));
      File('${buildDir.path}/index.html').writeAsStringSync(_template);
      final home = _route('/');
      final about = _route('/about');
      final flutter = SeoRoute(
        path: '/admin',
        meta: (_) => const SeoMeta(title: 'Admin'),
        body: (_) => [SeoNode(tag: 'h1', text: 'Admin')],
      );

      await prerenderSite(
        routes: [home, about, flutter],
        siteBase: 'https://x.dev',
        buildDir: buildDir.path,
        writeSitemap: false,
        writeRobotsTxt: false,
        writeLlmsTxt: false,
        write404Page: false,
      );

      final homeHtml = File('${buildDir.path}/index.html').readAsStringSync();
      final aboutHtml =
          File('${buildDir.path}/about/index.html').readAsStringSync();
      final flutterHtml =
          File('${buildDir.path}/admin/index.html').readAsStringSync();

      expect(homeHtml, contains(seoDomFirstNavigationManifestAttribute));
      expect(aboutHtml, contains(seoDomFirstNavigationManifestAttribute));
      expect(homeHtml, isNot(contains('flutter_bootstrap.js')));
      expect(aboutHtml, isNot(contains('flutter_bootstrap.js')));
      expect(flutterHtml, contains('flutter_bootstrap.js'));
      expect(
        flutterHtml,
        isNot(contains(seoDomFirstNavigationManifestAttribute)),
      );
    });
  });
}
