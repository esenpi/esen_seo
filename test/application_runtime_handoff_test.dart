import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:esen_seo/server.dart';
import 'package:esen_seo/src/renderer/seo_dom_first_navigation_application_handoff_runtime.g.dart';
import 'package:esen_seo/src/renderer/seo_dom_first_navigation_application_profile_runtime.g.dart';
import 'package:esen_seo/src/renderer/seo_dom_first_runtime_handoff.dart';
import 'package:esen_seo/src/renderer/seo_dom_first_theme_toggle_runtime.g.dart';
import 'package:esen_seo/src/server/seo_application_runtime_handoff.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shelf/shelf.dart';

const _reference =
    SeoDomFirstApplicationRuntime.collection('handoff-collection');
const _otherReference =
    SeoDomFirstApplicationRuntime.collection('other-collection');
const _javascript = '(function(){var collectionHandoff=true;})();';
const _configuratorReference =
    SeoDomFirstApplicationRuntime.configurator('pricing-configurator');
const _otherConfiguratorReference =
    SeoDomFirstApplicationRuntime.configurator('other-configurator');
const _configuratorJavascript =
    '(function(){var configuratorHandoff=true;})();';
const _workflowReference =
    SeoDomFirstApplicationRuntime.editorialWorkflow('article-workflow');
const _workflowJavascript =
    '(function(){var editorialWorkflowHandoff=true;})();';
const _approvalReference =
    SeoDomFirstApplicationRuntime.approvalChecklist('review-checklist');
const _approvalJavascript =
    '(function(){var approvalChecklistHandoff=true;})();';
const _tabsReference = SeoDomFirstApplicationRuntime.tabs('product-tabs');
const _tabsJavascript = '(function(){var tabsHandoff=true;})();';
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

SeoDomFirstRuntimeArtifact _configuratorArtifact([
  SeoDomFirstApplicationRuntime reference = _configuratorReference,
]) =>
    SeoDomFirstRuntimeArtifact.create(
      reference: reference,
      javascript: _configuratorJavascript,
      dartVersion: '3.6.2',
    );

SeoDomFirstRuntimeArtifact _workflowArtifact() =>
    SeoDomFirstRuntimeArtifact.create(
      reference: _workflowReference,
      javascript: _workflowJavascript,
      dartVersion: '3.6.2',
    );

SeoDomFirstRuntimeArtifact _approvalArtifact() =>
    SeoDomFirstRuntimeArtifact.create(
      reference: _approvalReference,
      javascript: _approvalJavascript,
      dartVersion: '3.6.2',
    );

SeoDomFirstRuntimeArtifact _tabsArtifact() => SeoDomFirstRuntimeArtifact.create(
      reference: _tabsReference,
      javascript: _tabsJavascript,
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

SeoRoute _profileRoute(
  String path, {
  SeoDomFirstApplicationRuntime profile = _configuratorReference,
  SeoDomFirstApplicationRuntime? runtime,
}) =>
    SeoRoute(
      path: path,
      delivery: SeoRouteDelivery.domFirst,
      domFirstFeatures: _features,
      applicationRuntimeHandoffProfile: profile,
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

String _incompressibleJavascript(int length) {
  const alphabet =
      r'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_$';
  final random = Random(7);
  final source = StringBuffer('var seoRuntimeSource="');
  for (var index = 0; index < length; index++) {
    source.write(alphabet[random.nextInt(alphabet.length)]);
  }
  source.write('";');
  return source.toString();
}

int _nearCeilingSourceLength() {
  final codec = GZipCodec(level: 9);
  var length = 24 * 1024;
  while (codec
          .encode(utf8.encode(_incompressibleJavascript(length + 1024)))
          .length <=
      seoDomFirstRuntimeMaxGzipBytes) {
    length += 1024;
  }
  while (codec
          .encode(utf8.encode('${_incompressibleJavascript(length)}'
              '$seoDomFirstConfiguratorApplicationHandoffEpilogue'
              '$seoDomFirstNavigationApplicationProfileRuntime'
              '$seoDomFirstThemeToggleRuntime'))
          .length >
      31 * 1024) {
    length--;
  }
  return length;
}

String _withoutScripts(String html) =>
    html.replaceAll(RegExp(r'<script[^>]*>.*?</script>', dotAll: true), '');

void main() {
  group('typed application handoff profile', () {
    test('binds a Tabs profile to schema 4', () {
      final artifact = _tabsArtifact();
      final payload = SeoDomFirstApplicationHandoffPayload.fromArtifact(
        artifact,
        typedProfile: true,
      );
      final routes = [
        _profileRoute('/overview', profile: _tabsReference),
        _profileRoute(
          '/product',
          profile: _tabsReference,
          runtime: _tabsReference,
        ),
      ];
      final plan = buildSeoDomFirstNavigationPlan(
        routes: routes,
        currentRoute: routes.last,
        siteBase: 'https://x.dev/repo',
        applicationRuntimes: {_tabsReference: payload.navigationEntry},
      )!;
      final manifest = jsonDecode(plan.manifestJson) as Map<String, dynamic>;

      expect(
        plan.schemaVersion,
        seoDomFirstTypedApplicationRuntimeHandoffManifestSchema,
      );
      expect(
        plan.profile,
        'applicationRuntimeHandoff.navigation.themeToggle.application.'
        'tabs.product-tabs',
      );
      expect(plan.currentRuntime?.kind, 'tabs');
      expect(plan.profileRuntime?.applicationId, _tabsReference.id);
      expect(manifest['schema'], 4);
      expect((manifest['routes'] as List).last, [
        '/product',
        plan.profile,
        [
          'application',
          'tabs',
          _tabsReference.id,
          seoDomFirstRuntimeContractRevision,
          payload.navigationEntry.sha256,
          payload.navigationEntry.bytes,
        ],
      ]);
    });

    test('renders only Tabs structural CSS for its profile', () {
      final artifact = _tabsArtifact();
      final payload = SeoDomFirstApplicationHandoffPayload.fromArtifact(
        artifact,
        typedProfile: true,
      );
      final routes = [
        _profileRoute('/overview', profile: _tabsReference),
        _profileRoute(
          '/product',
          profile: _tabsReference,
          runtime: _tabsReference,
        ),
      ];
      final entries = {_tabsReference: payload.navigationEntry};
      final overviewPlan = buildSeoDomFirstNavigationPlan(
        routes: routes,
        currentRoute: routes.first,
        siteBase: 'https://x.dev',
        applicationRuntimes: entries,
      )!;
      final activePlan = buildSeoDomFirstNavigationPlan(
        routes: routes,
        currentRoute: routes.last,
        siteBase: 'https://x.dev',
        applicationRuntimes: entries,
      )!;
      final overviewHtml = SeoPage.domFirstFromNodes(
        body: [SeoNode(tag: 'h1', text: 'Overview')],
        features: _features,
        navigationPlan: overviewPlan,
      ).toHtmlDocument();
      final activeHtml = SeoPage.domFirstFromNodes(
        body: [SeoNode(tag: 'h1', text: 'Product')],
        features: _features,
        navigationPlan: activePlan,
        applicationRuntime: artifact,
      ).toHtmlDocument();

      for (final html in [overviewHtml, activeHtml]) {
        expect(html, contains(seoDomFirstTabsStylesheet));
        expect(html, isNot(contains(seoDomFirstCarouselStylesheet)));
        expect(html, isNot(contains(seoDomFirstStepperStylesheet)));
        expect(html, isNot(contains(seoDomFirstCollectionStylesheet)));
        expect(html, isNot(contains(seoDomFirstConfiguratorStylesheet)));
        expect(html, isNot(contains(seoDomFirstEditorialWorkflowStylesheet)));
        expect(html, isNot(contains(seoDomFirstApprovalChecklistStylesheet)));
      }
      expect(overviewHtml, isNot(contains(_tabsJavascript)));
      expect(activeHtml, contains(_tabsJavascript));
      expect(
        activeHtml,
        contains(seoDomFirstTabsApplicationHandoffEpilogue),
      );
      expect(
        payload.javascript,
        '$_tabsJavascript$seoDomFirstTabsApplicationHandoffEpilogue',
      );
      expect(
        payload.navigationEntry.bytes,
        utf8.encode(_tabsJavascript).length,
      );
      expect(payload.navigationEntry.sha256, artifact.manifest.sha256);
      payload.validateProfileBudget(includeThemeToggle: true);
    });

    test('snapshots one Tabs artifact across server routes', () async {
      final artifact = _tabsArtifact();
      final store = _MemoryStore(artifact);
      final routes = [
        _profileRoute('/overview', profile: _tabsReference),
        _profileRoute(
          '/product',
          profile: _tabsReference,
          runtime: _tabsReference,
        ),
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
      final product = await handler(
        Request('GET', Uri.parse('https://x.dev/product')),
      );
      final overviewHtml = await overview.readAsString();
      final productHtml = await product.readAsString();

      expect(store.loads, 1);
      expect(overviewHtml, isNot(contains(_tabsJavascript)));
      expect(overviewHtml, contains(artifact.manifest.sha256));
      expect(productHtml, contains(_tabsJavascript));
      expect(productHtml, contains(artifact.manifest.sha256));
    });

    test('prerenders one Tabs snapshot for its profile', () async {
      final build = await Directory.systemTemp.createTemp('esen_tabs_handoff');
      addTearDown(() => build.delete(recursive: true));
      await File('${build.path}/index.html').writeAsString(
        '<!DOCTYPE html><html><head><title>App</title></head>'
        '<body><script src="flutter_bootstrap.js"></script></body></html>',
      );
      final artifact = _tabsArtifact();
      final store = _MemoryStore(artifact);
      final routes = [
        _profileRoute('/overview', profile: _tabsReference),
        _profileRoute(
          '/product',
          profile: _tabsReference,
          runtime: _tabsReference,
        ),
      ];

      await prerenderSite(
        routes: routes,
        siteBase: 'https://x.dev/repo',
        buildDir: build.path,
        domFirstRuntimeStore: store,
        writeSitemap: false,
        writeRobotsTxt: false,
        writeLlmsTxt: false,
        write404Page: false,
      );
      final overview =
          await File('${build.path}/overview/index.html').readAsString();
      final product =
          await File('${build.path}/product/index.html').readAsString();

      expect(store.loads, 1);
      expect(overview, contains(seoDomFirstTabsStylesheet));
      expect(overview, isNot(contains(_tabsJavascript)));
      expect(overview, contains('"schema":4'));
      expect(product, contains(_tabsJavascript));
      expect(product, contains('"schema":4'));
    });

    test('binds an Approval Checklist profile to schema 4', () {
      final artifact = _approvalArtifact();
      final payload = SeoDomFirstApplicationHandoffPayload.fromArtifact(
        artifact,
        typedProfile: true,
      );
      final routes = [
        _profileRoute('/overview', profile: _approvalReference),
        _profileRoute(
          '/review',
          profile: _approvalReference,
          runtime: _approvalReference,
        ),
      ];
      final plan = buildSeoDomFirstNavigationPlan(
        routes: routes,
        currentRoute: routes.last,
        siteBase: 'https://x.dev/repo',
        applicationRuntimes: {_approvalReference: payload.navigationEntry},
      )!;
      final manifest = jsonDecode(plan.manifestJson) as Map<String, dynamic>;

      expect(
        plan.schemaVersion,
        seoDomFirstTypedApplicationRuntimeHandoffManifestSchema,
      );
      expect(
        plan.profile,
        'applicationRuntimeHandoff.navigation.themeToggle.application.'
        'approval-checklist.review-checklist',
      );
      expect(plan.currentRuntime?.kind, 'approval-checklist');
      expect(plan.profileRuntime?.applicationId, _approvalReference.id);
      expect(manifest['schema'], 4);
      expect((manifest['routes'] as List).last, [
        '/review',
        plan.profile,
        [
          'application',
          'approval-checklist',
          _approvalReference.id,
          seoDomFirstRuntimeContractRevision,
          payload.navigationEntry.sha256,
          payload.navigationEntry.bytes,
        ],
      ]);
    });

    test('renders only Approval Checklist structural CSS for its profile', () {
      final artifact = _approvalArtifact();
      final payload = SeoDomFirstApplicationHandoffPayload.fromArtifact(
        artifact,
        typedProfile: true,
      );
      final routes = [
        _profileRoute('/overview', profile: _approvalReference),
        _profileRoute(
          '/review',
          profile: _approvalReference,
          runtime: _approvalReference,
        ),
      ];
      final entries = {_approvalReference: payload.navigationEntry};
      final overviewPlan = buildSeoDomFirstNavigationPlan(
        routes: routes,
        currentRoute: routes.first,
        siteBase: 'https://x.dev',
        applicationRuntimes: entries,
      )!;
      final activePlan = buildSeoDomFirstNavigationPlan(
        routes: routes,
        currentRoute: routes.last,
        siteBase: 'https://x.dev',
        applicationRuntimes: entries,
      )!;
      final overviewHtml = SeoPage.domFirstFromNodes(
        body: [SeoNode(tag: 'h1', text: 'Overview')],
        features: _features,
        navigationPlan: overviewPlan,
      ).toHtmlDocument();
      final activeHtml = SeoPage.domFirstFromNodes(
        body: [SeoNode(tag: 'h1', text: 'Review')],
        features: _features,
        navigationPlan: activePlan,
        applicationRuntime: artifact,
      ).toHtmlDocument();

      for (final html in [overviewHtml, activeHtml]) {
        expect(html, contains('.esen-seo-approval-checklist'));
        expect(html, isNot(contains('.esen-seo-collection-toolbar')));
        expect(html, isNot(contains('.esen-seo-configurator-controls')));
        expect(html, isNot(contains('.esen-seo-editorial-workflow')));
      }
      expect(overviewHtml, isNot(contains(_approvalJavascript)));
      expect(activeHtml, contains(_approvalJavascript));
      expect(
        activeHtml,
        contains(seoDomFirstApprovalChecklistApplicationHandoffEpilogue),
      );
      expect(
        payload.javascript,
        '$_approvalJavascript'
        '$seoDomFirstApprovalChecklistApplicationHandoffEpilogue',
      );
      expect(
        payload.navigationEntry.bytes,
        utf8.encode(_approvalJavascript).length,
      );
      expect(payload.navigationEntry.sha256, artifact.manifest.sha256);
      payload.validateProfileBudget(includeThemeToggle: true);
    });

    test('snapshots one Approval Checklist artifact across server routes',
        () async {
      final artifact = _approvalArtifact();
      final store = _MemoryStore(artifact);
      final routes = [
        _profileRoute('/overview', profile: _approvalReference),
        _profileRoute(
          '/review',
          profile: _approvalReference,
          runtime: _approvalReference,
        ),
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
      final review = await handler(
        Request('GET', Uri.parse('https://x.dev/review')),
      );
      final overviewHtml = await overview.readAsString();
      final reviewHtml = await review.readAsString();

      expect(store.loads, 1);
      expect(overviewHtml, isNot(contains(_approvalJavascript)));
      expect(overviewHtml, contains(artifact.manifest.sha256));
      expect(reviewHtml, contains(_approvalJavascript));
      expect(reviewHtml, contains(artifact.manifest.sha256));
    });

    test('prerenders one Approval Checklist snapshot for its profile',
        () async {
      final build = await Directory.systemTemp.createTemp(
        'esen_approval_handoff',
      );
      addTearDown(() => build.delete(recursive: true));
      await File('${build.path}/index.html').writeAsString(
        '<!DOCTYPE html><html><head><title>App</title></head>'
        '<body><script src="flutter_bootstrap.js"></script></body></html>',
      );
      final artifact = _approvalArtifact();
      final store = _MemoryStore(artifact);
      final routes = [
        _profileRoute('/overview', profile: _approvalReference),
        _profileRoute(
          '/review',
          profile: _approvalReference,
          runtime: _approvalReference,
        ),
      ];

      await prerenderSite(
        routes: routes,
        siteBase: 'https://x.dev/repo',
        buildDir: build.path,
        domFirstRuntimeStore: store,
        writeSitemap: false,
        writeRobotsTxt: false,
        writeLlmsTxt: false,
        write404Page: false,
      );
      final overview =
          await File('${build.path}/overview/index.html').readAsString();
      final review =
          await File('${build.path}/review/index.html').readAsString();

      expect(store.loads, 1);
      expect(overview, contains('.esen-seo-approval-checklist'));
      expect(overview, isNot(contains(_approvalJavascript)));
      expect(overview, contains('"schema":4'));
      expect(review, contains(_approvalJavascript));
      expect(review, contains('"schema":4'));
    });

    test('binds an Editorial Workflow profile to schema 4', () {
      final artifact = _workflowArtifact();
      final payload = SeoDomFirstApplicationHandoffPayload.fromArtifact(
        artifact,
        typedProfile: true,
      );
      final routes = [
        _profileRoute('/overview', profile: _workflowReference),
        _profileRoute(
          '/editorial',
          profile: _workflowReference,
          runtime: _workflowReference,
        ),
      ];
      final plan = buildSeoDomFirstNavigationPlan(
        routes: routes,
        currentRoute: routes.last,
        siteBase: 'https://x.dev/repo',
        applicationRuntimes: {_workflowReference: payload.navigationEntry},
      )!;
      final manifest = jsonDecode(plan.manifestJson) as Map<String, dynamic>;

      expect(
        plan.schemaVersion,
        seoDomFirstTypedApplicationRuntimeHandoffManifestSchema,
      );
      expect(
        plan.profile,
        'applicationRuntimeHandoff.navigation.themeToggle.application.'
        'editorial-workflow.article-workflow',
      );
      expect(plan.currentRuntime?.kind, 'editorial-workflow');
      expect(plan.profileRuntime?.applicationId, _workflowReference.id);
      expect(manifest['schema'], 4);
      expect((manifest['routes'] as List).last, [
        '/editorial',
        plan.profile,
        [
          'application',
          'editorial-workflow',
          _workflowReference.id,
          seoDomFirstRuntimeContractRevision,
          payload.navigationEntry.sha256,
          payload.navigationEntry.bytes,
        ],
      ]);
    });

    test('renders only Editorial Workflow structural CSS for its profile', () {
      final artifact = _workflowArtifact();
      final payload = SeoDomFirstApplicationHandoffPayload.fromArtifact(
        artifact,
        typedProfile: true,
      );
      final routes = [
        _profileRoute('/overview', profile: _workflowReference),
        _profileRoute(
          '/editorial',
          profile: _workflowReference,
          runtime: _workflowReference,
        ),
      ];
      final entries = {_workflowReference: payload.navigationEntry};
      final overviewPlan = buildSeoDomFirstNavigationPlan(
        routes: routes,
        currentRoute: routes.first,
        siteBase: 'https://x.dev',
        applicationRuntimes: entries,
      )!;
      final activePlan = buildSeoDomFirstNavigationPlan(
        routes: routes,
        currentRoute: routes.last,
        siteBase: 'https://x.dev',
        applicationRuntimes: entries,
      )!;
      final overviewHtml = SeoPage.domFirstFromNodes(
        body: [SeoNode(tag: 'h1', text: 'Overview')],
        features: _features,
        navigationPlan: overviewPlan,
      ).toHtmlDocument();
      final activeHtml = SeoPage.domFirstFromNodes(
        body: [SeoNode(tag: 'h1', text: 'Editorial')],
        features: _features,
        navigationPlan: activePlan,
        applicationRuntime: artifact,
      ).toHtmlDocument();

      for (final html in [overviewHtml, activeHtml]) {
        expect(html, contains('.esen-seo-editorial-workflow'));
        expect(html, isNot(contains('.esen-seo-collection-toolbar')));
        expect(html, isNot(contains('.esen-seo-configurator-controls')));
      }
      expect(overviewHtml, isNot(contains(_workflowJavascript)));
      expect(activeHtml, contains(_workflowJavascript));
      expect(
        activeHtml,
        contains(seoDomFirstEditorialWorkflowApplicationHandoffEpilogue),
      );
      expect(
        payload.javascript,
        '$_workflowJavascript'
        '$seoDomFirstEditorialWorkflowApplicationHandoffEpilogue',
      );
      expect(
        payload.navigationEntry.bytes,
        utf8.encode(_workflowJavascript).length,
      );
      expect(payload.navigationEntry.sha256, artifact.manifest.sha256);
      payload.validateProfileBudget(includeThemeToggle: true);
    });

    test('snapshots one Editorial Workflow artifact across server routes',
        () async {
      final artifact = _workflowArtifact();
      final store = _MemoryStore(artifact);
      final routes = [
        _profileRoute('/overview', profile: _workflowReference),
        _profileRoute(
          '/editorial',
          profile: _workflowReference,
          runtime: _workflowReference,
        ),
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
      final editorial = await handler(
        Request('GET', Uri.parse('https://x.dev/editorial')),
      );
      final overviewHtml = await overview.readAsString();
      final editorialHtml = await editorial.readAsString();

      expect(store.loads, 1);
      expect(overviewHtml, isNot(contains(_workflowJavascript)));
      expect(overviewHtml, contains(artifact.manifest.sha256));
      expect(editorialHtml, contains(_workflowJavascript));
      expect(editorialHtml, contains(artifact.manifest.sha256));
    });

    test('binds a Configurator profile to static and active routes', () {
      final artifact = _configuratorArtifact();
      final payload = SeoDomFirstApplicationHandoffPayload.fromArtifact(
        artifact,
        typedProfile: true,
      );
      final routes = [
        _profileRoute('/overview'),
        _profileRoute('/pricing', runtime: _configuratorReference),
      ];
      final entries = {_configuratorReference: payload.navigationEntry};
      final overviewPlan = buildSeoDomFirstNavigationPlan(
        routes: routes,
        currentRoute: routes.first,
        siteBase: 'https://x.dev/repo',
        applicationRuntimes: entries,
      )!;
      final pricingPlan = buildSeoDomFirstNavigationPlan(
        routes: routes,
        currentRoute: routes.last,
        siteBase: 'https://x.dev/repo',
        applicationRuntimes: entries,
      )!;
      final manifest =
          jsonDecode(overviewPlan.manifestJson) as Map<String, dynamic>;

      expect(
        overviewPlan.schemaVersion,
        seoDomFirstTypedApplicationRuntimeHandoffManifestSchema,
      );
      expect(
        overviewPlan.profile,
        'applicationRuntimeHandoff.navigation.themeToggle.application.'
        'configurator.pricing-configurator',
      );
      expect(overviewPlan.currentRuntime, isNull);
      expect(overviewPlan.profileRuntime?.kind, 'configurator');
      expect(
        overviewPlan.profileRuntime?.applicationId,
        _configuratorReference.id,
      );
      expect(pricingPlan.currentRuntime?.kind, 'configurator');
      expect(manifest['schema'], 4);
      expect((manifest['routes'] as List).last, [
        '/pricing',
        overviewPlan.profile,
        [
          'application',
          'configurator',
          _configuratorReference.id,
          seoDomFirstRuntimeContractRevision,
          payload.navigationEntry.sha256,
          payload.navigationEntry.bytes,
        ],
      ]);
    });

    test('rejects implicit, mismatched and unsupported profiles', () {
      expect(
        () => _route('/implicit', runtime: _configuratorReference),
        throwsArgumentError,
      );
      expect(
        () => _profileRoute(
          '/mismatch',
          runtime: _otherConfiguratorReference,
        ),
        throwsArgumentError,
      );
      expect(
        () => SeoRoute(
          path: '/carousel',
          delivery: SeoRouteDelivery.domFirst,
          domFirstFeatures: _features,
          applicationRuntimeHandoffProfile:
              const SeoDomFirstApplicationRuntime.carousel(
            'profile-carousel',
          ),
          meta: (_) => const SeoMeta(),
        ),
        throwsArgumentError,
      );
      expect(
        () => _profileRoute(
          '/bundle',
          profile: SeoDomFirstApplicationRuntime.bundle(
            'profile-bundle',
            members: const {
              SeoDomFirstApplicationRuntimeKind.tabs,
              SeoDomFirstApplicationRuntimeKind.carousel,
            },
          ),
        ),
        throwsArgumentError,
      );
      expect(
        () => SeoRoute(
          path: '/no-feature',
          delivery: SeoRouteDelivery.domFirst,
          applicationRuntimeHandoffProfile: _configuratorReference,
          meta: (_) => const SeoMeta(),
        ),
        throwsArgumentError,
      );
    });

    test('keeps different typed runtime identities in separate profiles', () {
      final first = _configuratorArtifact();
      final second = _configuratorArtifact(_otherConfiguratorReference);
      final routes = [
        _profileRoute('/first', runtime: _configuratorReference),
        _profileRoute(
          '/second',
          profile: _otherConfiguratorReference,
          runtime: _otherConfiguratorReference,
        ),
      ];
      final entries = {
        _configuratorReference:
            SeoDomFirstApplicationHandoffPayload.fromArtifact(
          first,
          typedProfile: true,
        ).navigationEntry,
        _otherConfiguratorReference:
            SeoDomFirstApplicationHandoffPayload.fromArtifact(
          second,
          typedProfile: true,
        ).navigationEntry,
      };

      final firstPlan = buildSeoDomFirstNavigationPlan(
        routes: routes,
        currentRoute: routes.first,
        siteBase: 'https://x.dev',
        applicationRuntimes: entries,
      )!;
      final secondPlan = buildSeoDomFirstNavigationPlan(
        routes: routes,
        currentRoute: routes.last,
        siteBase: 'https://x.dev',
        applicationRuntimes: entries,
      )!;

      expect(firstPlan.profile, isNot(secondPlan.profile));
      expect(
          firstPlan.profileRuntime?.applicationId, _configuratorReference.id);
      expect(
        secondPlan.profileRuntime?.applicationId,
        _otherConfiguratorReference.id,
      );
    });

    test('renders stable Configurator CSS and the schema-4 loader', () {
      final artifact = _configuratorArtifact();
      final payload = SeoDomFirstApplicationHandoffPayload.fromArtifact(
        artifact,
        typedProfile: true,
      );
      final routes = [
        _profileRoute('/overview'),
        _profileRoute('/pricing', runtime: _configuratorReference),
      ];
      final entries = {_configuratorReference: payload.navigationEntry};
      final overviewPlan = buildSeoDomFirstNavigationPlan(
        routes: routes,
        currentRoute: routes.first,
        siteBase: 'https://x.dev',
        applicationRuntimes: entries,
      )!;
      final pricingPlan = buildSeoDomFirstNavigationPlan(
        routes: routes,
        currentRoute: routes.last,
        siteBase: 'https://x.dev',
        applicationRuntimes: entries,
      )!;
      final overviewHtml = SeoPage.domFirstFromNodes(
        body: [SeoNode(tag: 'h1', text: 'Overview')],
        features: _features,
        navigationPlan: overviewPlan,
      ).toHtmlDocument();
      final pricingHtml = SeoPage.domFirstFromNodes(
        body: [SeoNode(tag: 'h1', text: 'Pricing')],
        features: _features,
        navigationPlan: pricingPlan,
        applicationRuntime: artifact,
      ).toHtmlDocument();

      expect(overviewHtml, contains('.esen-seo-configurator-controls'));
      expect(overviewHtml, isNot(contains('.esen-seo-collection-toolbar')));
      expect(
        overviewHtml,
        contains(seoDomFirstNavigationApplicationProfileRuntime),
      );
      expect(
        overviewHtml,
        isNot(contains(seoDomFirstNavigationApplicationHandoffRuntime)),
      );
      expect(pricingHtml, contains(_configuratorJavascript));
      expect(
        pricingHtml,
        contains(seoDomFirstConfiguratorApplicationHandoffEpilogue),
      );
      expect(
        pricingHtml.indexOf(_configuratorJavascript),
        lessThan(pricingHtml.indexOf(
          seoDomFirstNavigationApplicationProfileRuntime,
        )),
      );
      payload.validateProfileBudget(includeThemeToggle: true);
    });

    test('middleware snapshots a static Configurator profile exactly once',
        () async {
      final artifact = _configuratorArtifact();
      final store = _MemoryStore(artifact);
      final routes = [
        _profileRoute('/overview'),
        _profileRoute('/pricing', runtime: _configuratorReference),
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
      final pricing = await handler(
        Request('GET', Uri.parse('https://x.dev/pricing')),
      );
      final overviewHtml = await overview.readAsString();
      final pricingHtml = await pricing.readAsString();

      expect(store.loads, 1);
      expect(overviewHtml, isNot(contains(_configuratorJavascript)));
      expect(overviewHtml, contains(artifact.manifest.sha256));
      expect(pricingHtml, contains(_configuratorJavascript));
      expect(pricingHtml, contains(artifact.manifest.sha256));
    });

    test('prerender uses one Configurator snapshot for static and active pages',
        () async {
      final build = await Directory.systemTemp.createTemp(
        'esen_configurator_handoff',
      );
      addTearDown(() => build.delete(recursive: true));
      await File('${build.path}/index.html').writeAsString(
        '<!DOCTYPE html><html><head><title>App</title></head>'
        '<body><script src="flutter_bootstrap.js"></script></body></html>',
      );
      final artifact = _configuratorArtifact();
      final store = _MemoryStore(artifact);
      final routes = [
        _profileRoute('/overview'),
        _profileRoute('/pricing', runtime: _configuratorReference),
      ];

      await prerenderSite(
        routes: routes,
        siteBase: 'https://x.dev/repo',
        buildDir: build.path,
        domFirstRuntimeStore: store,
        writeSitemap: false,
        writeRobotsTxt: false,
        writeLlmsTxt: false,
        write404Page: false,
      );
      final overview =
          await File('${build.path}/overview/index.html').readAsString();
      final pricing =
          await File('${build.path}/pricing/index.html').readAsString();

      expect(store.loads, 1);
      expect(overview, contains('.esen-seo-configurator-controls'));
      expect(overview, isNot(contains(_configuratorJavascript)));
      expect(overview, contains('"schema":4'));
      expect(pricing, contains(_configuratorJavascript));
      expect(pricing, contains('"schema":4'));
    });

    test('rejects a descriptor that borrows another admitted kind', () {
      final artifact = _configuratorArtifact();
      final valid = SeoDomFirstApplicationHandoffPayload.fromArtifact(
        artifact,
        typedProfile: true,
      ).navigationEntry;
      final routes = [
        _profileRoute('/overview'),
        _profileRoute('/pricing', runtime: _configuratorReference),
      ];

      expect(
        () => buildSeoDomFirstNavigationPlan(
          routes: routes,
          currentRoute: routes.first,
          siteBase: 'https://x.dev',
          applicationRuntimes: {
            _configuratorReference: SeoDomFirstNavigationRuntimeEntry(
              kind: 'collection',
              sha256: valid.sha256,
              bytes: valid.bytes,
              applicationId: valid.applicationId,
              contractRevision: valid.contractRevision,
            ),
          },
        ),
        throwsArgumentError,
      );
    });

    test('rejects a typed profile on a Flutter-delivered route', () {
      expect(
        () => SeoRoute(
          path: '/flutter',
          applicationRuntimeHandoffProfile: _configuratorReference,
          meta: (_) => const SeoMeta(),
        ),
        throwsA(isA<ArgumentError>()
            .having(
              (error) => error.name,
              'name',
              'applicationRuntimeHandoffProfile',
            )
            .having(
              (error) => error.message,
              'message',
              contains('requires delivery'),
            )),
      );
      expect(
        () => SeoRoute.dynamic(
          path: '/flutter-dynamic',
          applicationRuntimeHandoffProfile: _configuratorReference,
          resolve: (_) => const SeoDocument(),
        ),
        throwsA(isA<ArgumentError>()
            .having(
              (error) => error.name,
              'name',
              'applicationRuntimeHandoffProfile',
            )
            .having(
              (error) => error.message,
              'message',
              contains('requires delivery'),
            )),
      );
    });

    test('rejects an invalid runtime id in a typed profile', () {
      for (final id in ['', '9bad', 'Bad', 'a b', 'a' * 65]) {
        expect(
          () => _profileRoute(
            '/invalid',
            profile: SeoDomFirstApplicationRuntime.configurator(id),
          ),
          throwsA(isA<ArgumentError>().having(
            (error) => error.name,
            'name',
            'applicationRuntimeHandoffProfile',
          )),
          reason: id,
        );
      }
    });

    test('rejects a profile whose kind contradicts an equal runtime id', () {
      const collection = SeoDomFirstApplicationRuntime.collection('shared-id');
      const configurator =
          SeoDomFirstApplicationRuntime.configurator('shared-id');

      expect(collection, isNot(configurator));
      expect({collection, configurator}, hasLength(2));

      for (final (profile, runtime) in [
        (configurator, collection),
        (collection, configurator),
      ]) {
        expect(
          () => _profileRoute('/mixed', profile: profile, runtime: runtime),
          throwsA(isA<ArgumentError>().having(
            (error) => error.name,
            'name',
            'applicationRuntime',
          )),
          reason: profile.kind,
        );
      }
    });

    test('admits a Collection reference under the explicit typed profile', () {
      final artifact = _artifact();
      final payload = SeoDomFirstApplicationHandoffPayload.fromArtifact(
        artifact,
        typedProfile: true,
      );
      final routes = [
        _profileRoute('/overview', profile: _reference),
        _profileRoute('/articles', profile: _reference, runtime: _reference),
      ];
      final plan = buildSeoDomFirstNavigationPlan(
        routes: routes,
        currentRoute: routes.last,
        siteBase: 'https://x.dev',
        applicationRuntimes: {_reference: payload.navigationEntry},
      )!;
      final html = SeoPage.domFirstFromNodes(
        body: [SeoNode(tag: 'h1', text: 'Articles')],
        features: _features,
        navigationPlan: plan,
        applicationRuntime: artifact,
      ).toHtmlDocument();

      expect(
        plan.schemaVersion,
        seoDomFirstTypedApplicationRuntimeHandoffManifestSchema,
      );
      expect(
        plan.profile,
        'applicationRuntimeHandoff.navigation.themeToggle.application.'
        'collection.handoff-collection',
      );
      expect(plan.profileRuntime?.kind, 'collection');
      expect(html, contains(seoDomFirstCollectionStylesheet));
      expect(html, isNot(contains(seoDomFirstConfiguratorStylesheet)));
      expect(html, contains(seoDomFirstNavigationApplicationProfileRuntime));
      expect(
        html,
        isNot(contains(seoDomFirstNavigationApplicationHandoffRuntime)),
      );
      expect(html, contains(seoDomFirstApplicationHandoffEpilogue));
    });

    test('binds the exact schema-4 manifest envelope', () {
      final artifact = _configuratorArtifact();
      final payload = SeoDomFirstApplicationHandoffPayload.fromArtifact(
        artifact,
        typedProfile: true,
      );
      final routes = [
        _profileRoute('/overview'),
        _profileRoute('/pricing', runtime: _configuratorReference),
      ];
      final plan = buildSeoDomFirstNavigationPlan(
        routes: routes,
        currentRoute: routes.first,
        siteBase: 'https://x.dev/repo',
        applicationRuntimes: {_configuratorReference: payload.navigationEntry},
      )!;
      final manifest = jsonDecode(plan.manifestJson) as Map<String, dynamic>;
      final descriptor =
          ((manifest['routes'] as List).last as List).last as List;

      expect(
        manifest.keys.toList()..sort(),
        ['base', 'profile', 'routes', 'schema'],
      );
      expect(
        manifest['schema'],
        seoDomFirstTypedApplicationRuntimeHandoffManifestSchema,
      );
      expect(manifest['base'], '/repo');
      expect(manifest['profile'], plan.profile);
      expect(
        (manifest['routes'] as List).first,
        ['/overview', plan.profile, null],
      );
      expect(descriptor, hasLength(6));
      expect(descriptor[0], seoDomFirstApplicationRuntimeOwner);
      expect(descriptor[1], 'configurator');
      expect(descriptor[2], _configuratorReference.id);
      expect(descriptor[3], seoDomFirstRuntimeContractRevision);
      expect(descriptor[4], matches(RegExp(r'^[a-f0-9]{64}$')));
      expect(descriptor[5], payload.navigationEntry.bytes);
      expect(plan.manifestJson, isNot(contains('<')));
      expect(plan.manifestJson, isNot(contains('>')));
      expect(plan.manifestJson, isNot(contains('&')));
    });

    test('applies the schema-4 manifest budget after script-safe escaping', () {
      final payload = SeoDomFirstApplicationHandoffPayload.fromArtifact(
        _configuratorArtifact(),
        typedProfile: true,
      );
      final routes = [
        for (var index = 0; index < 30; index++)
          _profileRoute(
            '/$index-${List.filled(200, '<').join()}',
            runtime: _configuratorReference,
          ),
      ];

      expect(
        () => buildSeoDomFirstNavigationPlan(
          routes: routes,
          currentRoute: routes.first,
          siteBase: 'https://x.dev',
          applicationRuntimes: {
            _configuratorReference: payload.navigationEntry,
          },
        ),
        throwsArgumentError,
      );
    });

    test('rejects more than the maximum number of typed profile routes', () {
      final payload = SeoDomFirstApplicationHandoffPayload.fromArtifact(
        _configuratorArtifact(),
        typedProfile: true,
      );
      final routes = [
        _profileRoute('/pricing', runtime: _configuratorReference),
        for (var index = 0; index < seoDomFirstNavigationMaxRoutes; index++)
          SeoRoute(path: '/route-$index', meta: (_) => const SeoMeta()),
      ];

      expect(
        () => buildSeoDomFirstNavigationPlan(
          routes: routes,
          currentRoute: routes.first,
          siteBase: 'https://x.dev',
          applicationRuntimes: {
            _configuratorReference: payload.navigationEntry,
          },
        ),
        throwsArgumentError,
      );
    });

    test('binds one shared artifact across many typed profile routes', () {
      final payload = SeoDomFirstApplicationHandoffPayload.fromArtifact(
        _configuratorArtifact(),
        typedProfile: true,
      );
      final routes = [
        for (var index = 0; index < 5; index++) _profileRoute('/static-$index'),
        for (var index = 0; index < 5; index++)
          _profileRoute('/active-$index', runtime: _configuratorReference),
      ];
      final plan = buildSeoDomFirstNavigationPlan(
        routes: routes,
        currentRoute: routes.last,
        siteBase: 'https://x.dev',
        applicationRuntimes: {_configuratorReference: payload.navigationEntry},
      )!;

      expect(plan.entries, hasLength(10));
      for (final entry in plan.entries.take(5)) {
        expect(entry.runtime, isNull);
      }
      for (final entry in plan.entries.skip(5)) {
        expect(entry.runtime?.applicationId, _configuratorReference.id);
        expect(entry.runtime?.sha256, payload.navigationEntry.sha256);
        expect(entry.runtime?.bytes, payload.navigationEntry.bytes);
      }
      expect(plan.currentRuntime?.sha256, payload.navigationEntry.sha256);
      expect(plan.profileRuntime?.sha256, payload.navigationEntry.sha256);
    });

    test('keeps a typed profile document complete without JavaScript', () {
      const meta = SeoMeta(title: 'Profile');
      final body = [
        SeoNode(tag: 'main', children: [
          SeoNode(tag: 'h1', text: 'Complete without JavaScript'),
        ]),
      ];
      final artifact = _configuratorArtifact();
      final payload = SeoDomFirstApplicationHandoffPayload.fromArtifact(
        artifact,
        typedProfile: true,
      );
      final routes = [
        _profileRoute('/overview'),
        _profileRoute('/pricing', runtime: _configuratorReference),
      ];
      final entries = {_configuratorReference: payload.navigationEntry};
      final overview = _withoutScripts(SeoPage.domFirstFromNodes(
        meta: meta,
        body: body,
        features: _features,
        navigationPlan: buildSeoDomFirstNavigationPlan(
          routes: routes,
          currentRoute: routes.first,
          siteBase: 'https://x.dev',
          applicationRuntimes: entries,
        ),
        interactionNonce: 'trusted-nonce',
      ).toHtmlDocument());
      final pricing = _withoutScripts(SeoPage.domFirstFromNodes(
        meta: meta,
        body: body,
        features: _features,
        navigationPlan: buildSeoDomFirstNavigationPlan(
          routes: routes,
          currentRoute: routes.last,
          siteBase: 'https://x.dev',
          applicationRuntimes: entries,
        ),
        applicationRuntime: artifact,
        interactionNonce: 'trusted-nonce',
      ).toHtmlDocument());

      expect(overview, isNot(contains('<script')));
      expect(pricing, isNot(contains('<script')));
      expect(pricing, contains('Complete without JavaScript'));
      expect(pricing, contains('$seoDomFirstAttribute="true"'));
      expect(pricing, contains(seoDomFirstConfiguratorStylesheet));
      expect(pricing, isNot(contains(_configuratorJavascript)));
      expect(
        pricing,
        isNot(contains(seoDomFirstNavigationApplicationProfileRuntime)),
      );
      expect(pricing, overview);
    });

    test('keeps a near-ceiling artifact inside the combined handoff budget',
        () {
      final artifact = SeoDomFirstRuntimeArtifact.create(
        reference: _configuratorReference,
        javascript: _incompressibleJavascript(_nearCeilingSourceLength()),
        dartVersion: '3.6.2',
      );
      final payload = SeoDomFirstApplicationHandoffPayload.fromArtifact(
        artifact,
        typedProfile: true,
      );
      final routes = [
        _profileRoute('/overview'),
        _profileRoute('/pricing', runtime: _configuratorReference),
      ];
      final plan = buildSeoDomFirstNavigationPlan(
        routes: routes,
        currentRoute: routes.last,
        siteBase: 'https://x.dev',
        applicationRuntimes: {_configuratorReference: payload.navigationEntry},
      )!;
      final codec = GZipCodec(level: 9);

      expect(
        artifact.manifest.gzipBytes,
        lessThanOrEqualTo(seoDomFirstRuntimeMaxGzipBytes),
      );
      expect(
        artifact.manifest.gzipBytes,
        greaterThan(seoDomFirstRuntimeMaxGzipBytes - 2048),
      );
      expect(
        codec
            .encode(utf8.encode(seoDomFirstNavigationApplicationProfileRuntime))
            .length,
        lessThanOrEqualTo(8 * 1024),
      );
      expect(
        codec
            .encode(utf8.encode('${payload.javascript}'
                '$seoDomFirstNavigationApplicationProfileRuntime'
                '$seoDomFirstThemeToggleRuntime'))
            .length,
        lessThanOrEqualTo(31 * 1024),
      );
      payload.validateProfileBudget(includeThemeToggle: true);
      expect(
        SeoPage.domFirstFromNodes(
          body: [SeoNode(tag: 'h1', text: 'Pricing')],
          features: _features,
          navigationPlan: plan,
          applicationRuntime: artifact,
        ).toHtmlDocument(),
        contains(payload.javascript),
      );
    });

    test('rejects an artifact above the compressed runtime ceiling', () {
      expect(
        () => SeoDomFirstRuntimeArtifact.create(
          reference: _configuratorReference,
          javascript:
              _incompressibleJavascript(_nearCeilingSourceLength() + 1024),
          dartVersion: '3.6.2',
        ),
        throwsA(isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('size budget'),
        )),
      );
    });
  });

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

    test('pins the schema-3 handoff fragments', () {
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
        siteBase: 'https://x.dev/repo',
        applicationRuntimes: _runtimeEntries(artifact),
      )!;
      final html = SeoPage.domFirstFromNodes(
        meta: const SeoMeta(title: 'Articles'),
        body: [SeoNode(tag: 'h1', text: 'Articles')],
        features: _features,
        navigationPlan: plan,
        applicationRuntime: artifact,
        interactionNonce: 'trusted-nonce',
      ).toHtmlDocument();

      expect(
        plan.manifestJson,
        '{"schema":$seoDomFirstApplicationRuntimeHandoffManifestSchema,'
        '"base":"/repo",'
        '"profile":"applicationRuntimeHandoff.navigation.themeToggle",'
        '"routes":['
        '["/overview","applicationRuntimeHandoff.navigation.themeToggle",'
        'null],'
        '["/articles","applicationRuntimeHandoff.navigation.themeToggle",'
        '["application","collection","${_reference.id}",'
        '$seoDomFirstRuntimeContractRevision,'
        '"${payload.navigationEntry.sha256}",'
        '${payload.navigationEntry.bytes}]]]}',
      );
      expect(
        html,
        contains('<script $seoDomFirstLoadableRuntimeAttribute='
            '"$seoDomFirstApplicationRuntimeOwner" '
            '$seoDomFirstApplicationScriptAttribute="${_reference.id}" '
            '$seoDomFirstRuntimeKindAttribute="collection" '
            '$seoDomFirstRuntimeContractAttribute='
            '"$seoDomFirstRuntimeContractRevision" '
            '$seoDomFirstRuntimeSha256Attribute='
            '"${payload.navigationEntry.sha256}" '
            'nonce="trusted-nonce">${payload.javascript}</script>'),
      );
      expect(html, contains(seoDomFirstCollectionStylesheet));
      expect(html, isNot(contains(seoDomFirstConfiguratorStylesheet)));
      expect(html, contains(seoDomFirstNavigationApplicationHandoffRuntime));
      expect(
        html,
        isNot(contains(seoDomFirstNavigationApplicationProfileRuntime)),
      );
      expect(html, contains(seoDomFirstApplicationHandoffEpilogue));
      expect(
        html,
        isNot(contains(seoDomFirstConfiguratorApplicationHandoffEpilogue)),
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
