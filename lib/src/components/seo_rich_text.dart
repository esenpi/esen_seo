import '../renderer/seo_node.dart';
import '../renderer/tag_policy.dart';

/// Semantic roles supported by [SeoRichTextSpan].
enum SeoRichTextRole {
  /// Ordinary inline text with no additional meaning.
  text,

  /// Strong importance, rendered as `<strong>`.
  strong,

  /// Stress emphasis, rendered as `<em>`.
  emphasis,

  /// Inline code, rendered as `<code>`.
  code,

  /// A navigation link, rendered as `<a href="...">` when its URL is safe.
  link,

  /// A forced line break, rendered as `<br>`.
  lineBreak,
}

/// Maximum supported nesting depth for a rich-text span tree.
const int seoRichTextMaxDepth = 200;

/// One span in a declarative rich-text tree.
///
/// The model is pure Dart so the Flutter widget and server-side renderers can
/// consume the same content. It deliberately describes meaning rather than
/// Flutter paint details: arbitrary `TextStyle` and gesture objects cannot
/// reliably reveal whether text is important, emphasized, code or a link.
class SeoRichTextSpan {
  /// Ordinary text, optionally followed by nested semantic spans.
  const SeoRichTextSpan.text(
    this.text, {
    this.children = const [],
    this.attributes = const {},
  })  : role = SeoRichTextRole.text,
        href = null;

  /// A grouping span without its own text.
  const SeoRichTextSpan.group(
    this.children, {
    this.attributes = const {},
  })  : role = SeoRichTextRole.text,
        text = null,
        href = null;

  /// Text of strong importance.
  const SeoRichTextSpan.strong({
    this.text,
    this.children = const [],
    this.attributes = const {},
  })  : role = SeoRichTextRole.strong,
        href = null;

  /// Text carrying stress emphasis.
  const SeoRichTextSpan.emphasis({
    this.text,
    this.children = const [],
    this.attributes = const {},
  })  : role = SeoRichTextRole.emphasis,
        href = null;

  /// Inline source code or another machine-readable token.
  const SeoRichTextSpan.code({
    this.text,
    this.children = const [],
    this.attributes = const {},
  })  : role = SeoRichTextRole.code,
        href = null;

  /// A link whose visible content can contain further semantic spans.
  const SeoRichTextSpan.link({
    required String href,
    this.text,
    this.children = const [],
    this.attributes = const {},
  })  : role = SeoRichTextRole.link,
        // The public link parameter stays non-nullable although the shared
        // field is null for every non-link constructor.
        // ignore: prefer_initializing_formals
        href = href;

  /// A forced line break.
  const SeoRichTextSpan.lineBreak()
      : role = SeoRichTextRole.lineBreak,
        text = null,
        href = null,
        children = const [],
        attributes = const {};

  /// Meaning carried by this span.
  final SeoRichTextRole role;

  /// Text rendered before [children].
  final String? text;

  /// Nested inline content.
  final List<SeoRichTextSpan> children;

  /// Link target for [SeoRichTextRole.link].
  final String? href;

  /// HTML attributes for this span, filtered by the normal renderer policy.
  ///
  /// A plain text span only gains a `<span>` wrapper when attributes are
  /// present. On links, the explicit [href] cannot be replaced through this
  /// map, including by a differently cased duplicate key.
  final Map<String, String> attributes;

  /// The trimmed link target accepted by the package URL policy.
  ///
  /// `null` means this span must behave as ordinary text in both Flutter and
  /// HTML. The renderer still applies the same policy again at serialization;
  /// this getter aligns presentation behavior and is not a security bypass.
  String? get effectiveHref {
    if (role != SeoRichTextRole.link) return null;
    final candidate = href?.trim();
    if (candidate == null || candidate.isEmpty) return null;
    return isAllowedSeoAttribute('href', candidate) ? candidate : null;
  }
}

/// Builds semantic HTML nodes for a rich-text tree.
///
/// Empty trees emit nothing. Plain spans stay as text nodes unless they carry
/// attributes, while nested links degrade to `<span>` so the browser never has
/// to repair invalid `<a>`-inside-`<a>` markup.
List<SeoNode> buildSeoRichTextNodes({
  required List<SeoRichTextSpan> spans,
  String tag = 'p',
  Map<String, String> attributes = const {},
}) {
  final children = _richTextNodes(spans, depth: 0, inLink: false);
  if (children.isEmpty) return const [];
  return [
    SeoNode(
      tag: tag,
      attributes: {'class': 'esen-seo-rich-text', ...attributes},
      children: children,
    ),
  ];
}

// Rich text arrives from CMS data often enough that a cyclic or absurdly deep
// tree must fail diagnostically before recursive Flutter/span construction can
// overflow the stack. Ordinary prose does not approach this depth.
List<SeoNode> _richTextNodes(
  List<SeoRichTextSpan> spans, {
  required int depth,
  required bool inLink,
}) {
  if (spans.isEmpty) return const [];
  if (depth > seoRichTextMaxDepth) {
    throw StateError(
      'SeoRichText nests deeper than $seoRichTextMaxDepth levels - is its '
      'span tree cyclic?',
    );
  }

  final nodes = <SeoNode>[];
  for (final span in spans) {
    if (span.role == SeoRichTextRole.lineBreak) {
      nodes.add(SeoNode(tag: 'br'));
      continue;
    }

    final href = span.effectiveHref;
    final isLink = span.role == SeoRichTextRole.link && !inLink && href != null;
    final children = <SeoNode>[
      if (span.text case final text? when text.isNotEmpty) SeoNode.text(text),
      ..._richTextNodes(
        span.children,
        depth: depth + 1,
        inLink: inLink || isLink,
      ),
    ];
    if (children.isEmpty) continue;

    final attributes = _withoutHref(span.attributes);
    switch (span.role) {
      case SeoRichTextRole.text:
        if (attributes.isEmpty) {
          nodes.addAll(children);
        } else {
          nodes.add(SeoNode(
            tag: 'span',
            attributes: attributes,
            children: children,
          ));
        }
      case SeoRichTextRole.strong:
        nodes.add(SeoNode(
          tag: 'strong',
          attributes: attributes,
          children: children,
        ));
      case SeoRichTextRole.emphasis:
        nodes.add(SeoNode(
          tag: 'em',
          attributes: attributes,
          children: children,
        ));
      case SeoRichTextRole.code:
        nodes.add(SeoNode(
          tag: 'code',
          attributes: attributes,
          children: children,
        ));
      case SeoRichTextRole.link:
        nodes.add(SeoNode(
          tag: isLink ? 'a' : 'span',
          attributes: {
            ...attributes,
            if (isLink) 'href': href,
          },
          children: children,
        ));
      case SeoRichTextRole.lineBreak:
        // Handled before child traversal.
        throw StateError('Unreachable rich-text line-break branch.');
    }
  }
  return nodes;
}

Map<String, String> _withoutHref(Map<String, String> attributes) => {
      for (final entry in attributes.entries)
        if (entry.key.trim().toLowerCase() != 'href') entry.key: entry.value,
    };
