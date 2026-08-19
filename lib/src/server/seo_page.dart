import '../meta/seo_meta.dart';
import '../renderer/html_renderer.dart';
import '../renderer/seo_container.dart';
import '../renderer/seo_dom_first.dart';
import '../renderer/seo_interactions.dart';
import '../renderer/seo_node.dart';
import '../renderer/seo_stylesheet.dart';
import '../routing/seo_application_runtime.dart';
import '../routing/seo_route_delivery.dart';
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
    this.interactionNonce,
    this.applicationRuntime,
  })  : meta = meta ?? const SeoMeta(),
        bodyHtml = seoDomFirstContainerHtml(
          const HtmlRenderer().render(body),
        ),
        enableInteractions = false,
        domFirstFeatures = Set.unmodifiable(features) {
    final runtimeFeature = applicationRuntime == null
        ? null
        : _applicationRuntimeFeature(applicationRuntime!.reference);
    if (runtimeFeature != null && features.contains(runtimeFeature)) {
      throw ArgumentError.value(
        applicationRuntime!.reference,
        'applicationRuntime',
        'cannot be combined with the package-owned '
            '${applicationRuntime!.reference.kind} runtime',
      );
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
    final effectiveFeatures = {
      ...domFirstFeatures,
      if (applicationRuntime?.reference is SeoDomFirstTabsApplicationRuntime)
        SeoDomFirstFeature.tabs,
      if (applicationRuntime?.reference
          is SeoDomFirstCarouselApplicationRuntime)
        SeoDomFirstFeature.carousel,
      if (applicationRuntime?.reference is SeoDomFirstStepperApplicationRuntime)
        SeoDomFirstFeature.stepper,
    };
    final head = StringBuffer();
    head.write(
      seoDomFirstFeatureBootstrapScriptHtml(
        domFirstFeatures,
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
      ),
    );
    final runtime = StringBuffer();
    if (enableInteractions) {
      runtime.write(seoInteractionScriptHtml(nonce: interactionNonce));
    }
    runtime.write(
      seoDomFirstFeatureScriptHtml(
        domFirstFeatures,
        nonce: interactionNonce,
      ),
    );
    if (applicationRuntime case final artifact?) {
      runtime.write(_applicationRuntimeScriptHtml(
        artifact,
        nonce: interactionNonce,
      ));
    }
    return '<!DOCTYPE html>'
        '<html lang="$language">'
        '<head>'
        '<meta charset="utf-8"/>'
        '<meta name="viewport" content="width=device-width, initial-scale=1"/>'
        '${meta.toHtml()}'
        '$head'
        '</head>'
        '<body>$bodyHtml$runtime</body>'
        '</html>';
  }
}

SeoDomFirstFeature _applicationRuntimeFeature(
  SeoDomFirstApplicationRuntime reference,
) =>
    switch (reference) {
      SeoDomFirstTabsApplicationRuntime() => SeoDomFirstFeature.tabs,
      SeoDomFirstCarouselApplicationRuntime() => SeoDomFirstFeature.carousel,
      SeoDomFirstStepperApplicationRuntime() => SeoDomFirstFeature.stepper,
    };

String _applicationRuntimeScriptHtml(
  SeoDomFirstRuntimeArtifact artifact, {
  String? nonce,
}) {
  final id = HtmlRenderer.escapeAttribute(artifact.reference.id);
  final hash = HtmlRenderer.escapeAttribute(artifact.manifest.sha256);
  final value = nonce?.trim();
  final nonceAttribute = value == null || value.isEmpty
      ? ''
      : ' nonce="${HtmlRenderer.escapeAttribute(value)}"';
  return '<script $seoDomFirstApplicationScriptAttribute="$id" '
      'data-esen-seo-runtime-sha256="$hash"$nonceAttribute>'
      '${artifact.javascript}</script>';
}
