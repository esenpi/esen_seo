import 'package:flutter/widgets.dart';

import '../controller/seo_controller.dart';
import '../renderer/seo_node.dart';

/// What kind of HTML element a [SeoWidget] represents.
enum SeoElementType {
  /// A text element like `<h1>` or `<p>` with inline content.
  text,

  /// A self-closing `<img>` element described by its attributes.
  image,

  /// A container like `<div>` whose children come from the widget subtree.
  container,

  /// An `<a>` element whose label comes from the widget subtree.
  link,

  /// A widget that declares its own HTML translation as [SeoWidget.nodes].
  /// The subtree below it is not traversed — the declared nodes replace it.
  custom,
}

/// Internal marker widget created by the `.seo()` extensions.
///
/// It renders its [child] completely unchanged — the Flutter UI is never
/// affected. The [SeoController] finds these markers while walking the
/// element tree and mirrors them as semantic HTML.
class SeoWidget extends StatefulWidget {
  const SeoWidget({
    super.key,
    required this.child,
    required this.type,
    this.tag,
    this.content,
    this.attributes = const {},
    this.nodes,
  });

  /// The original widget, passed through untouched.
  final Widget child;

  /// How this widget maps to HTML.
  final SeoElementType type;

  /// Explicit HTML tag. When null the smart-defaults system picks one.
  final String? tag;

  /// Text content for [SeoElementType.text] elements.
  final String? content;

  /// HTML attributes, e.g. `src`/`alt` for images or `href` for links.
  final Map<String, String> attributes;

  /// The declared HTML translation for [SeoElementType.custom] widgets.
  /// Sanitized by the controller before rendering (tag and attribute
  /// policy apply to every node in the tree).
  final List<SeoNode>? nodes;

  @override
  State<SeoWidget> createState() => _SeoWidgetState();
}

class _SeoWidgetState extends State<SeoWidget> {
  @override
  void initState() {
    super.initState();
    SeoController.instance.markDirty();
  }

  @override
  void didUpdateWidget(SeoWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    SeoController.instance.markDirty();
  }

  @override
  void dispose() {
    SeoController.instance.markDirty();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
