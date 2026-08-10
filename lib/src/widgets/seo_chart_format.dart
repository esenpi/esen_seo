/// Flutter color adapter for the pure component formatting helpers.
library;

import 'dart:ui';

import '../components/seo_component_format.dart';

export '../components/seo_component_format.dart'
    show cssNumber, cssPercent, safeChartValue, safeDimension;

/// Converts a Flutter [Color] to the ARGB integer accepted by pure builders.
int flutterColorArgb(Color color) {
  int channel(double value) =>
      ((value * 255).round().clamp(0, 255) as num).toInt();
  return channel(color.a) << 24 |
      channel(color.r) << 16 |
      channel(color.g) << 8 |
      channel(color.b);
}

/// A [Color] as a CSS hex value, e.g. `#2563eb`.
String cssColor(Color color) => cssColorArgb(flutterColorArgb(color));
