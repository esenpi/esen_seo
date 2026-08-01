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

  /// The scale, normalized so degenerate input (`max: 0`, negative)
  /// can never throw — the page must render no matter what.
  int get _scale => max < 1 ? 1 : max;

  /// The score with NaN/infinity/negatives normalized to `0`.
  double get _value => value.isFinite && value > 0 ? value : 0;

  /// Beyond this many stars the symbols stop being readable — and a
  /// wrong `max` (say a million) would allocate a giant string. Past
  /// the limit only the exact score is shown, which stays correct.
  static const int _maxStars = 20;

  /// Filled stars: full stars for the integer part; the exact score is
  /// always carried as text, so nothing is overstated.
  int get _filled => _value.clamp(0, _scale.toDouble()).floor();

  String get _stars =>
      _scale > _maxStars ? '' : '★' * _filled + '☆' * (_scale - _filled);

  String get _score => '${cssNumber(_value)}/$_scale';

  /// Stars (when the scale allows them) plus the exact score and the
  /// optional context — the same information the widget shows.
  String get _mirrorText {
    final scored = label == null ? _score : '$_score ($label)';
    return _stars.isEmpty ? scored : '$_stars $scored';
  }

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
      // Kein aria-label: Für <p> ist ein ARIA-Name laut Spezifikation
      // verboten (Rolle „paragraph" ist name-prohibited) — der Text
      // trägt den Wert ohnehin vollständig.
      SeoNode(
        tag: 'p',
        attributes: const {'class': 'esen-seo-rating'},
        text: _mirrorText,
      ),
    ]);
  }
}
