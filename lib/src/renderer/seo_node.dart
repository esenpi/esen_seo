/// A node in the semantic HTML tree that mirrors the Flutter widget tree.
///
/// The [SeoController] builds a list of these while walking the element tree.
/// The [HtmlRenderer] turns them into an HTML string, the DOM injector turns
/// them into real DOM elements on web.
class SeoNode {
  SeoNode({
    required this.tag,
    this.text,
    this.rawText,
    Map<String, String>? attributes,
    List<SeoNode>? children,
  })  : attributes = attributes ?? <String, String>{},
        children = children ?? <SeoNode>[];

  /// A raw text node without any surrounding tag, e.g. the label inside
  /// an `<a>` element.
  factory SeoNode.text(String text) => SeoNode(tag: '', text: text);

  /// The HTML tag, e.g. `h1`, `p`, `img`, `div`, `a`.
  /// An empty tag marks a raw text node.
  final String tag;

  /// Text content of this node, rendered before [children].
  final String? text;

  /// Pre-escaped content written verbatim, without HTML escaping.
  ///
  /// Internal — only used for JSON-LD script blocks whose content is
  /// already made safe by [SeoSchema.toJsonString]. Never route
  /// user-visible text through this.
  final String? rawText;

  /// HTML attributes, e.g. `src`, `alt`, `href`, `style`.
  final Map<String, String> attributes;

  /// Nested child nodes.
  final List<SeoNode> children;

  /// Whether this node is a raw text node without a tag.
  bool get isTextOnly => tag.isEmpty;

  /// The complete HTML5 void-element list — elements that never have
  /// a closing tag.
  static const Set<String> voidElements = {
    'area',
    'base',
    'br',
    'col',
    'embed',
    'hr',
    'img',
    'input',
    'link',
    'meta',
    'source',
    'track',
    'wbr',
  };

  /// Whether this tag renders as a self-closing element.
  bool get isSelfClosing => voidElements.contains(tag);
}
