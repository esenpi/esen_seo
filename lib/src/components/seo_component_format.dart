/// Shared formatting used by the pure SEO component builders.
library;

/// Normalizes chart input data so invalid and negative values become zero.
double safeChartValue(double value) => value.isFinite && value > 0 ? value : 0;

/// Normalizes a positive dimension, falling back for invalid input.
double safeDimension(double value, double fallback) =>
    value.isFinite && value > 0 ? value : fallback;

// Beyond 2^53 a double no longer represents consecutive integers.
const double _maxExactInteger = 9007199254740992;

/// Formats a finite CSS number without an unnecessary decimal suffix.
String cssNumber(double value) {
  if (!value.isFinite) return '0';
  if (value == value.roundToDouble() && value.abs() < _maxExactInteger) {
    return value.round().toString();
  }
  final text = value.toString();
  return text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
}

/// Formats [value]'s share of [total] as a percentage with one decimal at most.
String cssPercent(double value, double total) {
  if (total <= 0) return '0';
  final fixed = (value / total * 100).clamp(0, 100).toStringAsFixed(1);
  return fixed.endsWith('.0') ? fixed.substring(0, fixed.length - 2) : fixed;
}

/// Formats an ARGB integer as CSS `#rrggbb`, intentionally ignoring alpha.
///
/// Alpha remains ignored for compatibility with the widget output before the
/// pure component layer was introduced.
String cssColorArgb(int argb) =>
    '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
