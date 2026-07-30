import 'seo_node.dart';

/// Renders a tree of [SeoNode]s into a clean, semantic HTML string.
///
/// Pure Dart with no platform dependencies, so it runs everywhere:
/// in the browser, on the Dart server and in unit tests.
class HtmlRenderer {
  const HtmlRenderer();

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

    buffer
      ..write('<')
      ..write(node.tag);
    node.attributes.forEach((name, value) {
      buffer
        ..write(' ')
        ..write(name)
        ..write('="')
        ..write(escapeAttribute(value))
        ..write('"');
    });

    if (node.isSelfClosing) {
      buffer.write('/>');
      return;
    }

    buffer.write('>');
    if (node.text != null) buffer.write(escapeText(node.text!));
    if (node.rawText != null) buffer.write(node.rawText!);
    for (final child in node.children) {
      _write(buffer, child);
    }
    buffer
      ..write('</')
      ..write(node.tag)
      ..write('>');
  }

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
}
