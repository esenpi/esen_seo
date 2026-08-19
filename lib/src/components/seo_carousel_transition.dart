/// Pure state transition shared by Flutter and DOM-first carousel presentations.
library;

/// A state-free carousel transition shared by platform presentations.
typedef SeoCarouselTransition = SeoCarouselState Function(
  SeoCarouselState state,
  SeoCarouselAction action,
);

/// Executes [transition] within the closed state contract of a carousel.
///
/// Application logic cannot change the slide count or select a missing slide.
/// A thrown exception or invalid result leaves the last valid state unchanged
/// on both Flutter and DOM-first presentations.
SeoCarouselState applySeoCarouselTransition(
  SeoCarouselTransition transition,
  SeoCarouselState state,
  SeoCarouselAction action,
) {
  final current = _normalizedSeoCarouselState(state);
  final SeoCarouselState result;
  try {
    result = transition(current, action);
  } catch (_) {
    return current;
  }
  if (result.count != current.count ||
      result.index < 0 ||
      result.index >= current.count) {
    return current;
  }
  return result;
}

/// Whether [action] can move the normalized [state] through [transition].
bool canApplySeoCarouselAction(
  SeoCarouselTransition transition,
  SeoCarouselState state,
  SeoCarouselAction action,
) {
  final current = _normalizedSeoCarouselState(state);
  return applySeoCarouselTransition(transition, current, action) != current;
}

/// The complete shared state needed to select one slide.
final class SeoCarouselState {
  const SeoCarouselState({required this.index, required this.count});

  /// The selected slide index. [transitionSeoCarousel] normalizes it first.
  final int index;

  /// The number of slides. Negative input is normalized to zero.
  final int count;

  @override
  bool operator ==(Object other) =>
      other is SeoCarouselState && other.index == index && other.count == count;

  @override
  int get hashCode => Object.hash(index, count);
}

/// A user intent understood by the shared carousel transition.
sealed class SeoCarouselAction {
  const SeoCarouselAction();
}

/// Selects one slide by index. Invalid indices leave selection unchanged.
final class SeoCarouselSelect extends SeoCarouselAction {
  const SeoCarouselSelect(this.index);

  final int index;
}

/// Selects the next slide without moving past the final slide.
final class SeoCarouselNext extends SeoCarouselAction {
  const SeoCarouselNext();
}

/// Selects the previous slide without moving before the first slide.
final class SeoCarouselPrevious extends SeoCarouselAction {
  const SeoCarouselPrevious();
}

/// Selects the first slide.
final class SeoCarouselFirst extends SeoCarouselAction {
  const SeoCarouselFirst();
}

/// Selects the last slide.
final class SeoCarouselLast extends SeoCarouselAction {
  const SeoCarouselLast();
}

/// Returns a valid initial state for [count] slides.
SeoCarouselState initialSeoCarouselState({required int count, int index = 0}) =>
    _normalizedSeoCarouselState(SeoCarouselState(index: index, count: count));

/// Computes the next carousel state without retaining state or causing effects.
SeoCarouselState transitionSeoCarousel(
  SeoCarouselState state,
  SeoCarouselAction action,
) {
  final normalized = _normalizedSeoCarouselState(state);
  final count = normalized.count;
  if (count == 0) return normalized;

  final current = normalized.index;
  final last = count - 1;
  final next = switch (action) {
    SeoCarouselSelect(:final index) when index >= 0 && index < count => index,
    SeoCarouselSelect() => current,
    SeoCarouselNext() => (current + 1).clamp(0, last),
    SeoCarouselPrevious() => (current - 1).clamp(0, last),
    SeoCarouselFirst() => 0,
    SeoCarouselLast() => last,
  };
  return SeoCarouselState(index: next, count: count);
}

SeoCarouselState _normalizedSeoCarouselState(SeoCarouselState state) {
  final count = state.count < 0 ? 0 : state.count;
  if (count == 0) return const SeoCarouselState(index: 0, count: 0);
  return SeoCarouselState(index: state.index.clamp(0, count - 1), count: count);
}
