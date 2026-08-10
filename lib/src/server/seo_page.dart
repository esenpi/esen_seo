import '../meta/seo_meta.dart';
import '../renderer/html_renderer.dart';
import '../renderer/seo_container.dart';
import '../renderer/seo_interactions.dart';
import '../renderer/seo_node.dart';
import '../renderer/seo_stylesheet.dart';

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
/// package-owned progressive interactions.
class SeoPage {
  SeoPage({
    SeoMeta? meta,
    required this.bodyHtml,
    this.lang = 'en',
  })  : meta = meta ?? const SeoMeta(),
        stylesheet = null,
        enableInteractions = false,
        interactionNonce = null;

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
        );

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

  /// Optional CSP nonce placed on package-generated style and script tags.
  ///
  /// It does not cover the visible container's inline `style` attribute.
  final String? interactionNonce;

  /// Renders the complete HTML document.
  String toHtmlDocument() {
    final language = HtmlRenderer.escapeAttribute(lang);
    final head = StringBuffer();
    if (stylesheet != null && stylesheet!.trim().isNotEmpty) {
      head.write(seoStyleTagHtml(stylesheet!, nonce: interactionNonce));
    }
    if (enableInteractions) {
      head.write(seoInteractionStyleHtml(nonce: interactionNonce));
    }
    final runtime = enableInteractions
        ? seoInteractionScriptHtml(nonce: interactionNonce)
        : '';
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
