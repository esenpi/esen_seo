import 'package:flutter/widgets.dart';

import '../controller/seo_controller.dart';
import '../renderer/image_source.dart';
import '../widgets/seo_widget.dart';

/// Adds `.seo()` to [Image].
extension ImageSeo on Image {
  /// Mirrors this image as an `<img>` element on web.
  ///
  /// ```dart
  /// Image.network('https://esen.software/foto.png').seo(alt: 'Ein Foto');
  /// // → <img src="https://esen.software/foto.png" alt="Ein Foto"/>
  /// Image.network(url).seo(alt: 'Foto', width: 800, height: 400, lazy: true);
  /// // → <img src="..." alt="Foto" width="800" height="400" loading="lazy"/>
  /// ```
  ///
  /// The `src` is read from the image provider (network URL or asset path)
  /// and can be overridden with [src]. When [alt] is omitted the widget's
  /// [Image.semanticLabel] is used; when [width]/[height] are omitted the
  /// widget's own dimensions are used if set. Explicit image dimensions
  /// let crawlers reserve layout space (Core Web Vitals: CLS), [lazy]
  /// adds `loading="lazy"`. [attributes] adds anything else, filtered by
  /// the attribute policy.
  ///
  /// On non-web platforms the original widget is returned unchanged.
  Widget seo({
    String? alt,
    String? src,
    int? width,
    int? height,
    bool lazy = false,
    Map<String, String> attributes = const {},
  }) {
    if (!SeoController.enabled) return this;
    final imgWidth = width ?? this.width?.round();
    final imgHeight = height ?? this.height?.round();
    return SeoWidget(
      type: SeoElementType.image,
      tag: 'img',
      attributes: {
        'src': src ?? seoImageSource(image),
        'alt': alt ?? semanticLabel ?? '',
        if (imgWidth != null) 'width': '$imgWidth',
        if (imgHeight != null) 'height': '$imgHeight',
        if (lazy) 'loading': 'lazy',
        ...attributes,
      },
      child: this,
    );
  }
}
