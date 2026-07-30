import 'package:flutter/widgets.dart';

import '../controller/seo_controller.dart';
import '../tags/seo_tags.dart';
import '../widgets/seo_widget.dart';

/// Adds `.seo()` to [Text].
extension TextSeo on Text {
  /// Mirrors this text as a semantic HTML element on web.
  ///
  /// ```dart
  /// Text('Willkommen').seo(SeoTextTag.h1); // → <h1>Willkommen</h1>
  /// Text('Willkommen').h1;                 // Kurzform, gleiche Wirkung
  /// Text('12. Juli').seo(SeoTextTag.time, {'datetime': '2026-07-12'});
  /// // → <time datetime="2026-07-12">12. Juli</time>
  /// ```
  ///
  /// The IDE autocompletes all common text tags on [SeoTextTag]; exotic
  /// tags stay possible via `SeoTextTag('bdo')`. [attributes] adds HTML
  /// attributes like `id`, `lang`, `datetime` or `cite` — event handlers
  /// (`onclick` …) and executable URLs are dropped by the attribute
  /// policy.
  ///
  /// Without [tag] the smart-defaults system decides: the first text on the
  /// page becomes `<h1>`, every following one `<p>`.
  ///
  /// On non-web platforms the original widget is returned unchanged.
  Widget seo([SeoTextTag? tag, Map<String, String> attributes = const {}]) {
    if (!SeoController.enabled) return this;
    return SeoWidget(
      type: SeoElementType.text,
      tag: tag?.name,
      content: data ?? textSpan?.toPlainText() ?? '',
      attributes: attributes,
      child: this,
    );
  }
}
