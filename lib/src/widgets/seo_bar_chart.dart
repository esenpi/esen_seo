import 'package:flutter/widgets.dart';

import '../components/seo_components.dart';
import '../renderer/seo_node.dart';
import 'seo_block.dart';
import 'seo_chart_format.dart';

/// One bar of a [SeoBarChart].
class SeoBarChartEntry {
  const SeoBarChartEntry(this.label, this.value);

  /// The category label shown under the bar, e.g. `2026`.
  final String label;

  /// The bar's value. Must be `>= 0`.
  final double value;
}

/// A bar chart that mirrors itself as real HTML.
///
/// Ordinary chart packages paint onto a canvas — for crawlers (and for
/// the visible shell) the result is a meaningless bitmap. This chart
/// knows its **data**, so it can exist twice: on every platform it
/// renders as normal Flutter widgets, and on the web its data is
/// additionally translated into the semantic mirror as CSS bars plus a
/// real `<table>` — content search engines can actually read.
///
/// ```dart
/// SeoBarChart(
///   title: 'Umsatz pro Jahr',
///   data: [
///     SeoBarChartEntry('2024', 12),
///     SeoBarChartEntry('2025', 31),
///     SeoBarChartEntry('2026', 54),
///   ],
/// )
/// ```
///
/// This is the pattern for anything that cannot be mirrored directly:
/// don't translate the pixels, translate the data they were painted
/// from. For one-off cases, `.seoNodes()` does the same by hand.
class SeoBarChart extends SeoBlock {
  const SeoBarChart({
    super.key,
    required this.data,
    this.title,
    this.height = 220,
    this.color = const Color(0xFF2563EB),
    this.labelStyle,
  });

  /// The bars, in display order.
  final List<SeoBarChartEntry> data;

  /// Optional caption — rendered above the chart and as the HTML
  /// `<figcaption>`/`<caption>`.
  final String? title;

  /// Total height of the bar area in logical pixels (and CSS pixels).
  final double height;

  /// Bar color, used for the Flutter bars and the CSS bars alike.
  final Color color;

  /// Style of the labels under the bars.
  final TextStyle? labelStyle;

  double _valueOf(SeoBarChartEntry entry) => safeChartValue(entry.value);

  /// A NaN or infinite height would break Flutter's layout invariants
  /// and leak `NaNpx` into the mirrored CSS.
  double get _height => safeDimension(height, 220);

  double get _maxValue {
    var max = 0.0;
    for (final entry in data) {
      final value = _valueOf(entry);
      if (value > max) max = value;
    }
    return max;
  }

  @override
  Widget buildFlutter(BuildContext context) {
    final max = _maxValue;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              title!,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        SizedBox(
          height: _height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final entry in data)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: FractionallySizedBox(
                              heightFactor: max <= 0
                                  ? 0
                                  : (_valueOf(entry) / max).clamp(0.0, 1.0),
                              child: Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(3),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(entry.label,
                            style: labelStyle ?? const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// The HTML translation: CSS bars for the eye (visible shell),
  /// a real table for crawlers and screen readers.
  @override
  List<SeoNode> toSeoNodes() => buildSeoBarChartNodes(
        data: [
          for (final entry in data) (label: entry.label, value: entry.value),
        ],
        title: title,
        height: height,
        colorArgb: flutterColorArgb(color),
      );
}
