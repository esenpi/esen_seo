import 'seo_node.dart';
import 'tag_policy.dart';

/// Where a rendered fragment is going to land.
enum SeoRenderTarget {
  /// Inside `<body>` — the ordinary tag and attribute policy applies.
  body,

  /// Inside `<head>` — only the head elements esen_seo manages are
  /// allowed, and nothing else gets in.
  head,
}

/// Renders a tree of [SeoNode]s into a clean, semantic HTML string.
///
/// Pure Dart with no platform dependencies, so it runs everywhere:
/// in the browser, on the Dart server and in unit tests.
///
/// **The renderer is the choke point for safety.** Tags and attributes
/// are filtered here, not by the caller, because every path to HTML —
/// the Flutter mirror, the SSR middleware and the prerenderer — ends up
/// in this class. A node tree assembled from untrusted data (a CMS
/// block, say) can therefore not smuggle a `<script>`, an `onerror=`
/// handler or a broken-out attribute into the output, no matter which
/// path it took to get here.
class HtmlRenderer {
  /// A renderer for body content.
  const HtmlRenderer() : target = SeoRenderTarget.body;

  /// A renderer for the document head — used by `SeoMeta`, whose tags
  /// (`title`, `meta`, `link`, …) the body policy deliberately blocks.
  const HtmlRenderer.head() : target = SeoRenderTarget.head;

  /// Which policy this renderer applies.
  final SeoRenderTarget target;

  /// Renders a list of top-level nodes into one HTML fragment.
  String render(List<SeoNode> nodes) {
    final buffer = StringBuffer();
    for (final node in nodes) {
      _write(buffer, node);
    }
    return buffer.toString();
  }

  /// Renders a single node including all of its children.
  String renderNode(SeoNode node) {
    final buffer = StringBuffer();
    _write(buffer, node);
    return buffer.toString();
  }

  /// Writes [node] into [buffer] — one shared buffer for the whole
  /// tree instead of one string allocation per node.
  void _write(StringBuffer buffer, SeoNode node) {
    if (node.isTextOnly) {
      buffer.write(escapeText(node.text ?? ''));
      return;
    }

    final tag = _resolveTag(node);
    if (tag == null) return; // nichts, was hier stehen dürfte

    buffer
      ..write('<')
      ..write(tag);
    node.attributes.forEach((name, value) {
      final attribute = name.trim().toLowerCase();
      // Namen werden hier geprüft, nicht escaped: Ein Name, der die
      // Policy nicht besteht, hat im Dokument nichts verloren — ein
      // escapetes `x" onmouseover="…` wäre bloß kaputtes Markup.
      if (!isAllowedSeoAttribute(attribute, value)) return;
      buffer
        ..write(' ')
        ..write(attribute)
        ..write('="')
        ..write(escapeAttribute(value))
        ..write('"');
    });

    if (SeoNode.voidElements.contains(tag)) {
      buffer.write('/>');
      return;
    }

    buffer.write('>');
    if (node.text != null) buffer.write(escapeText(node.text!));
    if (node.rawText != null) buffer.write(escapeRawText(node.rawText!));
    for (final child in node.children) {
      _write(buffer, child);
    }
    buffer
      ..write('</')
      ..write(tag)
      ..write('>');
  }

  /// The tag this node may actually be rendered as, or `null` when it
  /// must be dropped entirely.
  String? _resolveTag(SeoNode node) {
    // JSON-LD is the one script that is content rather than code, and
    // it is legal in both head and body.
    if (_isJsonLd(node)) return 'script';
    if (target == SeoRenderTarget.head) {
      return _headElements.contains(node.tag) ? node.tag : null;
    }
    // Blocked or malformed tags degrade to a neutral container instead
    // of taking the page down with them.
    return normalizeSeoTag(node.tag) ?? 'div';
  }

  static bool _isJsonLd(SeoNode node) =>
      node.tag == 'script' &&
      node.attributes['type'] == 'application/ld+json';

  /// The head elements `SeoMeta` builds. Everything else is refused —
  /// the head is no place for arbitrary markup.
  static const Set<String> _headElements = {'title', 'meta', 'link', 'base'};

  static final RegExp _needsTextEscape = RegExp('[&<>]');
  static final RegExp _needsAttributeEscape = RegExp('[&<>"]');
  static final RegExp _rawTextBreakout =
      RegExp(r'<(?=/\s*(script|style))', caseSensitive: false);

  /// Escapes text content so it is safe inside an HTML element.
  ///
  /// Fast path: most strings contain no special characters and are
  /// returned unchanged without any allocation.
  static String escapeText(String value) {
    if (!_needsTextEscape.hasMatch(value)) return value;
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
  }

  /// Escapes a value so it is safe inside a double-quoted HTML attribute.
  static String escapeAttribute(String value) {
    if (!_needsAttributeEscape.hasMatch(value)) return value;
    return escapeText(value).replaceAll('"', '&quot;');
  }

  /// Makes verbatim content safe to sit inside a `<script>` element.
  ///
  /// [SeoNode.rawText] exists so JSON-LD can keep its quotes and
  /// braces — `SeoSchema.toJsonString` already escapes `<`. Content
  /// from anywhere else must not be able to close the element early,
  /// so a `</script` or `</style` sequence is neutralized with the
  /// JSON escape that survives a round trip.
  static String escapeRawText(String value) =>
      value.replaceAll(_rawTextBreakout, r'\u003C');
}
