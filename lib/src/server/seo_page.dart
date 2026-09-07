import '../meta/seo_meta.dart';
import '../renderer/html_renderer.dart';
import '../renderer/seo_container.dart';
import '../renderer/seo_dom_first.dart';
import '../renderer/seo_dom_first_runtime_handoff.dart';
import '../renderer/seo_interactions.dart';
import '../renderer/seo_node.dart';
import '../renderer/seo_stylesheet.dart';
import '../routing/seo_application_runtime.dart';
import '../routing/seo_dom_first_navigation.dart';
import '../routing/seo_route_delivery.dart';
import 'seo_application_runtime_handoff.dart';
import 'seo_runtime_store.dart';

/// Marks a verified application-authored runtime in a DOM-first document.
const String seoDomFirstApplicationScriptAttribute =
    'data-esen-seo-dom-first-application-runtime';

/// A complete server-rendered page: head metadata plus a semantic HTML body.
///
/// ```dart
/// SeoPage(
///   meta: SeoMeta(title: 'Willkommen', description: '...'),
///   bodyHtml: '<h1>Willkommen</h1><p>Flutter mit echtem SEO.</p>',
/// );
/// ```
///
/// The body can also be built from [SeoNode]s via [SeoPage.fromNodes] - then
/// all text is escaped by the [HtmlRenderer], exactly like in the Flutter app.
/// [SeoPage.visibleFromNodes] creates a standalone, visible page with optional
/// package-owned progressive interactions. [SeoPage.domFirstFromNodes] creates
/// a permanent semantic page with separately selected compiled capabilities.
class SeoPage {
  SeoPage({
    SeoMeta? meta,
    required this.bodyHtml,
    this.lang = 'en',
  })  : meta = meta ?? const SeoMeta(),
        stylesheet = null,
        enableInteractions = false,
        interactionNonce = null,
        domFirstFeatures = const {},
        navigationPlan = null,
        applicationRuntime = null;

  /// Builds the body from [SeoNode]s using the same renderer as the
  /// Flutter side.
  SeoPage.fromNodes({
    SeoMeta? meta,
    required List<SeoNode> body,
    String lang = 'en',
  }) : this(
          meta: meta,
          bodyHtml: const HtmlRenderer().render(body),
          lang: lang,
        );

  /// Builds a standalone page whose semantic body is visible without Flutter.
  ///
  /// The source HTML remains complete when JavaScript is unavailable. Setting
  /// [enableInteractions] only adds package-owned progressive enhancement for
  /// components that explicitly opt in, such as interactive `SeoTabs`.
  SeoPage.visibleFromNodes({
    SeoMeta? meta,
    required List<SeoNode> body,
    this.lang = 'en',
    this.stylesheet = seoDefaultStylesheet,
    this.enableInteractions = true,
    this.interactionNonce,
  })  : meta = meta ?? const SeoMeta(),
        bodyHtml = seoContainerHtml(
          const HtmlRenderer().render(body),
          mode: SeoRenderMode.visibleShell,
        ),
        domFirstFeatures = const {},
        navigationPlan = null,
        applicationRuntime = null;

  /// Builds a permanent semantic page without a Flutter browser runtime.
  ///
  /// [features] is independent from [enableInteractions]: only the compiled
  /// capabilities selected for this DOM-first route are included.
  SeoPage.domFirstFromNodes({
    SeoMeta? meta,
    required List<SeoNode> body,
    this.lang = 'en',
    this.stylesheet = seoDefaultStylesheet,
    Set<SeoDomFirstFeature> features = const {},
    this.navigationPlan,
    this.interactionNonce,
    this.applicationRuntime,
  })  : meta = meta ?? const SeoMeta(),
        bodyHtml = seoDomFirstContainerHtml(
          const HtmlRenderer.domFirst().render(body),
        ),
        enableInteractions = false,
        domFirstFeatures = Set.unmodifiable(features) {
    if (features.contains(SeoDomFirstFeature.runtimeHandoff) &&
        applicationRuntime != null) {
      throw ArgumentError.value(
        applicationRuntime!.reference,
        'applicationRuntime',
        'cannot be combined with runtimeHandoff',
      );
    }
    if (features.contains(SeoDomFirstFeature.applicationRuntimeHandoff) &&
        applicationRuntime != null &&
        !_admittedApplicationHandoffRuntime(
          applicationRuntime!.reference,
          typedProfile: navigationPlan?.schemaVersion ==
              seoDomFirstTypedApplicationRuntimeHandoffManifestSchema,
        )) {
      throw ArgumentError.value(
        applicationRuntime!.reference,
        'applicationRuntime',
        'is not admitted by this applicationRuntimeHandoff profile',
      );
    }
    final expectedNavigationProfile =
        seoDomFirstNavigationFeatureProfile(features);
    if ((expectedNavigationProfile == null) != (navigationPlan == null) ||
        (navigationPlan != null &&
            !_matchesNavigationProfile(
              navigationPlan!,
              expectedNavigationProfile!,
            ))) {
      throw ArgumentError.value(
        navigationPlan,
        'navigationPlan',
        'must exactly match the selected DOM-first navigation profile',
      );
    }
    if (features.contains(SeoDomFirstFeature.applicationRuntimeHandoff)) {
      final expectedRuntime = navigationPlan?.currentRuntime;
      final artifact = applicationRuntime;
      final payload = artifact == null
          ? null
          : SeoDomFirstApplicationHandoffPayload.fromArtifact(
              artifact,
              typedProfile: navigationPlan?.schemaVersion ==
                  seoDomFirstTypedApplicationRuntimeHandoffManifestSchema,
            );
      final actualRuntime = payload?.navigationEntry;
      if (!_sameApplicationRuntime(expectedRuntime, actualRuntime)) {
        throw ArgumentError.value(
          artifact?.reference,
          'applicationRuntime',
          'must exactly match the current navigation-plan runtime',
        );
      }
    }
    for (final runtimeFeature
        in applicationRuntime?.reference.memberKinds ?? const []) {
      final feature = _applicationRuntimeFeature(runtimeFeature);
      if (features.contains(feature)) {
        throw ArgumentError.value(
          applicationRuntime!.reference,
          'applicationRuntime',
          'cannot combine ${runtimeFeature.value} with the package-owned '
              '${feature.name} runtime',
        );
      }
    }
  }

  /// Head metadata: title, description, OpenGraph, JSON-LD schemas.
  final SeoMeta meta;

  /// The semantic HTML body written into the document.
  ///
  /// **This string is written into the document verbatim.** It is the
  /// one deliberate way past the renderer's tag and attribute policy,
  /// meant for HTML you wrote yourself. Never build it from content you
  /// do not control — use [SeoPage.fromNodes] for that, which puts the
  /// nodes through the policy.
  final String bodyHtml;

  /// The `lang` attribute of the `<html>` element, e.g. `de`.
  final String lang;

  /// Optional inline CSS for a visible semantic page.
  final String? stylesheet;

  /// Whether to include the trusted package interaction runtime.
  ///
  /// The runtime only enhances components that explicitly opt in and ignores
  /// content below an `inert` or `aria-hidden="true"` ancestor.
  final bool enableInteractions;

  /// Compiled behaviours selected for a permanent DOM-first page.
  final Set<SeoDomFirstFeature> domFirstFeatures;

  /// Ordered route manifest for the profile-bound navigation runtime.
  final SeoDomFirstNavigationPlan? navigationPlan;

  /// A separately built and verified application transition for this page.
  final SeoDomFirstRuntimeArtifact? applicationRuntime;

  /// Optional CSP nonce placed on package-generated style and script tags.
  ///
  /// In visible-shell mode it does not cover the container's inline `style`
  /// attribute.
  final String? interactionNonce;

  /// Renders the complete HTML document.
  String toHtmlDocument() {
    final language = HtmlRenderer.escapeAttribute(lang);
    final navigation = navigationPlan;
    final handoffKind = SeoDomFirstApplicationRuntimeKind.tryParse(
      navigation?.profileRuntime?.kind ?? '',
    );
    final effectiveFeatures = {
      ...domFirstFeatures,
      for (final member
          in applicationRuntime?.reference.memberKinds ?? const [])
        _applicationRuntimeFeature(member),
    };
    final bootstrapFeatures = {
      ...effectiveFeatures,
      if (enableInteractions) ...const {
        SeoDomFirstFeature.tabs,
        SeoDomFirstFeature.carousel,
        SeoDomFirstFeature.stepper,
      },
    };
    final head = StringBuffer();
    final metaHtml = navigation == null
        ? meta.toHtml()
        : const HtmlRenderer.navigationHead().render(meta.toNodes());
    final navigationManifestHtml = navigation == null
        ? ''
        : '<script type="application/json" '
            '$seoDomFirstNavigationManifestAttribute '
            'data-esen-navigation-profile="'
            '${HtmlRenderer.escapeAttribute(navigation.profile)}"'
            '${_nonceAttribute(interactionNonce)}>'
            '${navigation.manifestJson}</script>';
    head.write(
      seoDomFirstFeatureBootstrapScriptHtml(
        bootstrapFeatures,
        nonce: interactionNonce,
      ),
    );
    if (stylesheet != null && stylesheet!.trim().isNotEmpty) {
      head.write(seoStyleTagHtml(stylesheet!, nonce: interactionNonce));
    }
    if (enableInteractions) {
      head.write(seoInteractionStyleHtml(nonce: interactionNonce));
    }
    head.write(
      seoDomFirstFeatureStyleHtml(
        effectiveFeatures,
        nonce: interactionNonce,
        applicationRuntimeHandoffKind: handoffKind,
      ),
    );
    final runtime = StringBuffer();
    final applicationHandoff = domFirstFeatures.contains(
      SeoDomFirstFeature.applicationRuntimeHandoff,
    );
    final applicationArtifact = applicationRuntime;
    if (enableInteractions) {
      runtime.write(seoInteractionScriptHtml(nonce: interactionNonce));
    }
    if (applicationHandoff && applicationArtifact != null) {
      runtime.write(_applicationRuntimeScriptHtml(
        applicationArtifact,
        nonce: interactionNonce,
        handoff: true,
        typedHandoff: navigation?.schemaVersion ==
            seoDomFirstTypedApplicationRuntimeHandoffManifestSchema,
        includeThemeToggle:
            domFirstFeatures.contains(SeoDomFirstFeature.themeToggle),
      ));
    }
    runtime.write(
      seoDomFirstFeatureScriptHtml(
        domFirstFeatures,
        nonce: interactionNonce,
        applicationRuntimeHandoffSchema: navigation?.schemaVersion,
      ),
    );
    if (!applicationHandoff && applicationArtifact != null) {
      runtime.write(_applicationRuntimeScriptHtml(
        applicationArtifact,
        nonce: interactionNonce,
      ));
    }
    return '<!DOCTYPE html>'
        '<html lang="$language">'
        '<head>'
        '<meta charset="utf-8"/>'
        '<meta name="viewport" content="width=device-width, initial-scale=1"/>'
        '$metaHtml'
        '$navigationManifestHtml'
        '$head'
        '</head>'
        '<body>$bodyHtml$runtime</body>'
        '</html>';
  }
}

bool _sameApplicationRuntime(
  SeoDomFirstNavigationRuntimeEntry? expected,
  SeoDomFirstNavigationRuntimeEntry? actual,
) =>
    expected == null
        ? actual == null
        : actual != null &&
            expected.kind == actual.kind &&
            expected.applicationId == actual.applicationId &&
            expected.contractRevision == actual.contractRevision &&
            expected.sha256 == actual.sha256 &&
            expected.bytes == actual.bytes;

SeoDomFirstFeature _applicationRuntimeFeature(
  SeoDomFirstApplicationRuntimeKind kind,
) =>
    switch (kind) {
      SeoDomFirstApplicationRuntimeKind.tabs => SeoDomFirstFeature.tabs,
      SeoDomFirstApplicationRuntimeKind.carousel => SeoDomFirstFeature.carousel,
      SeoDomFirstApplicationRuntimeKind.collection =>
        SeoDomFirstFeature.collection,
      SeoDomFirstApplicationRuntimeKind.configurator =>
        SeoDomFirstFeature.configurator,
      SeoDomFirstApplicationRuntimeKind.editorialWorkflow =>
        SeoDomFirstFeature.editorialWorkflow,
      SeoDomFirstApplicationRuntimeKind.approvalChecklist =>
        SeoDomFirstFeature.approvalChecklist,
      SeoDomFirstApplicationRuntimeKind.stepper ||
      SeoDomFirstApplicationRuntimeKind.stepperEffects =>
        SeoDomFirstFeature.stepper,
    };

String _applicationRuntimeScriptHtml(
  SeoDomFirstRuntimeArtifact artifact, {
  String? nonce,
  bool handoff = false,
  bool typedHandoff = false,
  bool includeThemeToggle = false,
}) {
  if (handoff) {
    final payload = SeoDomFirstApplicationHandoffPayload.fromArtifact(
      artifact,
      typedProfile: typedHandoff,
    );
    payload.validateProfileBudget(
      includeThemeToggle: includeThemeToggle,
    );
    final reference = artifact.reference;
    final id = HtmlRenderer.escapeAttribute(reference.id);
    final kind = HtmlRenderer.escapeAttribute(reference.kind);
    final contract = artifact.manifest.contractRevision;
    final hash = HtmlRenderer.escapeAttribute(
      payload.navigationEntry.sha256,
    );
    return '<script $seoDomFirstLoadableRuntimeAttribute="'
        '$seoDomFirstApplicationRuntimeOwner" '
        '$seoDomFirstApplicationScriptAttribute="$id" '
        '$seoDomFirstRuntimeKindAttribute="$kind" '
        '$seoDomFirstRuntimeContractAttribute="$contract" '
        '$seoDomFirstRuntimeSha256Attribute="$hash"'
        '${_nonceAttribute(nonce)}>${payload.javascript}</script>';
  }
  final id = HtmlRenderer.escapeAttribute(artifact.reference.id);
  final hash = HtmlRenderer.escapeAttribute(artifact.manifest.sha256);
  final nonceAttribute = _nonceAttribute(nonce);
  final hasInteractionLayout = artifact.reference.memberKinds
      .any((kind) => kind != SeoDomFirstApplicationRuntimeKind.collection);
  return '<script $seoDomFirstApplicationScriptAttribute="$id" '
      'data-esen-seo-runtime-sha256="$hash"$nonceAttribute>'
      '${artifact.javascript}'
      '${artifact.reference.memberKinds.contains(SeoDomFirstApplicationRuntimeKind.collection) ? ';delete document.documentElement.dataset.esenCollectionPending' : ''}'
      '${hasInteractionLayout ? ';delete document.documentElement.dataset.esenInteractionPending' : ''}'
      '</script>';
}

bool _matchesNavigationProfile(
  SeoDomFirstNavigationPlan plan,
  String featureProfile,
) {
  if (plan.schemaVersion ==
      seoDomFirstTypedApplicationRuntimeHandoffManifestSchema) {
    final runtime = plan.profileRuntime;
    return runtime != null &&
        plan.profile ==
            '$featureProfile.application.${runtime.kind}.'
                '${runtime.applicationId}';
  }
  return plan.profile == featureProfile;
}

bool _admittedApplicationHandoffRuntime(
  SeoDomFirstApplicationRuntime runtime, {
  required bool typedProfile,
}) =>
    typedProfile
        ? runtime is SeoDomFirstCollectionApplicationRuntime ||
            runtime is SeoDomFirstConfiguratorApplicationRuntime ||
            runtime is SeoDomFirstEditorialWorkflowApplicationRuntime
        : runtime is SeoDomFirstCollectionApplicationRuntime;

String _nonceAttribute(String? nonce) {
  final value = nonce?.trim();
  return value == null || value.isEmpty
      ? ''
      : ' nonce="${HtmlRenderer.escapeAttribute(value)}"';
}
