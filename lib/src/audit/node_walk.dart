import '../renderer/seo_node.dart';

/// What the structural checks need from a page body, gathered in one
/// pass instead of walking the tree once per check.
class SeoBodyFacts {
  SeoBodyFacts._();

  /// Every heading node, in document order, paired with its level.
  final List<({int level, String text})> headings = [];

  /// Every `<img>` node.
  final List<SeoNode> images = [];

  /// Every `<a>` node.
  final List<SeoNode> links = [];

  /// All visible text, concatenated — for emptiness and length checks.
  final StringBuffer _text = StringBuffer();

  String get text => _text.toString().trim();

  /// Whether the body contains any node at all.
  bool get isEmpty =>
      headings.isEmpty && images.isEmpty && links.isEmpty && text.isEmpty;

  /// Whether the walk stopped early because the tree was too deep.
  bool truncated = false;

  /// Deep enough for any real document, shallow enough that a
  /// pathological tree — or one a resolver accidentally made
  /// self-referential — reports a finding instead of taking the
  /// process down with a StackOverflowError.
  static const int maxDepth = 200;

  /// Collects everything the checks need from [nodes].
  static SeoBodyFacts of(List<SeoNode> nodes) {
    final facts = SeoBodyFacts._();
    facts._walk(nodes);
    return facts;
  }

  void _walk(List<SeoNode> nodes, [int depth = 0]) {
    if (depth > maxDepth) {
      truncated = true;
      return;
    }
    for (final node in nodes) {
      final tag = node.tag.toLowerCase();
      final level = _headingLevel(tag);
      if (level != null) {
        headings.add((level: level, text: _textOf(node)));
      } else if (tag == 'img') {
        images.add(node);
      } else if (tag == 'a') {
        links.add(node);
      }
      final text = node.text;
      if (text != null && text.isNotEmpty) {
        _text
          ..write(text)
          ..write(' ');
      }
      _walk(node.children, depth + 1);
    }
  }

  static int? _headingLevel(String tag) {
    if (tag.length != 2 || tag[0] != 'h') return null;
    final digit = int.tryParse(tag[1]);
    return (digit != null && digit >= 1 && digit <= 6) ? digit : null;
  }
}

/// All text under [node], including its children — the anchor text of a
/// link, the words of a heading.
String _textOf(SeoNode node) {
  final buffer = StringBuffer();
  void walk(SeoNode n, int depth) {
    // Same ceiling as the fact-gathering walk: an audit must never be
    // the thing that crashes the build it is checking.
    if (depth > SeoBodyFacts.maxDepth) return;
    final text = n.text;
    if (text != null && text.isNotEmpty) {
      buffer
        ..write(text)
        ..write(' ');
    }
    for (final child in n.children) {
      walk(child, depth + 1);
    }
  }

  walk(node, 0);
  return buffer.toString().trim();
}

/// The visible text of [node] and its subtree.
String seoNodeText(SeoNode node) => _textOf(node);
