import 'dart:convert';
import 'dart:io';

import 'package:esen_seo/server.dart';
import 'package:esen_seo/src/server/seo_application_runtime_handoff.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shelf/shelf.dart';

const _collection =
    SeoDomFirstApplicationRuntime.collection('mixed-collection');
const _configurator =
    SeoDomFirstApplicationRuntime.configurator('mixed-configurator');
const _features = {
  SeoDomFirstFeature.navigation,
  SeoDomFirstFeature.applicationRuntimeHandoff,
};

SeoDomFirstRuntimeArtifact _artifact(
  SeoDomFirstApplicationRuntime reference,
) =>
    SeoDomFirstRuntimeArtifact.create(
      reference: reference,
      javascript: 'var mixedProfileRuntime="${reference.kind}";',
      dartVersion: '3.6.2',
    );

SeoRoute _implicitRoute(
  String path, {
  SeoDomFirstApplicationRuntime? runtime,
}) =>
    SeoRoute(
      path: path,
      delivery: SeoRouteDelivery.domFirst,
      domFirstFeatures: _features,
      applicationRuntime: runtime,
      meta: (_) => SeoMeta(title: path),
      body: (_) => [SeoNode(tag: 'h1', text: path)],
    );

SeoRoute _typedRoute(
  String path, {
  SeoDomFirstApplicationRuntime? runtime,
}) =>
    SeoRoute(
      path: path,
      delivery: SeoRouteDelivery.domFirst,
      domFirstFeatures: _features,
      applicationRuntimeHandoffProfile: _configurator,
      applicationRuntime: runtime,
      meta: (_) => SeoMeta(title: path),
      body: (_) => [SeoNode(tag: 'h1', text: path)],
    );

List<SeoRoute> _routes() => [
      _implicitRoute('/articles'),
      _implicitRoute('/articles/all', runtime: _collection),
      _typedRoute('/pricing'),
      _typedRoute('/pricing/calculator', runtime: _configurator),
    ];

Map<SeoDomFirstApplicationRuntime, SeoDomFirstRuntimeArtifact> _artifacts() => {
      _collection: _artifact(_collection),
      _configurator: _artifact(_configurator),
    };

Map<SeoDomFirstApplicationRuntime, SeoDomFirstNavigationRuntimeEntry> _entries(
  Map<SeoDomFirstApplicationRuntime, SeoDomFirstRuntimeArtifact> artifacts,
) =>
    {
      _collection: SeoDomFirstApplicationHandoffPayload.fromArtifact(
        artifacts[_collection]!,
      ).navigationEntry,
      _configurator: SeoDomFirstApplicationHandoffPayload.fromArtifact(
        artifacts[_configurator]!,
        typedProfile: true,
      ).navigationEntry,
    };

Map<String, List<dynamic>> _manifestRoutes(String manifestJson) {
  final manifest = jsonDecode(manifestJson) as Map<String, dynamic>;
  return {
    for (final raw in manifest['routes'] as List<dynamic>)
      (raw as List<dynamic>).first as String: raw,
  };
}

String _manifestJson(String html) {
  final match = RegExp(
    r'<script[^>]*data-esen-seo-navigation-manifest[^>]*>(.*?)</script>',
  ).firstMatch(html);
  expect(match, isNotNull);
  return match!.group(1)!;
}

void main() {
  test('scopes schema-3 and schema-4 descriptors to the current profile', () {
    final routes = _routes();
    final artifacts = _artifacts();
    final entries = _entries(artifacts);

    final implicit = buildSeoDomFirstNavigationPlan(
      routes: routes,
      currentRoute: routes.first,
      siteBase: 'https://x.dev',
      applicationRuntimes: entries,
    )!;
    final typed = buildSeoDomFirstNavigationPlan(
      routes: routes,
      currentRoute: routes[2],
      siteBase: 'https://x.dev',
      applicationRuntimes: entries,
    )!;
    final implicitRoutes = _manifestRoutes(implicit.manifestJson);
    final typedRoutes = _manifestRoutes(typed.manifestJson);

    expect(
      implicit.schemaVersion,
      seoDomFirstApplicationRuntimeHandoffManifestSchema,
    );
    expect(implicitRoutes['/articles']![2], isNull);
    expect(implicitRoutes['/articles/all']![2], isNotNull);
    expect(implicitRoutes['/pricing']![2], isNull);
    expect(implicitRoutes['/pricing/calculator']![2], isNull);

    expect(
      typed.schemaVersion,
      seoDomFirstTypedApplicationRuntimeHandoffManifestSchema,
    );
    expect(typedRoutes['/articles']![2], isNull);
    expect(typedRoutes['/articles/all']![2], isNull);
    expect(typedRoutes['/pricing']![2], isNull);
    expect(typedRoutes['/pricing/calculator']![2], isNotNull);
  });

  test('middleware emits profile-scoped manifests from one mixed table',
      () async {
    final routes = _routes();
    final artifacts = _artifacts();
    final store = _MemoryStore(artifacts);
    final handler = const Pipeline()
        .addMiddleware(
          seoBotMiddleware(
            routes: routes,
            siteBase: 'https://x.dev',
            domFirstRuntimeStore: store,
          ),
        )
        .addHandler((_) => Response.ok('flutter'));

    final implicitResponse = await handler(
      Request('GET', Uri.parse('https://x.dev/articles')),
    );
    final typedResponse = await handler(
      Request('GET', Uri.parse('https://x.dev/pricing')),
    );
    final implicitRoutes = _manifestRoutes(
      _manifestJson(await implicitResponse.readAsString()),
    );
    final typedRoutes = _manifestRoutes(
      _manifestJson(await typedResponse.readAsString()),
    );

    expect(implicitRoutes['/articles/all']![2], isNotNull);
    expect(implicitRoutes['/pricing/calculator']![2], isNull);
    expect(typedRoutes['/articles/all']![2], isNull);
    expect(typedRoutes['/pricing/calculator']![2], isNotNull);
    expect(store.loads, {_collection: 1, _configurator: 1});
  });

  test('prerender emits profile-scoped manifests from one mixed table',
      () async {
    final build = await Directory.systemTemp.createTemp('esen_profile_scope');
    addTearDown(() => build.delete(recursive: true));
    await File('${build.path}/index.html').writeAsString(
      '<!DOCTYPE html><html><head><title>App</title></head>'
      '<body><script src="flutter_bootstrap.js"></script></body></html>',
    );
    final routes = _routes();

    await prerenderSite(
      routes: routes,
      siteBase: 'https://x.dev',
      buildDir: build.path,
      domFirstRuntimeStore: _MemoryStore(_artifacts()),
      writeSitemap: false,
      writeRobotsTxt: false,
      writeLlmsTxt: false,
      write404Page: false,
    );

    final implicitRoutes = _manifestRoutes(
      _manifestJson(
        await File('${build.path}/articles/index.html').readAsString(),
      ),
    );
    final typedRoutes = _manifestRoutes(
      _manifestJson(
        await File('${build.path}/pricing/index.html').readAsString(),
      ),
    );

    expect(implicitRoutes['/articles/all']![2], isNotNull);
    expect(implicitRoutes['/pricing/calculator']![2], isNull);
    expect(typedRoutes['/articles/all']![2], isNull);
    expect(typedRoutes['/pricing/calculator']![2], isNotNull);
  });
}

final class _MemoryStore implements SeoDomFirstRuntimeStore {
  _MemoryStore(this.artifacts);

  final Map<SeoDomFirstApplicationRuntime, SeoDomFirstRuntimeArtifact>
      artifacts;
  final Map<SeoDomFirstApplicationRuntime, int> loads = {};

  @override
  SeoDomFirstRuntimeArtifact load(SeoDomFirstApplicationRuntime reference) {
    loads.update(reference, (count) => count + 1, ifAbsent: () => 1);
    return artifacts[reference]!;
  }
}
