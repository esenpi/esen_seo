import 'package:flutter/widgets.dart';

import '../extensions/widget_seo.dart';
import '../renderer/seo_node.dart';

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
class SeoBarChart extends StatelessWidget {
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

  double get _maxValue {
    var max = 0.0;
    for (final entry in data) {
      if (entry.value > max) max = entry.value;
    }
    return max;
  }

  @override
  Widget build(BuildContext context) {
    return _buildChart(context).seoNodes(_toNodes());
  }

  Widget _buildChart(BuildContext context) {
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
          height: height,
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
                                  : (entry.value / max).clamp(0.0, 1.0),
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
  List<SeoNode> _toNodes() {
    final max = _maxValue;
    return [
      SeoNode(
        tag: 'figure',
        attributes: {'class': 'esen-seo-bar-chart'},
        children: [
          if (title != null) SeoNode(tag: 'figcaption', text: title),
          // Die Balken sind reine Optik — die Tabelle darunter trägt die
          // Semantik, deshalb bleiben sie für Screenreader unsichtbar.
          SeoNode(
            tag: 'div',
            attributes: {
              'aria-hidden': 'true',
              'style': 'display:flex;align-items:flex-end;gap:8px;'
                  'height:${_css(height)}px',
            },
            children: [
              for (final entry in data)
                SeoNode(
                  tag: 'div',
                  attributes: {
                    'title': '${entry.label}: ${_css(entry.value)}',
                    'style': 'flex:1;border-radius:3px 3px 0 0;'
                        'background:${_cssColor(color)};'
                        'height:${_percent(entry.value, max)}%',
                  },
                ),
            ],
          ),
          SeoNode(tag: 'table', children: [
            if (title != null) SeoNode(tag: 'caption', text: title),
            SeoNode(tag: 'tbody', children: [
              for (final entry in data)
                SeoNode(tag: 'tr', children: [
                  SeoNode(tag: 'th', text: entry.label),
                  SeoNode(tag: 'td', text: _css(entry.value)),
                ]),
            ]),
          ]),
        ],
      ),
    ];
  }

  static String _percent(double value, double max) {
    if (max <= 0) return '0';
    final fixed = (value / max * 100).clamp(0, 100).toStringAsFixed(1);
    return fixed.endsWith('.0') ? fixed.substring(0, fixed.length - 2) : fixed;
  }

  /// Compact number formatting: `54` instead of `54.0`.
  static String _css(double value) => value == value.roundToDouble()
      ? value.round().toString()
      : value.toString();

  static String _cssColor(Color color) {
    String hex(double channel) => ((channel * 255).round().clamp(0, 255))
        .toRadixString(16)
        .padLeft(2, '0');
    return '#${hex(color.r)}${hex(color.g)}${hex(color.b)}';
  }
}
