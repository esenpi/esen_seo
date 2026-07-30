import 'package:flutter/widgets.dart';

import '../controller/seo_controller.dart';
import '../widgets/seo_widget.dart';

/// Adds `.seo()` to [GestureDetector].
extension LinkSeo on GestureDetector {
  /// Mirrors this tappable widget as an `<a>` element on web.
  ///
  /// ```dart
  /// GestureDetector(
  ///   onTap: () => context.go('/about'),
  ///   child: Text('Über uns'),
  /// ).seo(href: '/about');
  /// // → <a href="/about">Über uns</a>
  /// ```
  ///
  /// Untagged texts inside the detector become the plain anchor label;
  /// tagged children keep their own elements.
  ///
  /// [rel] (e.g. `nofollow`, `noopener`) and [hreflang] (e.g. `de`) map
  /// to the corresponding anchor attributes; [attributes] adds anything
  /// else, filtered by the attribute policy.
  ///
  /// On non-web platforms the original widget is returned unchanged.
  Widget seo({
    required String href,
    String? title,
    String? rel,
    String? hreflang,
    Map<String, String> attributes = const {},
  }) {
    if (!SeoController.enabled) return this;
    return SeoWidget(
      type: SeoElementType.link,
      tag: 'a',
      attributes: {
        'href': href,
        if (title != null) 'title': title,
        if (rel != null) 'rel': rel,
        if (hreflang != null) 'hreflang': hreflang,
        ...attributes,
      },
      child: this,
    );
  }
}
