import 'package:flutter/widgets.dart';

import '../components/seo_responsive_image.dart';
import '../renderer/seo_node.dart';
import 'seo_block.dart';

/// A native Flutter image backed by a semantic HTML `<picture>` definition.
///
/// The fallback [src] and [candidates] drive both presentations. Flutter picks
/// the smallest valid fallback variant that covers the actual layout width at
/// the current device-pixel ratio. HTML emits those variants as `img[srcset]`
/// and adds [sources] as alternate AVIF/WebP encodings.
///
/// Alternate encodings must depict the same image. This component deliberately
/// does not accept media queries or art-directed content because Flutter could
/// not derive the same presentation from that input.
class SeoResponsiveImage extends SeoBlock {
  const SeoResponsiveImage({
    super.key,
    required this.src,
    required this.alt,
    required this.width,
    required this.height,
    this.candidates = const [],
    this.sources = const [],
    this.sizes = '100vw',
    this.loading = SeoResponsiveImageLoading.automatic,
    this.fetchPriority = SeoResponsiveImageFetchPriority.automatic,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
  });

  /// Ordinary fallback URL and the variant represented by [width].
  final String src;

  /// Alternative text. An explicit empty string marks a decorative image.
  final String alt;

  /// Intrinsic fallback width used for `width`, `srcset` and aspect ratio.
  final int width;

  /// Intrinsic fallback height used for `height` and aspect ratio.
  final int height;

  /// Additional fallback-encoding width variants.
  final List<SeoResponsiveImageCandidate> candidates;

  /// Alternate AVIF/WebP encodings of the same visual content.
  final List<SeoResponsiveImageSource> sources;

  /// HTML `sizes` hint. Flutter uses its measured layout width instead.
  final String sizes;

  /// Browser loading hint. Native Flutter loading follows widget visibility.
  final SeoResponsiveImageLoading loading;

  /// Browser fetch-priority hint; it has no native scheduling equivalent.
  final SeoResponsiveImageFetchPriority fetchPriority;

  /// How the selected Flutter image fills its aspect-ratio box.
  final BoxFit fit;

  /// Alignment of the selected Flutter image inside its box.
  final AlignmentGeometry alignment;

  @override
  Widget buildFlutter(BuildContext context) {
    final fallbackSrc = normalizeSeoResponsiveImageFallbackUrl(src);
    if (fallbackSrc == null) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final media = MediaQuery.maybeOf(context);
        final validDimensions = width > 0 &&
            width <= seoResponsiveImageMaxDimension &&
            height > 0 &&
            height <= seoResponsiveImageMaxDimension;
        final logicalWidth = _logicalImageWidth(
          constraints: constraints,
          media: media,
          width: width,
          height: height,
          validDimensions: validDimensions,
        );
        final rawRatio = media?.devicePixelRatio ?? 1;
        final pixelRatio = rawRatio.isFinite && rawRatio > 0 ? rawRatio : 1;
        final canonical = canonicalSeoResponsiveImageCandidates(
          candidates,
          fallback: width > 0 && width <= seoResponsiveImageMaxDimension
              ? SeoResponsiveImageCandidate(src: fallbackSrc, width: width)
              : null,
        );
        final selected = selectSeoResponsiveImageCandidate(
          canonical,
          logicalWidth * pixelRatio,
        );
        final image = Image.network(
          selected?.src ?? fallbackSrc,
          fit: fit,
          alignment: alignment,
          semanticLabel: alt.isEmpty ? null : alt,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        );
        if (!validDimensions) return image;
        final ratio = width / height;
        if (constraints.hasBoundedWidth || constraints.hasBoundedHeight) {
          return AspectRatio(aspectRatio: ratio, child: image);
        }
        return SizedBox(
          width: width.toDouble(),
          height: height.toDouble(),
          child: image,
        );
      },
    );
  }

  @override
  List<SeoNode> toSeoNodes() => buildSeoResponsiveImageNodes(
        src: src,
        alt: alt,
        width: width,
        height: height,
        candidates: candidates,
        sources: sources,
        sizes: sizes,
        loading: loading,
        fetchPriority: fetchPriority,
      );
}

double _logicalImageWidth({
  required BoxConstraints constraints,
  required MediaQueryData? media,
  required int width,
  required int height,
  required bool validDimensions,
}) {
  if (constraints.maxWidth.isFinite) {
    return constraints.maxWidth.clamp(0.0, double.maxFinite).toDouble();
  }
  if (validDimensions && constraints.maxHeight.isFinite) {
    return constraints.maxHeight.clamp(0.0, double.maxFinite).toDouble() *
        width /
        height;
  }
  final mediaWidth = media?.size.width;
  if (mediaWidth != null && mediaWidth.isFinite && mediaWidth > 0) {
    return mediaWidth;
  }
  return validDimensions ? width.toDouble() : 0;
}
