import '../renderer/html_renderer.dart';
import '../renderer/seo_node.dart';

/// An element as it will actually render: the raw node, plus its
/// attributes under the renderer's name normalization (trimmed,
/// lower-cased). Checks read `attributes` for lookups and keep `node`
/// for children and text.
typedef SeoElementView = ({SeoNode node, Map<String, String> attributes});

/// What the structural checks need from a page body, gathered in one
/// pass instead of walking the tree once per check.
///
/// The walk sees the **renderer's** view of every node, not the raw
/// tree — `HtmlRenderer.effectiveBodyTag` decides what each node
/// becomes. The two views genuinely differ: an `<img>` carrying text
/// renders as a `<span>`, an `<a>` inside an `<a>` loses its link, and
/// `{'SRC': …}` is written as `src`. Auditing the raw tree reported
/// errors on nodes the renderer had already quietly repaired, and
/// missed the repair itself.
class SeoBodyFacts {
  SeoBodyFacts._();

  /// Every heading node, in document order, paired with its level.
  final List<({int level, String text})> headings = [];

  /// Every node that renders as an `<img>`.
  final List<SeoElementView> images = [];

  /// Every node that renders as an `<a>`.
  final List<SeoElementView> links = [];

  /// Every text run, in document order — so a missing passage can be
  /// quoted rather than reported as a diff of two giant strings.
  final List<String> textRuns = [];

  /// All visible text, concatenated — for emptiness and length checks.
  final StringBuffer _text = StringBuffer();

  String get text => _text.toString().trim();

  /// Whether the body contains any node at all.
  bool get isEmpty =>
      headings.isEmpty && images.isEmpty && links.isEmpty && text.isEmpty;

  /// Whether the walk stopped early because the tree was too deep.
  ///
  /// Callers must turn this into a finding — a truncated walk that
  /// stays silent reads as "checked and clean" about content nobody
  /// looked at.
  bool truncated = false;

  /// Deep enough for any real document, shallow enough that a
  /// pathological tree — or one a resolver accidentally made
  /// self-referential — reports a finding instead of taking the
  /// process down with a StackOverflowError.
  static const int maxDepth = HtmlRenderer.maxDepth;

  /// Collects everything the checks need from [nodes].
  static SeoBodyFacts of(List<SeoNode> nodes) {
    final facts = SeoBodyFacts._();
    facts._walk(nodes);
    return facts;
  }

  void _walk(List<SeoNode> nodes, {int depth = 0, bool inAnchor = false}) {
    // Emptiness before the ceiling: recursing into a leaf's empty child
    // list is not a visit, and flagging it made a fully-walked tree of
    // exactly maxDepth+1 levels claim its own findings were incomplete.
    if (nodes.isEmpty) return;
    if (depth > maxDepth) {
      truncated = true;
      return;
    }
    for (final node in nodes) {
      final tag = HtmlRenderer.effectiveBodyTag(node, inAnchor: inAnchor);
      // The only node that renders as a <script> is JSON-LD, and its
      // payload is data, not page content: the renderer neither shows
      // its text nor renders its children. Walking into it collected
      // phantom headings that suppressed real heading.no-h1 findings.
      if (tag == 'script') continue;
      final level = tag == null ? null : _headingLevel(tag);
      if (level != null) {
        headings.add((
          level: level,
          text: _textOf(node, inAnchor: inAnchor),
        ));
      } else if (tag == 'img') {
        images.add((
          node: node,
          attributes: HtmlRenderer.effectiveAttributeNames(node),
        ));
      } else if (tag == 'a') {
        links.add((
          node: node,
          attributes: HtmlRenderer.effectiveAttributeNames(node),
        ));
      }
      // rawText on a non-script node is content: the renderer escapes
      // it into the visible output exactly like text.
      for (final text in [node.text, node.rawText]) {
        if (text == null || text.isEmpty) continue;
        if (text.trim().isNotEmpty) textRuns.add(text.trim());
        _text
          ..write(text)
          ..write(' ');
      }
      _walk(node.children, depth: depth + 1, inAnchor: inAnchor || tag == 'a');
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
String _textOf(SeoNode node, {bool inAnchor = false}) {
  final buffer = StringBuffer();
  void walk(SeoNode n, int depth, bool nestedInAnchor) {
    // Same ceiling as the fact-gathering walk: an audit must never be
    // the thing that crashes the build it is checking.
    if (depth > SeoBodyFacts.maxDepth) return;
    final tag = HtmlRenderer.effectiveBodyTag(
      n,
      inAnchor: nestedInAnchor,
    );
    // JSON-LD is data. Its raw payload and children are not visible text and
    // must not give a heading or link a phantom label.
    if (tag == 'script') return;
    for (final text in [n.text, n.rawText]) {
      if (text == null || text.isEmpty) continue;
      buffer
        ..write(text)
        ..write(' ');
    }
    for (final child in n.children) {
      walk(child, depth + 1, nestedInAnchor || tag == 'a');
    }
  }

  walk(node, 0, inAnchor);
  return buffer.toString().trim();
}

/// The visible text of [node] and its subtree.
String seoNodeText(SeoNode node) => _textOf(node);
