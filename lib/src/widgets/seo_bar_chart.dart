import 'package:flutter/widgets.dart';

import '../components/seo_components.dart';
import '../components/seo_motion.dart';
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
    this.motion = SeoMotionPreset.none,
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

  /// Optional decorative motion shared with the semantic web presentation.
  ///
  /// [SeoMotionPreset.none] preserves the original static widget and HTML.
  /// [SeoMotionPreset.gentle] grows the bars with a short stagger and adds
  /// pointer or press emphasis. Reduced-motion preferences disable both.
  final SeoMotionPreset motion;

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
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final motionEnabled = motion != SeoMotionPreset.none && !disableAnimations;
    final timing = seoMotionTiming(motion);
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
          child: motionEnabled
              ? TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: timing.totalEntranceFor(data.length),
                  builder: (context, elapsed, _) => _buildBars(
                    max: max,
                    elapsed: elapsed,
                    timing: timing,
                    motionEnabled: true,
                  ),
                )
              : _buildBars(
                  max: max,
                  elapsed: 1,
                  timing: timing,
                  motionEnabled: false,
                ),
        ),
      ],
    );
  }

  Widget _buildBars({
    required double max,
    required double elapsed,
    required SeoMotionTiming timing,
    required bool motionEnabled,
  }) {
    final total = timing.totalEntranceFor(data.length);
    final curve = Cubic(timing.x1, timing.y1, timing.x2, timing.y2);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var index = 0; index < data.length; index++)
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
                        heightFactor: _heightFactor(
                          index: index,
                          max: max,
                          elapsed: elapsed,
                          total: total,
                          timing: timing,
                          curve: curve,
                          motionEnabled: motionEnabled,
                        ),
                        child: _bar(
                          curve: curve,
                          timing: timing,
                          motionEnabled: motionEnabled,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data[index].label,
                    style: labelStyle ?? const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  double _heightFactor({
    required int index,
    required double max,
    required double elapsed,
    required Duration total,
    required SeoMotionTiming timing,
    required Curve curve,
    required bool motionEnabled,
  }) {
    final target =
        max <= 0 ? 0.0 : (_valueOf(data[index]) / max).clamp(0.0, 1.0);
    if (!motionEnabled || total == Duration.zero) return target;
    final elapsedMicros = total.inMicroseconds * elapsed;
    final local = ((elapsedMicros - timing.delayFor(index).inMicroseconds) /
            timing.entrance.inMicroseconds)
        .clamp(0.0, 1.0)
        .toDouble();
    return target * curve.transform(local);
  }

  Widget _bar({
    required Cubic curve,
    required SeoMotionTiming timing,
    required bool motionEnabled,
  }) {
    final bar = Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
      ),
    );
    if (!motionEnabled) return bar;
    return _SeoBarMotionSurface(
      timing: timing,
      curve: curve,
      child: bar,
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
        motion: motion,
      );
}

class _SeoBarMotionSurface extends StatefulWidget {
  const _SeoBarMotionSurface({
    required this.timing,
    required this.curve,
    required this.child,
  });

  final SeoMotionTiming timing;
  final Cubic curve;
  final Widget child;

  @override
  State<_SeoBarMotionSurface> createState() => _SeoBarMotionSurfaceState();
}

class _SeoBarMotionSurfaceState extends State<_SeoBarMotionSurface> {
  bool _hovered = false;
  bool _pressed = false;

  void _setHovered(bool value) {
    if (_hovered == value) return;
    setState(() => _hovered = value);
  }

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final emphasized = _hovered || _pressed;
    return MouseRegion(
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: Listener(
        onPointerDown: (_) => _setPressed(true),
        onPointerUp: (_) => _setPressed(false),
        onPointerCancel: (_) => _setPressed(false),
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: emphasized ? 1 : 0),
          duration: widget.timing.emphasis,
          curve: widget.curve,
          child: widget.child,
          builder: (context, value, child) => Transform.translate(
            offset: Offset(0, -4 * value),
            child: Transform.scale(
              scale: 1 + 0.025 * value,
              alignment: Alignment.bottomCenter,
              child: Opacity(opacity: 1 - 0.08 * value, child: child),
            ),
          ),
        ),
      ),
    );
  }
}
