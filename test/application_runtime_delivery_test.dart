import 'dart:io';

import 'package:esen_seo/server.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shelf/shelf.dart';

const _reference = SeoDomFirstApplicationRuntime.tabs('application-tabs');
const _javascript = '(function(){var applicationTabs=true;})();';

SeoDomFirstRuntimeArtifact _artifact([
  SeoDomFirstApplicationRuntime reference = _reference,
]) =>
    SeoDomFirstRuntimeArtifact.create(
      reference: reference,
      javascript: _javascript,
      dartVersion: '3.6.2',
    );

List<SeoNode> _tabsNodes() => buildSeoTabsNodes(
      tabs: [
        (
          label: 'First',
          nodes: [SeoNode(tag: 'p', text: 'First panel')],
        ),
        (
          label: 'Second',
          nodes: [SeoNode(tag: 'p', text: 'Second panel')],
        ),
      ],
      interactionId: 'application-tabs-control',
    );

SeoRoute _route({String path = '/application'}) => SeoRoute(
      path: path,
      delivery: SeoRouteDelivery.domFirst,
      applicationRuntime: _reference,
      meta: (_) => const SeoMeta(title: 'Application tabs'),
      body: (_) => _tabsNodes(),
    );

void main() {
  group('application runtime route contract', () {
    test('is DOM-first only and cannot double-own tabs', () {
      expect(
        () => SeoRoute(
          path: '/',
          meta: (_) => const SeoMeta(),
          applicationRuntime: _reference,
        ),
        throwsArgumentError,
      );
      expect(
        () => SeoRoute(
          path: '/',
          delivery: SeoRouteDelivery.domFirst,
          domFirstFeatures: const {SeoDomFirstFeature.tabs},
          applicationRuntime: _reference,
          meta: (_) => const SeoMeta(),
        ),
        throwsArgumentError,
      );
      expect(
        () => SeoRoute(
          path: '/',
          delivery: SeoRouteDelivery.domFirst,
          applicationRuntime:
              const SeoDomFirstApplicationRuntime.tabs('../escape'),
          meta: (_) => const SeoMeta(),
        ),
        throwsArgumentError,
      );

      final route = SeoRoute(
        path: '/',
        delivery: SeoRouteDelivery.domFirst,
        domFirstFeatures: const {SeoDomFirstFeature.collection},
        applicationRuntime: _reference,
        meta: (_) => const SeoMeta(),
      );
      expect(route.applicationRuntime, _reference);
      expect(route.domFirstFeatures, {SeoDomFirstFeature.collection});
    });

    test('page embeds only the verified application script with CSP data', () {
      final artifact = _artifact();
      final html = SeoPage.domFirstFromNodes(
        body: _tabsNodes(),
        applicationRuntime: artifact,
        interactionNonce: ' safe"nonce ',
      ).toHtmlDocument();

      expect(html, contains('data-esen-component="tabs"'));
      expect(html, contains(seoDomFirstTabsStylesheet));
      expect(html, contains(_javascript));
      expect(
        html,
        contains(
          'data-esen-seo-dom-first-application-runtime="application-tabs"',
        ),
      );
      expect(html, contains('data-esen-seo-runtime-sha256='));
      expect(html, contains('nonce="safe&quot;nonce"'));
      expect(
        'data-esen-seo-dom-first-runtime'.allMatches(html),
        isEmpty,
      );
    });
  });

  group('server delivery', () {
    test('requires a store before accepting an application route', () {
      expect(
        () => seoBotMiddleware(
          routes: [_route()],
          siteBase: 'https://x.dev',
        ),
        throwsArgumentError,
      );
    });

    test('verifies the route runtime on every human and crawler response',
        () async {
      final store = _MemoryStore(_artifact());
      final handler = const Pipeline()
          .addMiddleware(seoBotMiddleware(
            routes: [_route()],
            siteBase: 'https://x.dev',
            domFirstRuntimeStore: store,
          ))
          .addHandler((_) => Response.ok('flutter'));

      for (final agent in const ['Mozilla/5.0', 'Googlebot']) {
        final response = await handler(Request(
          'GET',
          Uri.parse('https://x.dev/application'),
          headers: {'user-agent': agent},
        ));
        expect(response.statusCode, 200);
        expect(await response.readAsString(), contains(_javascript));
      }
      expect(store.loads, 2);
    });

    test('rejects a custom store that returns another identity', () async {
      const wrong = SeoDomFirstApplicationRuntime.tabs('other-tabs');
      final handler = const Pipeline()
          .addMiddleware(seoBotMiddleware(
            routes: [_route()],
            siteBase: 'https://x.dev',
            domFirstRuntimeStore: _MemoryStore(_artifact(wrong)),
          ))
          .addHandler((_) => Response.ok('flutter'));

      await expectLater(
        handler(Request('GET', Uri.parse('https://x.dev/application'))),
        throwsStateError,
      );
    });
  });

  group('prerender delivery', () {
    late Directory build;

    setUp(() async {
      build = await Directory.systemTemp.createTemp('esen_app_runtime');
      await File('${build.path}/index.html').writeAsString('''
<!DOCTYPE html><html><head><title>Flutter</title></head>
<body><script src="flutter_bootstrap.js"></script></body></html>
''');
    });

    tearDown(() => build.delete(recursive: true));

    test('fails before writing when the runtime store is missing', () async {
      await expectLater(
        prerenderSite(
          routes: [_route()],
          siteBase: 'https://x.dev',
          buildDir: build.path,
          writeSitemap: false,
          writeRobotsTxt: false,
          writeLlmsTxt: false,
          write404Page: false,
        ),
        throwsArgumentError,
      );
      expect(
          File('${build.path}/application/index.html').existsSync(), isFalse);
    });

    test('writes the verified runtime only to its selected route', () async {
      final store = _MemoryStore(_artifact());
      await prerenderSite(
        routes: [
          _route(),
          SeoRoute(
            path: '/plain',
            delivery: SeoRouteDelivery.domFirst,
            meta: (_) => const SeoMeta(title: 'Plain'),
            body: (_) => [SeoNode(tag: 'h1', text: 'Plain')],
          ),
        ],
        siteBase: 'https://x.dev',
        buildDir: build.path,
        domFirstRuntimeStore: store,
        writeSitemap: false,
        writeRobotsTxt: false,
        writeLlmsTxt: false,
        write404Page: false,
      );

      final application =
          await File('${build.path}/application/index.html').readAsString();
      final plain = await File('${build.path}/plain/index.html').readAsString();
      expect(application, contains(_javascript));
      expect(plain, isNot(contains(_javascript)));
      expect(plain, isNot(contains(seoDomFirstApplicationScriptAttribute)));
      expect(store.loads, 1);
    });
  });
}

final class _MemoryStore implements SeoDomFirstRuntimeStore {
  _MemoryStore(this.artifact);

  final SeoDomFirstRuntimeArtifact artifact;
  int loads = 0;

  @override
  SeoDomFirstRuntimeArtifact load(
    SeoDomFirstApplicationRuntime reference,
  ) {
    loads++;
    return artifact;
  }
}
