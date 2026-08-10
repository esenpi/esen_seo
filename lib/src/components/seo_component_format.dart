/// Shared formatting used by the pure SEO component builders.
library;

final RegExp _seoInteractionId = RegExp(r'^[A-Za-z][A-Za-z0-9_-]{0,127}$');

/// Whether [value] is safe to use as a package interaction identifier.
///
/// The closed ASCII form is valid in HTML ids and can be extended with fixed
/// package-owned suffixes without turning application data into a selector.
bool isValidSeoInteractionId(String value) => _seoInteractionId.hasMatch(value);

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

/// Formats an ARGB integer as lowercase CSS hexadecimal.
///
/// Opaque colors use `#rrggbb`; colors carrying alpha use `#rrggbbaa`,
/// following CSS ordering rather than the input integer's ARGB ordering.
String cssColorArgb(int argb) {
  final rgb = (argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0');
  final alpha = (argb >> 24) & 0xFF;
  return alpha == 0xFF
      ? '#$rgb'
      : '#$rgb${alpha.toRadixString(16).padLeft(2, '0')}';
}
