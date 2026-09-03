import '../renderer/seo_node.dart';
import '../renderer/tag_policy.dart';

/// Maximum number of width variants admitted for one image encoding.
const int seoResponsiveImageMaxCandidates = 16;

/// Maximum number of alternate encodings admitted for one picture.
const int seoResponsiveImageMaxSources = 2;

/// Largest useful intrinsic dimension accepted by the image model.
const int seoResponsiveImageMaxDimension = 100000;

/// Alternate encodings that may precede the fallback image in `<picture>`.
///
/// Sources are alternate encodings of the same visual content. Art direction
/// is deliberately outside this model, so Flutter and HTML keep the same image
/// meaning at every viewport size.
enum SeoResponsiveImageFormat {
  avif('image/avif'),
  webp('image/webp');

  const SeoResponsiveImageFormat(this.mimeType);

  /// MIME type emitted on the HTML `<source>` element.
  final String mimeType;
}

/// Browser loading behavior for a responsive image.
enum SeoResponsiveImageLoading {
  /// Leaves the `loading` attribute unset.
  automatic(null),

  /// Hints that the browser should load the image immediately.
  eager('eager'),

  /// Hints that an off-screen image may be deferred.
  lazy('lazy');

  const SeoResponsiveImageLoading(this.htmlValue);

  /// Attribute value, or `null` when the browser default should apply.
  final String? htmlValue;
}

/// Browser fetch-priority hint for a responsive image.
enum SeoResponsiveImageFetchPriority {
  /// Leaves the `fetchpriority` attribute unset.
  automatic(null),

  /// Raises the priority, commonly for the page's largest contentful image.
  high('high'),

  /// Lowers the priority for non-critical imagery.
  low('low');

  const SeoResponsiveImageFetchPriority(this.htmlValue);

  /// Attribute value, or `null` when the browser default should apply.
  final String? htmlValue;
}

/// One URL with its intrinsic pixel width.
final class SeoResponsiveImageCandidate {
  const SeoResponsiveImageCandidate({required this.src, required this.width});

  /// Image URL. Whitespace and commas must be percent-encoded for `srcset`.
  final String src;

  /// Intrinsic width represented by [src].
  final int width;
}

/// One alternate image encoding and its width variants.
final class SeoResponsiveImageSource {
  const SeoResponsiveImageSource({
    required this.format,
    required this.candidates,
  });

  /// Encoding advertised through the `<source type>` attribute.
  final SeoResponsiveImageFormat format;

  /// Width variants for this encoding.
  final List<SeoResponsiveImageCandidate> candidates;
}

/// Builds a semantic HTML responsive image from one bounded pure definition.
///
/// [src] is both the ordinary fallback and, when [width] is valid, a member of
/// the fallback `srcset`. Invalid optional candidates are omitted individually;
/// they can never make the required fallback disappear.
List<SeoNode> buildSeoResponsiveImageNodes({
  required String src,
  required String alt,
  required int width,
  required int height,
  List<SeoResponsiveImageCandidate> candidates = const [],
  List<SeoResponsiveImageSource> sources = const [],
  String sizes = '100vw',
  SeoResponsiveImageLoading loading = SeoResponsiveImageLoading.automatic,
  SeoResponsiveImageFetchPriority fetchPriority =
      SeoResponsiveImageFetchPriority.automatic,
}) {
  final fallbackSrc = normalizeSeoResponsiveImageFallbackUrl(src);
  final normalizedWidth = _validImageWidth(width) ? width : null;
  final normalizedHeight = _validImageWidth(height) ? height : null;
  final fallbackCandidates = canonicalSeoResponsiveImageCandidates(
    candidates,
    fallback: fallbackSrc == null || normalizedWidth == null
        ? null
        : SeoResponsiveImageCandidate(
            src: fallbackSrc,
            width: normalizedWidth,
          ),
  );
  final normalizedSizes = normalizeSeoResponsiveImageSizes(sizes);
  final normalizedSources = _canonicalSources(sources);
  final hasFallbackSrcset = fallbackCandidates.length > 1;

  return [
    SeoNode(
      tag: 'picture',
      attributes: const {'class': 'esen-seo-responsive-image'},
      children: [
        for (final source in normalizedSources)
          SeoNode(
            tag: 'source',
            attributes: {
              'type': source.format.mimeType,
              'srcset': _srcset(source.candidates),
              'sizes': normalizedSizes,
            },
          ),
        SeoNode(
          tag: 'img',
          attributes: {
            if (fallbackSrc != null) 'src': fallbackSrc,
            if (hasFallbackSrcset) ...{
              'srcset': _srcset(fallbackCandidates),
              'sizes': normalizedSizes,
            },
            // An explicit empty alt means decorative; omission means unknown.
            'alt': alt,
            if (normalizedWidth != null) 'width': '$normalizedWidth',
            if (normalizedHeight != null) 'height': '$normalizedHeight',
            if (loading.htmlValue case final value?) 'loading': value,
            if (fetchPriority.htmlValue case final value?)
              'fetchpriority': value,
          },
        ),
      ],
    ),
  ];
}

/// Returns canonical width variants, optionally including [fallback].
///
/// The first valid candidate for a width wins. Results are sorted by width so
/// both the HTML serializer and Flutter selection are deterministic.
List<SeoResponsiveImageCandidate> canonicalSeoResponsiveImageCandidates(
  List<SeoResponsiveImageCandidate> candidates, {
  SeoResponsiveImageCandidate? fallback,
}) {
  final byWidth = <int, SeoResponsiveImageCandidate>{};

  void admit(SeoResponsiveImageCandidate candidate) {
    if (byWidth.length >= seoResponsiveImageMaxCandidates) return;
    final src = _normalizeSrcsetUrl(candidate.src);
    if (src == null || !_validImageWidth(candidate.width)) return;
    byWidth.putIfAbsent(
      candidate.width,
      () => SeoResponsiveImageCandidate(src: src, width: candidate.width),
    );
  }

  if (fallback != null) admit(fallback);
  var inspected = 0;
  for (final candidate in candidates) {
    if (inspected >= seoResponsiveImageMaxCandidates) break;
    inspected++;
    admit(candidate);
  }

  final result = byWidth.values.toList()
    ..sort((left, right) => left.width.compareTo(right.width));
  return List.unmodifiable(result);
}

/// Selects the smallest candidate that covers [targetPhysicalWidth].
///
/// A non-finite or non-positive target selects the smallest variant. A target
/// above every candidate selects the largest one.
SeoResponsiveImageCandidate? selectSeoResponsiveImageCandidate(
  List<SeoResponsiveImageCandidate> candidates,
  double targetPhysicalWidth,
) {
  final canonical = canonicalSeoResponsiveImageCandidates(candidates);
  if (canonical.isEmpty) return null;
  final target = targetPhysicalWidth.isFinite && targetPhysicalWidth > 0
      ? targetPhysicalWidth
      : 0;
  for (final candidate in canonical) {
    if (candidate.width >= target) return candidate;
  }
  return canonical.last;
}

/// Normalizes a bounded `sizes` value without interpreting CSS media syntax.
String normalizeSeoResponsiveImageSizes(String sizes) {
  final value = sizes.trim();
  if (value.isEmpty ||
      value.length > 512 ||
      _unsafeSizesCharacters.hasMatch(value)) {
    return '100vw';
  }
  return value;
}

/// Returns a safe, trimmed ordinary image URL or `null`.
///
/// This helper is kept outside the public barrel API; the Flutter widget uses
/// it so a fallback refused by the HTML policy is not selected natively either.
String? normalizeSeoResponsiveImageFallbackUrl(String src) {
  final value = src.trim();
  final uri = Uri.tryParse(value);
  if (value.isEmpty ||
      value.length > 4096 ||
      uri == null ||
      (uri.hasScheme && uri.scheme != 'http' && uri.scheme != 'https') ||
      !isAllowedSeoAttribute('src', value)) {
    return null;
  }
  return value;
}

List<SeoResponsiveImageSource> _canonicalSources(
  List<SeoResponsiveImageSource> sources,
) {
  final byFormat = <SeoResponsiveImageFormat, SeoResponsiveImageSource>{};
  var inspected = 0;
  for (final source in sources) {
    if (inspected >= seoResponsiveImageMaxSources) break;
    inspected++;
    if (byFormat.containsKey(source.format)) continue;
    final candidates = canonicalSeoResponsiveImageCandidates(
      source.candidates,
    );
    if (candidates.isEmpty) continue;
    byFormat[source.format] = SeoResponsiveImageSource(
      format: source.format,
      candidates: candidates,
    );
  }
  return [
    for (final format in SeoResponsiveImageFormat.values)
      if (byFormat[format] case final source?) source,
  ];
}

String _srcset(List<SeoResponsiveImageCandidate> candidates) => candidates
    .map((candidate) => '${candidate.src} ${candidate.width}w')
    .join(', ');

bool _validImageWidth(int value) =>
    value > 0 && value <= seoResponsiveImageMaxDimension;

String? _normalizeSrcsetUrl(String src) {
  final value = normalizeSeoResponsiveImageFallbackUrl(src);
  if (value == null || _srcsetSeparators.hasMatch(value)) return null;
  return value;
}

final RegExp _srcsetSeparators = RegExp(
  r'''[\s,"'\\<>\u061c\u200e\u200f\u202a-\u202e\u2066-\u2069]''',
);
final RegExp _unsafeSizesCharacters = RegExp(
  r'[\x00-\x1f\x7f\u061c\u200e\u200f\u202a-\u202e\u2066-\u2069<>"\x27\\]',
);
