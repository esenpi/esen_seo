import 'dart:convert';
import 'dart:io';

import 'package:esen_seo/server.dart';
import 'package:esen_seo/src/renderer/seo_dom_first_navigation_application_handoff_runtime.g.dart';
import 'package:esen_seo/src/renderer/seo_dom_first_runtime_handoff.dart';
import 'package:esen_seo/src/server/seo_application_runtime_handoff.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shelf/shelf.dart';

const _reference =
    SeoDomFirstApplicationRuntime.collection('handoff-collection');
const _otherReference =
    SeoDomFirstApplicationRuntime.collection('other-collection');
const _javascript = '(function(){var collectionHandoff=true;})();';
const _features = {
  SeoDomFirstFeature.navigation,
  SeoDomFirstFeature.applicationRuntimeHandoff,
  SeoDomFirstFeature.themeToggle,
};
const _featuresWithoutTheme = {
  SeoDomFirstFeature.navigation,
  SeoDomFirstFeature.applicationRuntimeHandoff,
};

SeoDomFirstRuntimeArtifact _artifact([
  SeoDomFirstApplicationRuntime reference = _reference,
]) =>
    SeoDomFirstRuntimeArtifact.create(
      reference: reference,
      javascript: _javascript,
      dartVersion: '3.6.2',
    );

SeoRoute _route(
  String path, {
  SeoDomFirstApplicationRuntime? runtime,
  Set<SeoDomFirstFeature> features = _features,
}) =>
    SeoRoute(
      path: path,
      delivery: SeoRouteDelivery.domFirst,
      domFirstFeatures: features,
      applicationRuntime: runtime,
      meta: (_) => SeoMeta(title: 'Page $path'),
      body: (_) => [
        SeoNode(tag: 'main', children: [
          SeoNode(tag: 'h1', text: 'Page $path'),
        ]),
      ],
    );

Map<SeoDomFirstApplicationRuntime, SeoDomFirstNavigationRuntimeEntry>
    _runtimeEntries(SeoDomFirstRuntimeArtifact artifact) => {
          artifact.reference:
              SeoDomFirstApplicationHandoffPayload.fromArtifact(artifact)
                  .navigationEntry,
        };

void main() {
  group('application Collection handoff contract', () {
    test('admits only its closed route profile', () {
      final route = _route('/collection', runtime: _reference);
      expect(route.applicationRuntime, _reference);
      expect(
        seoDomFirstNavigationProfile(route),
        'applicationRuntimeHandoff.navigation.themeToggle',
      );

      for (final features in const <Set<SeoDomFirstFeature>>[
        {SeoDomFirstFeature.applicationRuntimeHandoff},
        {
          SeoDomFirstFeature.navigation,
          SeoDomFirstFeature.applicationRuntimeHandoff,
          SeoDomFirstFeature.prefetch,
        },
        {
          SeoDomFirstFeature.navigation,
          SeoDomFirstFeature.applicationRuntimeHandoff,
          SeoDomFirstFeature.collection,
        },
        {
          SeoDomFirstFeature.navigation,
          SeoDomFirstFeature.applicationRuntimeHandoff,
          SeoDomFirstFeature.runtimeHandoff,
        },
        {
          SeoDomFirstFeature.navigation,
          SeoDomFirstFeature.applicationRuntimeHandoff,
          SeoDomFirstFeature.tabs,
        },
      ]) {
        expect(
          () => _route('/invalid-${features.length}', features: features),
          throwsArgumentError,
        );
      }
      expect(
        () => SeoRoute(
          path: '/tabs',
          delivery: SeoRouteDelivery.domFirst,
          domFirstFeatures: _features,
          applicationRuntime:
              const SeoDomFirstApplicationRuntime.tabs('handoff-tabs'),
          meta: (_) => const SeoMeta(),
        ),
        throwsArgumentError,
      );
      expect(
        () => SeoRoute(
          path: '/bundle',
          delivery: SeoRouteDelivery.domFirst,
          domFirstFeatures: _features,
          applicationRuntime: SeoDomFirstApplicationRuntime.bundle(
            'handoff-bundle',
            members: const {
              SeoDomFirstApplicationRuntimeKind.tabs,
              SeoDomFirstApplicationRuntimeKind.carousel,
            },
          ),
          meta: (_) => const SeoMeta(),
        ),
        throwsArgumentError,
      );
    });

    test('binds application identity and exact envelope in manifest schema 3',
        () {
      final artifact = _artifact();
      final payload =
          SeoDomFirstApplicationHandoffPayload.fromArtifact(artifact);
      final routes = [
        _route('/overview'),
        _route('/articles', runtime: _reference),
      ];
      final plan = buildSeoDomFirstNavigationPlan(
        routes: routes,
        currentRoute: routes.first,
        siteBase: 'https://x.dev/repo',
        applicationRuntimes: _runtimeEntries(artifact),
      )!;
      final manifest = jsonDecode(plan.manifestJson) as Map<String, dynamic>;

      expect(
        plan.schemaVersion,
        seoDomFirstApplicationRuntimeHandoffManifestSchema,
      );
      expect(plan.entries.first.runtime, isNull);
      expect(plan.entries.last.runtime?.applicationId, _reference.id);
      expect(
        plan.entries.last.runtime?.contractRevision,
        seoDomFirstRuntimeContractRevision,
      );
      expect(plan.entries.last.runtime?.bytes, artifact.manifest.bytes);
      expect(
        plan.entries.last.runtime?.sha256,
        artifact.manifest.sha256,
      );
      expect(manifest['routes'], [
        [
          '/overview',
          'applicationRuntimeHandoff.navigation.themeToggle',
          null,
        ],
        [
          '/articles',
          'applicationRuntimeHandoff.navigation.themeToggle',
          [
            'application',
            'collection',
            _reference.id,
            seoDomFirstRuntimeContractRevision,
            payload.navigationEntry.sha256,
            payload.navigationEntry.bytes,
          ],
        ],
      ]);
    });

    test('rejects two runtime identities in one compatible profile', () {
      final first = _artifact();
      final second = _artifact(_otherReference);
      final routes = [
        _route('/first', runtime: _reference),
        _route('/second', runtime: _otherReference),
      ];

      expect(
        () => buildSeoDomFirstNavigationPlan(
          routes: routes,
          currentRoute: routes.first,
          siteBase: 'https://x.dev',
          applicationRuntimes: {
            ..._runtimeEntries(first),
            ..._runtimeEntries(second),
          },
        ),
        throwsArgumentError,
      );
    });

    test('keeps separate feature profiles independent', () {
      final first = _artifact();
      final second = _artifact(_otherReference);
      final routes = [
        _route('/first', runtime: _reference),
        _route(
          '/second',
          runtime: _otherReference,
          features: _featuresWithoutTheme,
        ),
      ];
      final entries = {
        ..._runtimeEntries(first),
        ..._runtimeEntries(second),
      };

      expect(
        buildSeoDomFirstNavigationPlan(
          routes: routes,
          currentRoute: routes.first,
          siteBase: 'https://x.dev',
          applicationRuntimes: entries,
        ),
        isNotNull,
      );
      expect(
        buildSeoDomFirstNavigationPlan(
          routes: routes,
          currentRoute: routes.last,
          siteBase: 'https://x.dev',
          applicationRuntimes: entries,
        ),
        isNotNull,
      );
    });

    test('renders the exact verified envelope before the navigation loader',
        () {
      final artifact = _artifact();
      final payload =
          SeoDomFirstApplicationHandoffPayload.fromArtifact(artifact);
      final routes = [
        _route('/overview'),
        _route('/articles', runtime: _reference),
      ];
      final plan = buildSeoDomFirstNavigationPlan(
        routes: routes,
        currentRoute: routes.last,
        siteBase: 'https://x.dev',
        applicationRuntimes: _runtimeEntries(artifact),
      )!;
      final html = SeoPage.domFirstFromNodes(
        meta: const SeoMeta(title: 'Articles'),
        body: [SeoNode(tag: 'h1', text: 'Complete without JavaScript')],
        features: _features,
        navigationPlan: plan,
        applicationRuntime: artifact,
        interactionNonce: 'trusted-nonce',
      ).toHtmlDocument();
      final applicationIndex = html.indexOf(
        '$seoDomFirstLoadableRuntimeAttribute="application"',
      );
      final navigationIndex =
          html.indexOf(seoDomFirstNavigationApplicationHandoffRuntime);

      expect(applicationIndex, greaterThan(0));
      expect(applicationIndex, lessThan(navigationIndex));
      expect(
        html,
        contains('$seoDomFirstApplicationScriptAttribute="${_reference.id}"'),
      );
      expect(
        html,
        contains('$seoDomFirstRuntimeKindAttribute="collection"'),
      );
      expect(
        html,
        contains('$seoDomFirstRuntimeContractAttribute="1"'),
      );
      expect(
        html,
        contains('$seoDomFirstRuntimeSha256Attribute="'
            '${payload.navigationEntry.sha256}"'),
      );
      expect(html, contains('nonce="trusted-nonce">${payload.javascript}'));
      expect(html, contains('Complete without JavaScript'));
      expect(
        'nonce="trusted-nonce"'.allMatches(html).length,
        greaterThanOrEqualTo(4),
      );
      payload.validateProfileBudget(includeThemeToggle: true);
    });

    test('rejects a page artifact that differs from its current route plan',
        () {
      final artifact = _artifact();
      final changed = SeoDomFirstRuntimeArtifact.create(
        reference: _reference,
        javascript: '(function(){var collectionHandoff=false;})();',
        dartVersion: '3.6.2',
      );
      final routes = [
        _route('/overview'),
        _route('/articles', runtime: _reference),
      ];
      final overviewPlan = buildSeoDomFirstNavigationPlan(
        routes: routes,
        currentRoute: routes.first,
        siteBase: 'https://x.dev',
        applicationRuntimes: _runtimeEntries(artifact),
      )!;
      final articlesPlan = buildSeoDomFirstNavigationPlan(
        routes: routes,
        currentRoute: routes.last,
        siteBase: 'https://x.dev',
        applicationRuntimes: _runtimeEntries(artifact),
      )!;

      expect(
        () => SeoPage.domFirstFromNodes(
          body: const [],
          features: _features,
          navigationPlan: articlesPlan,
        ),
        throwsArgumentError,
      );
      expect(
        () => SeoPage.domFirstFromNodes(
          body: const [],
          features: _features,
          navigationPlan: overviewPlan,
          applicationRuntime: artifact,
        ),
        throwsArgumentError,
      );
      expect(
        () => SeoPage.domFirstFromNodes(
          body: const [],
          features: _features,
          navigationPlan: articlesPlan,
          applicationRuntime: changed,
        ),
        throwsArgumentError,
      );
    });
  });

  group('application Collection handoff delivery', () {
    test('middleware snapshots one artifact for plans and every response',
        () async {
      final artifact = _artifact();
      final store = _MemoryStore(artifact);
      final routes = [
        _route('/overview'),
        _route('/articles', runtime: _reference),
      ];
      final handler = const Pipeline()
          .addMiddleware(seoBotMiddleware(
            routes: routes,
            siteBase: 'https://x.dev',
            domFirstRuntimeStore: store,
          ))
          .addHandler((_) => Response.ok('flutter'));

      final overview = await handler(
        Request('GET', Uri.parse('https://x.dev/overview')),
      );
      final articles = await handler(
        Request('GET', Uri.parse('https://x.dev/articles')),
      );
      final repeated = await handler(
        Request('GET', Uri.parse('https://x.dev/articles?q=second')),
      );
      final overviewHtml = await overview.readAsString();
      final articlesHtml = await articles.readAsString();
      await repeated.readAsString();

      expect(store.loads, 1);
      expect(overviewHtml, isNot(contains(_javascript)));
      expect(overviewHtml,
          contains(_runtimeEntries(artifact)[_reference]!.sha256));
      expect(articlesHtml, contains(_javascript));
      expect(
        articlesHtml,
        contains(_runtimeEntries(artifact)[_reference]!.sha256),
      );
    });

    test('prerender rejects a mismatched snapshot before writing a page',
        () async {
      final build = await Directory.systemTemp.createTemp('esen_app_handoff');
      addTearDown(() => build.delete(recursive: true));
      await File('${build.path}/index.html').writeAsString(
        '<!DOCTYPE html><html><head><title>App</title></head>'
        '<body><script src="flutter_bootstrap.js"></script></body></html>',
      );
      final routes = [
        _route('/overview'),
        _route('/articles', runtime: _reference),
      ];

      await expectLater(
        prerenderSite(
          routes: routes,
          siteBase: 'https://x.dev',
          buildDir: build.path,
          domFirstRuntimeStore: _MemoryStore(_artifact(_otherReference)),
          writeSitemap: false,
          writeRobotsTxt: false,
          writeLlmsTxt: false,
          write404Page: false,
        ),
        throwsStateError,
      );
      expect(File('${build.path}/overview/index.html').existsSync(), isFalse);
      expect(File('${build.path}/articles/index.html').existsSync(), isFalse);
    });
  });
}

final class _MemoryStore implements SeoDomFirstRuntimeStore {
  _MemoryStore(this.artifact);

  final SeoDomFirstRuntimeArtifact artifact;
  int loads = 0;

  @override
  SeoDomFirstRuntimeArtifact load(SeoDomFirstApplicationRuntime reference) {
    loads++;
    return artifact;
  }
}
