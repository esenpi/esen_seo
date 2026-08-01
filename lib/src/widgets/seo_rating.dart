import 'package:flutter/widgets.dart';

import '../extensions/widget_seo.dart';
import '../renderer/seo_node.dart';
import 'seo_chart_format.dart';

/// A star rating that mirrors itself as readable HTML.
///
/// Painted rating stars are invisible to crawlers. This widget renders
/// stars as Flutter text on every platform and mirrors the **value** on
/// the web — stars plus the exact score as plain text:
///
/// ```dart
/// SeoRating(value: 4.5, label: '128 Bewertungen')
/// // → <p class="esen-seo-rating" aria-label="Rated 4.5 out of 5">
/// //     ★★★★☆ 4.5/5 (128 Bewertungen)</p>
/// ```
///
/// For rating **stars in Google results**, additionally declare the
/// value as structured data — `SeoSchema.product(ratingValue: …)` or
/// `SeoSchema.review(rating: …)` via `SeoMeta.schemas`; this widget
/// covers the on-page content.
class SeoRating extends StatelessWidget {
  const SeoRating({
    super.key,
    required this.value,
    this.max = 5,
    this.label,
    this.color = const Color(0xFFF59E0B),
    this.size = 18,
  });

  /// The score, e.g. `4.5`.
  final double value;

  /// The scale's maximum, e.g. `5`.
  final int max;

  /// Optional context shown after the score, e.g. `128 Bewertungen`.
  final String? label;

  /// Star color.
  final Color color;

  /// Star font size in logical pixels.
  final double size;

  /// Filled stars: full stars for the integer part; the exact score is
  /// always carried as text, so nothing is overstated.
  int get _filled => value.clamp(0, max.toDouble()).floor();

  String get _stars => '★' * _filled + '☆' * (max - _filled);

  String get _score => '${cssNumber(value)}/$max';

  @override
  Widget build(BuildContext context) {
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _stars,
          style: TextStyle(color: color, fontSize: size),
        ),
        const SizedBox(width: 6),
        Text(
          label == null ? _score : '$_score ($label)',
          style: TextStyle(fontSize: size * 0.75),
        ),
      ],
    );
    return row.seoNodes([
      SeoNode(
        tag: 'p',
        attributes: {
          'class': 'esen-seo-rating',
          'aria-label': 'Rated ${cssNumber(value)} out of $max',
        },
        text: label == null ? '$_stars $_score' : '$_stars $_score ($label)',
      ),
    ]);
  }
}
