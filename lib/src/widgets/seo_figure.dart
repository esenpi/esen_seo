import 'package:flutter/widgets.dart';

import '../renderer/seo_node.dart';
import 'seo_block.dart';

/// An image with a caption that mirrors itself as real HTML.
///
/// `Image.seo(alt: …)` already covers a bare image; a figure adds the
/// **caption** and the `<figure>`/`<figcaption>` relationship, which is
/// what ties descriptive text to an image for search engines and screen
/// readers alike.
///
/// ```dart
/// SeoFigure(
///   src: 'https://esen.software/team.jpg',
///   alt: 'Das Team vor dem Büro in München',
///   caption: 'Unser Team, Sommer 2026',
///   width: 1200,
///   height: 800,
/// )
/// ```
///
/// Always pass [alt] — it is what image search reads. Give [width] and
/// [height] whenever you know them: the browser reserves the space
/// before the image arrives, which is what keeps the layout from
/// jumping (Core Web Vitals: CLS). [lazy] defaults to `false`, because
/// deferring an image above the fold delays the largest paint.
class SeoFigure extends SeoBlock {
  const SeoFigure({
    super.key,
    required this.src,
    required this.alt,
    this.caption,
    this.width,
    this.height,
    this.lazy = false,
    this.captionStyle,
    this.fit = BoxFit.cover,
  });

  /// The image URL.
  final String src;

  /// Alternative text — describes the image where it cannot be seen.
  final String alt;

  /// The visible caption below the image.
  final String? caption;

  /// Intrinsic image width in pixels.
  final int? width;

  /// Intrinsic image height in pixels.
  final int? height;

  /// Adds `loading="lazy"`. Leave it off for images above the fold.
  final bool lazy;

  /// Style of the caption text.
  final TextStyle? captionStyle;

  /// How the Flutter image fills its box.
  final BoxFit fit;

  /// Only positive, finite dimensions are worth emitting — anything
  /// else would make the browser reserve nonsense.
  int? get _width => (width != null && width! > 0) ? width : null;
  int? get _height => (height != null && height! > 0) ? height : null;

  @override
  Widget buildFlutter(BuildContext context) {
    // [width]/[height] beschreiben das Quellbild fürs HTML — als feste
    // Flutter-Größe würden sie auf schmalen Schirmen überlaufen. Sind
    // beide bekannt, reservieren wir stattdessen das Seitenverhältnis:
    // dieselbe Wirkung wie die HTML-Attribute, nur responsiv.
    Widget image = Image.network(
      src,
      fit: fit,
      semanticLabel: alt.isEmpty ? null : alt,
      // Ein fehlendes Bild darf die Seite nicht zerlegen.
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
    );
    if (_width != null && _height != null) {
      image = AspectRatio(aspectRatio: _width! / _height!, child: image);
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        image,
        if (caption != null && caption!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              caption!,
              style: captionStyle ??
                  const TextStyle(fontSize: 13, color: Color(0xFF4A4A4A)),
            ),
          ),
      ],
    );
  }

  @override
  List<SeoNode> toSeoNodes() => [
        SeoNode(
          tag: 'figure',
          attributes: const {'class': 'esen-seo-figure'},
          children: [
            SeoNode(tag: 'img', attributes: {
              'src': src,
              // Immer setzen: ein fehlendes alt ist etwas anderes als
              // ein bewusst leeres (dekoratives Bild).
              'alt': alt,
              if (_width != null) 'width': '$_width',
              if (_height != null) 'height': '$_height',
              if (lazy) 'loading': 'lazy',
            }),
            if (caption != null && caption!.isNotEmpty)
              SeoNode(tag: 'figcaption', text: caption),
          ],
        ),
      ];
}
