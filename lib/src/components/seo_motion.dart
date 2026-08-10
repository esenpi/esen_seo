/// Pure motion presets shared by Flutter and semantic web presentations.
library;

/// Closed, package-owned motion choices for bridge components.
///
/// The default is [none], so adding motion support never changes an existing
/// widget or its serialized HTML. Presets deliberately expose no arbitrary CSS
/// or platform curve objects.
enum SeoMotionPreset {
  /// Render the final state immediately with no decorative motion.
  none,

  /// A restrained entrance followed by short pointer or press emphasis.
  gentle,
}

/// Internal timing data derived from one [SeoMotionPreset].
///
/// This type is public only so the package's pure and Flutter libraries can
/// share it across Dart library boundaries. It is not exported by `core.dart`.
class SeoMotionTiming {
  const SeoMotionTiming({
    required this.entrance,
    required this.stagger,
    required this.emphasis,
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
  });

  final Duration entrance;
  final Duration stagger;
  final Duration emphasis;
  final double x1;
  final double y1;
  final double x2;
  final double y2;

  Duration delayFor(int index) =>
      stagger * index.clamp(0, seoMotionMaxStaggeredItems - 1);

  Duration totalEntranceFor(int itemCount) =>
      itemCount <= 0 ? Duration.zero : entrance + delayFor(itemCount - 1);
}

/// Caps entrance staggering so large data sets never take seconds to settle.
const int seoMotionMaxStaggeredItems = 12;

/// Returns the single source of timing truth for [preset].
SeoMotionTiming seoMotionTiming(SeoMotionPreset preset) => switch (preset) {
      SeoMotionPreset.none => const SeoMotionTiming(
          entrance: Duration.zero,
          stagger: Duration.zero,
          emphasis: Duration.zero,
          x1: 0,
          y1: 0,
          x2: 1,
          y2: 1,
        ),
      SeoMotionPreset.gentle => const SeoMotionTiming(
          entrance: Duration(milliseconds: 520),
          stagger: Duration(milliseconds: 55),
          emphasis: Duration(milliseconds: 160),
          x1: 0.22,
          y1: 1,
          x2: 0.36,
          y2: 1,
        ),
    };

/// Fixed HTML marker for [preset], or `null` when no CSS should run.
String? seoMotionMarker(SeoMotionPreset preset) => switch (preset) {
      SeoMotionPreset.none => null,
      SeoMotionPreset.gentle => 'gentle',
    };
