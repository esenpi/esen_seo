import 'package:flutter/widgets.dart';

import '../controller/seo_controller.dart';
import '../tags/seo_tags.dart';
import '../widgets/seo_widget.dart';

/// Adds `.seo()` to [Column].
extension ColumnSeo on Column {
  /// Mirrors this column as a container element on web.
  ///
  /// ```dart
  /// Column(children: [...]).seo();
  /// // → <div>...</div>
  /// Column(children: [...]).seo(SeoContainerTag.section);
  /// // → <section>...</section>  (Kurzform: .section)
  /// Column(children: [...]).seo(SeoContainerTag.section, {'id': 'preise'});
  /// // → <section id="preise">...</section>
  /// ```
  ///
  /// The IDE autocompletes all common container tags on [SeoContainerTag];
  /// exotic tags stay possible via `SeoContainerTag('my-widget')`.
  /// [attributes] adds HTML attributes like `id` or `lang` — event
  /// handlers and executable URLs are dropped by the attribute policy.
  ///
  /// All `.seo()` widgets inside the column become its HTML children.
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
      attributes: attributes,
      child: this,
    );
  }
}
