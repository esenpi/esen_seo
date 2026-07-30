import 'package:flutter/widgets.dart';

import '../controller/seo_controller.dart';
import '../tags/seo_tags.dart';
import '../widgets/seo_widget.dart';

/// Adds `.seo()` to [Row].
extension RowSeo on Row {
  /// Mirrors this row as a horizontal flex container on web.
  ///
  /// ```dart
  /// Row(children: [...]).seo();
  /// // → <div style="display:flex;flex-direction:row">...</div>
  /// Row(children: [...]).seo(SeoContainerTag.tr);
  /// // → <tr>...</tr>  (Kurzform: .tr)
  /// ```
  ///
  /// Only the generic `div` carries the flex style; semantic tags like
  /// `tr` or `nav` stay attribute-free — their meaning comes from the
  /// tag itself. [attributes] adds HTML attributes like `id`; your own
  /// `style` overrides the flex default.
  ///
  /// On non-web platforms the original widget is returned unchanged.
  Widget seo([
    SeoContainerTag tag = SeoContainerTag.div,
    Map<String, String> attributes = const {},
  ]) {
    if (!SeoController.enabled) return this;
    return SeoWidget(
      type: SeoElementType.container,
      tag: tag.name,
      attributes: {
        if (tag.name == 'div') 'style': 'display:flex;flex-direction:row',
        ...attributes,
      },
      child: this,
    );
  }
}
