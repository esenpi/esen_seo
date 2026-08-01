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

    // Namen einmal normalisieren: Zwei Schlüssel, die sich nur in der
    // Schreibweise unterscheiden, würden sonst zweimal ausgegeben — und
    // HTML nimmt das erste, während unsere Prüfung das zweite ansah.
    final attributes = <String, String>{};
    node.attributes.forEach((name, value) {
      attributes[name.trim().toLowerCase()] = value;
    });

    final tag = _resolveTag(node, attributes);
    if (tag == null) return; // nichts, was hier stehen dürfte

    // Ein abgelehntes Element verliert mit seiner Identität auch seine
    // Attribute: `action` oder `values` gehören zu dem Element, das es
    // nicht sein darf, und haben auf einem <div> nichts zu suchen.
    final refused = tag != node.tag.trim().toLowerCase();

    buffer
      ..write('<')
      ..write(tag);
    if (!refused) {
      attributes.forEach((name, value) {
        // Namen werden hier geprüft, nicht escaped: Ein Name, der die
        // Policy nicht besteht, hat im Dokument nichts verloren — ein
        // escapetes `x" onmouseover="…` wäre bloß kaputtes Markup.
        if (!isAllowedSeoAttribute(name, value)) return;
        if (target == SeoRenderTarget.head && !_allowedHeadAttribute(name)) {
          return;
        }
        buffer
          ..write(' ')
          ..write(name)
          ..write('="')
          ..write(escapeAttribute(value))
          ..write('"');
      });
    }

    if (SeoNode.voidElements.contains(tag)) {
      buffer.write('/>');
      return;
    }

    buffer.write('>');
    if (node.text != null) buffer.write(escapeText(node.text!));
    if (node.rawText != null) {
      // Verbatim only where it is the point: a JSON-LD payload, whose
      // `<` is escaped so it cannot close the element or start markup.
      // Anywhere else rawText is content, and content gets escaped —
      // otherwise this one field bypasses tag policy, attribute policy
      // and text escaping all at once.
      buffer.write(_isJsonLd(attributes)
          ? escapeJsonLd(node.rawText!)
          : escapeText(node.rawText!));
    }
    // A JSON-LD element holds a string, not markup: rendering children
    // into it would close the script early.
    if (!_isJsonLd(attributes) || node.tag != 'script') {
      for (final child in node.children) {
        _write(buffer, child);
      }
    }
    buffer
      ..write('</')
      ..write(tag)
      ..write('>');
  }

  /// The tag this node may actually be rendered as, or `null` when it
  /// must be dropped entirely.
  String? _resolveTag(SeoNode node, Map<String, String> attributes) {
    // JSON-LD is the one script that is content rather than code, and
    // it is legal in both head and body.
    if (node.tag == 'script' && _isJsonLd(attributes)) return 'script';
    if (target == SeoRenderTarget.head) {
      return _headElements.contains(node.tag) ? node.tag : null;
    }
    // Anything not on the allow list degrades to a neutral container
    // instead of taking the page down with it.
    return normalizeSeoTag(node.tag) ?? 'div';
  }

  /// Checked against the **normalized** attribute map, so a second key
  /// differing only in case cannot slip a `type` past this.
  static bool _isJsonLd(Map<String, String> attributes) =>
      attributes['type'] == 'application/ld+json';

  /// The head elements `SeoMeta` builds. Everything else is refused —
  /// the head is no place for arbitrary markup.
  static const Set<String> _headElements = {'title', 'meta', 'link'};

  /// What those head elements may carry. `http-equiv` would let a
  /// meta tag redirect the page, and a `<base href>` would repoint
  /// every relative URL in the document.
  static const Set<String> _headAttributes = {
    'name',
    'property',
    'content',
    'rel',
    'href',
    'hreflang',
    'type',
    'charset',
    'media',
    'sizes',
    'as',
    'crossorigin',
  };

  static bool _allowedHeadAttribute(String name) =>
      _headAttributes.contains(name);

  static final RegExp _needsTextEscape = RegExp('[&<>]');
  static final RegExp _needsAttributeEscape = RegExp('[&<>"]');

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

  /// Makes a JSON-LD payload safe to sit inside a `<script>` element.
  ///
  /// Every `<` becomes the JSON escape `\\u003C`. That is lossless for
  /// JSON — `SeoSchema.toJsonString` already does it — and it is the
  /// only reliable rule: guarding just `</script` leaves `<!--<script>`,
  /// which puts the HTML tokenizer into a state where the rest of the
  /// page is swallowed as script data.
  static String escapeJsonLd(String value) => value.replaceAll('<', r'\u003C');
}
