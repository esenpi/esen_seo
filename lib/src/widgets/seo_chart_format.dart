/// Shared CSS formatting for the SEO widget library — one place for
/// number, percent and color output so every widget mirrors the same
/// way. Internal; not exported.
library;

import 'dart:ui';

/// Compact number formatting: `54` instead of `54.0`.
String cssNumber(double value) => value == value.roundToDouble()
    ? value.round().toString()
    : value.toString();

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
