import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../extensions/widget_seo.dart';
import '../renderer/seo_node.dart';
import 'seo_chart_format.dart';

/// One segment of a [SeoPieChart].
class SeoPieChartEntry {
  const SeoPieChartEntry(this.label, this.value, {this.color});

  /// The segment label, e.g. `Flutter`.
  final String label;

  /// The segment's value. Must be `>= 0`.
  final double value;

  /// Optional explicit color; defaults to the chart palette.
  final Color? color;
}

/// A pie chart that mirrors itself as real HTML.
///
/// Same principle as [SeoBarChart]: the chart knows its **data**, so it
/// exists twice — painted Flutter segments on every platform, and on
/// the web a pure-CSS pie (`conic-gradient`, no images, no JS) plus a
/// real `<table>` with labels, values and shares in the mirror.
///
/// ```dart
/// SeoPieChart(
///   title: 'Marktanteile',
///   data: [
///     SeoPieChartEntry('Flutter', 46),
///     SeoPieChartEntry('React Native', 32),
///     SeoPieChartEntry('Andere', 22),
///   ],
/// )
/// ```
class SeoPieChart extends StatelessWidget {
  const SeoPieChart({
    super.key,
    required this.data,
    this.title,
    this.diameter = 180,
    this.palette = defaultPalette,
    this.labelStyle,
  });

  /// The segments, in display order (clockwise from the top).
  final List<SeoPieChartEntry> data;

  /// Optional caption — rendered above the chart and as the HTML
  /// `<figcaption>`/`<caption>`.
  final String? title;

  /// Diameter of the pie in logical pixels (and CSS pixels).
  final double diameter;

  /// Colors used for segments without an explicit color, repeating
  /// when there are more segments than palette entries.
  final List<Color> palette;

  /// Style of the legend labels.
  final TextStyle? labelStyle;

  /// The default segment palette.
  static const List<Color> defaultPalette = [
    Color(0xFF2563EB),
    Color(0xFFF59E0B),
    Color(0xFF10B981),
    Color(0xFFEF4444),
    Color(0xFF8B5CF6),
    Color(0xFF64748B),
  ];

  double get _total {
    var total = 0.0;
    for (final entry in data) {
      total += entry.value;
    }
    return total;
  }

  Color _colorAt(int index) =>
      data[index].color ?? palette[index % palette.length];

  @override
  Widget build(BuildContext context) {
    return _buildChart(context).seoNodes(_toNodes());
  }

  Widget _buildChart(BuildContext context) {
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
        CustomPaint(
          size: Size.square(diameter),
          painter: _PiePainter(
            values: [for (final entry in data) entry.value],
            colors: [for (var i = 0; i < data.length; i++) _colorAt(i)],
          ),
        ),
        const SizedBox(height: 12),
        // Legende: Farbpunkt + Label + Wert pro Segment.
        Wrap(
          spacing: 16,
          runSpacing: 4,
          children: [
            for (var i = 0; i < data.length; i++)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: _colorAt(i),
                      shape: BoxShape.circle,
                    ),
                  ),
                  Text(
                    '${data[i].label} (${cssNumber(data[i].value)})',
                    style: labelStyle ?? const TextStyle(fontSize: 12),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }

  /// The HTML translation: a `conic-gradient` circle for the eye,
  /// a table with labels, values and shares for crawlers.
  List<SeoNode> _toNodes() {
    final total = _total;
    return [
      SeoNode(
        tag: 'figure',
        attributes: {'class': 'esen-seo-pie-chart'},
        children: [
          if (title != null) SeoNode(tag: 'figcaption', text: title),
          SeoNode(
            tag: 'div',
            attributes: {
              'aria-hidden': 'true',
              'style': 'width:${cssNumber(diameter)}px;'
                  'height:${cssNumber(diameter)}px;'
                  'border-radius:50%;'
                  'background:${_conicGradient(total)}',
            },
          ),
          SeoNode(tag: 'table', children: [
            if (title != null) SeoNode(tag: 'caption', text: title),
            SeoNode(tag: 'tbody', children: [
              for (final entry in data)
                SeoNode(tag: 'tr', children: [
                  SeoNode(tag: 'th', text: entry.label),
                  SeoNode(tag: 'td', text: cssNumber(entry.value)),
                  SeoNode(
                    tag: 'td',
                    text: '${cssPercent(entry.value, total)}%',
                  ),
                ]),
            ]),
          ]),
        ],
      ),
    ];
  }

  String _conicGradient(double total) {
    if (total <= 0) return '#e5e7eb';
    final stops = StringBuffer('conic-gradient(');
    var start = 0.0;
    for (var i = 0; i < data.length; i++) {
      final end = start + data[i].value;
      if (i > 0) stops.write(',');
      stops
        ..write(cssColor(_colorAt(i)))
        ..write(' ${cssPercent(start, total)}%')
        ..write(' ${cssPercent(end, total)}%');
      start = end;
    }
    stops.write(')');
    return stops.toString();
  }
}

class _PiePainter extends CustomPainter {
  _PiePainter({required this.values, required this.colors});

  final List<double> values;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold(0.0, (sum, value) => sum + value);
    if (total <= 0) return;
    final rect = Offset.zero & size;
    var start = -math.pi / 2; // oben beginnen, im Uhrzeigersinn
    for (var i = 0; i < values.length; i++) {
      final sweep = values[i] / total * 2 * math.pi;
      canvas.drawArc(rect, start, sweep, true, Paint()..color = colors[i]);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_PiePainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.colors != colors;
}
