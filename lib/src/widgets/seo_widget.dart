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
  ModalRoute<dynamic>? _route;

  @override
  void initState() {
    super.initState();
    SeoController.instance.markDirty();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Mount, update and dispose all mark the mirror dirty — but none of
    // them fires when a route TRANSITION finishes. The refresh after a
    // push runs during the transition, while the outgoing route is
    // still onstage; only at the end does the Navigator put it
    // Offstage, and at that moment no widget mounts, updates or
    // disposes. The mirror then serves the old page under the new URL
    // — cloaking by timing. So every marker listens to its own route's
    // animation and marks dirty once more when it settles; the
    // controller collapses the flood into one refresh per frame.
    final route = ModalRoute.of(context);
    if (route != _route) {
      _route?.animation?.removeStatusListener(_onRouteAnimationStatus);
      _route = route;
      route?.animation?.addStatusListener(_onRouteAnimationStatus);
    }
  }

  void _onRouteAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed ||
        status == AnimationStatus.dismissed) {
      // Not markDirty directly: the Navigator applies the Offstage flip
      // to the outgoing route in the Overlay rebuild one frame AFTER
      // the animation settles. A refresh at the end of THIS frame still
      // sees both routes onstage and mirrors both pages. Hop one frame
      // — the callback registered during this frame's post-frame phase
      // runs at the end of the next one, after the Overlay has rebuilt.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        SeoController.instance.markDirty();
      });
      WidgetsBinding.instance.scheduleFrame();
    }
  }

  @override
  void didUpdateWidget(SeoWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    SeoController.instance.markDirty();
  }

  @override
  void dispose() {
    _route?.animation?.removeStatusListener(_onRouteAnimationStatus);
    SeoController.instance.markDirty();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
