/// Shared CSS formatting for the SEO widget library — one place for
/// number, percent and color output so every widget mirrors the same
/// way. Internal; not exported.
library;

import 'dart:ui';

/// Normalizes chart input data: NaN, infinity and negative values
/// become `0`. Data often arrives unchecked from databases or
/// calculations (`0/0` → NaN) — it must neither crash the Flutter
/// layout nor leak `NaN` into the mirrored HTML.
double safeChartValue(double value) => value.isFinite && value > 0 ? value : 0;

/// Normalizes a CSS dimension (heights, diameters): NaN, infinity and
/// non-positive values fall back to [fallback]. A NaN size does not
/// just produce `NaNpx` in the mirror, it violates Flutter's layout
/// invariants and throws.
double safeDimension(double value, double fallback) =>
    value.isFinite && value > 0 ? value : fallback;

/// Beyond 2^53 a double no longer represents consecutive integers, and
/// `round()` saturates to the int64 maximum — printing an outright
/// wrong number. Above this bound the plain double form is used.
const double _maxExactInteger = 9007199254740992; // 2^53

/// Compact number formatting: `54` instead of `54.0`.
String cssNumber(double value) {
  if (!value.isFinite) return '0';
  if (value == value.roundToDouble() && value.abs() < _maxExactInteger) {
    return value.round().toString();
  }
  // Jenseits von 2^53 bleibt nur die double-Form — ohne das ".0",
  // das in einer Tabellenzelle nur stört.
  final text = value.toString();
  return text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
}

/// A share of [total] as a percent string with at most one decimal:
/// `22.2`, `100`. `0` when [total] is not positive.
String cssPercent(double value, double total) {
  if (total <= 0) return '0';
  final fixed = (value / total * 100).clamp(0, 100).toStringAsFixed(1);
  return fixed.endsWith('.0') ? fixed.substring(0, fixed.length - 2) : fixed;
}

/// A [Color] as a CSS hex value, e.g. `#2563eb`.
String cssColor(Color color) {
  String hex(double channel) =>
      ((channel * 255).round().clamp(0, 255)).toRadixString(16).padLeft(2, '0');
  return '#${hex(color.r)}${hex(color.g)}${hex(color.b)}';
}
