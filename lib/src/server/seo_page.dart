import '../meta/seo_meta.dart';
import '../renderer/html_renderer.dart';
import '../renderer/seo_node.dart';

/// A complete server-rendered page for bots: head metadata plus a
/// semantic HTML body.
///
/// ```dart
/// SeoPage(
///   meta: SeoMeta(title: 'Willkommen', description: '...'),
///   bodyHtml: '<h1>Willkommen</h1><p>Flutter mit echtem SEO.</p>',
/// );
/// ```
///
/// The body can also be built from [SeoNode]s via [SeoPage.fromNodes] —
/// then all text is escaped by the [HtmlRenderer], exactly like in the
/// Flutter app.
class SeoPage {
  SeoPage({
    SeoMeta? meta,
    required this.bodyHtml,
    this.lang = 'en',
  }) : meta = meta ?? const SeoMeta();

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

  /// Head metadata: title, description, OpenGraph, JSON-LD schemas.
  final SeoMeta meta;

  /// The semantic HTML body served to bots.
  final String bodyHtml;

  /// The `lang` attribute of the `<html>` element, e.g. `de`.
  final String lang;

  /// Renders the complete HTML document.
  String toHtmlDocument() {
    final language = HtmlRenderer.escapeAttribute(lang);
    return '<!DOCTYPE html>'
        '<html lang="$language">'
        '<head>'
        '<meta charset="utf-8"/>'
        '<meta name="viewport" content="width=device-width, initial-scale=1"/>'
        '${meta.toHtml()}'
        '</head>'
        '<body>$bodyHtml</body>'
        '</html>';
  }
}
