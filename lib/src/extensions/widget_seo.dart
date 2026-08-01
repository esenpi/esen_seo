import 'package:flutter/widgets.dart';

import '../controller/seo_controller.dart';
import '../renderer/seo_node.dart';
import '../widgets/seo_widget.dart';

/// Adds `.seoNodes()` to every widget — the escape hatch for widgets
/// that cannot be mirrored automatically.
extension WidgetSeo on Widget {
  /// Declares this widget's HTML translation explicitly.
  ///
  /// Most widgets mirror automatically (`Text`, `Image`, containers) or
  /// with one `.seo()` call. Widgets that paint their content — charts,
  /// gauges, custom canvases — are a black box to the mirror: pixels
  /// carry no semantics. What *is* translatable is the data they paint
  /// from. `.seoNodes()` lets a widget hand that data over as HTML:
  ///
  /// ```dart
  /// MyRatingStars(score: 4.5).seoNodes([
  ///   SeoNode(tag: 'p', text: 'Rated 4.5 out of 5 stars'),
  /// ]);
  /// ```
  ///
  /// The declared nodes **replace** the widget's subtree in the mirror,
  /// so nothing is mirrored twice. The same safety policy as everywhere
  /// else applies to the whole tree: blocked tags (`script`, `style`, …)
  /// fall back to `div`, event handlers and executable URLs are dropped,
  /// and text is escaped by the renderer.
  ///
  /// The SEO widget library (e.g. `SeoBarChart`) builds on exactly this
  /// mechanism. On non-web platforms the original widget is returned
  /// unchanged.
  Widget seoNodes(List<SeoNode> nodes) {
    if (!SeoController.enabled) return this;
    return SeoWidget(
      type: SeoElementType.custom,
      nodes: nodes,
      child: this,
    );
  }
}
