/// Pure state transition shared by Flutter and DOM-first stepper presentations.
library;

/// A state-free stepper transition shared by platform presentations.
typedef SeoStepperTransition = SeoStepperState Function(
  SeoStepperState state,
  SeoStepperAction action,
);

/// Executes [transition] within the closed state contract of a stepper.
///
/// Application logic cannot change the step count or select a missing step.
/// A thrown exception or invalid result leaves the last valid state unchanged
/// on both Flutter and DOM-first presentations.
SeoStepperState applySeoStepperTransition(
  SeoStepperTransition transition,
  SeoStepperState state,
  SeoStepperAction action,
) {
  final current = _normalizedSeoStepperState(state);
  final SeoStepperState result;
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
///
/// Presentations use this to expose the same control availability as the
/// transition they execute. The transition must therefore remain pure and
/// inexpensive; invalid output and exceptions make the action unavailable.
bool canApplySeoStepperAction(
  SeoStepperTransition transition,
  SeoStepperState state,
  SeoStepperAction action,
) {
  final current = _normalizedSeoStepperState(state);
  return applySeoStepperTransition(transition, current, action) != current;
}

/// The complete shared state needed to select one step.
final class SeoStepperState {
  const SeoStepperState({required this.index, required this.count});

  /// The selected step index. [transitionSeoStepper] normalizes it before use.
  final int index;

  /// The number of steps. Negative input is normalized to zero.
  final int count;

  @override
  bool operator ==(Object other) =>
      other is SeoStepperState && other.index == index && other.count == count;

  @override
  int get hashCode => Object.hash(index, count);
}

/// A user intent understood by the shared stepper transition.
sealed class SeoStepperAction {
  const SeoStepperAction();
}

/// Selects one step by index. Out-of-range indices leave selection unchanged.
final class SeoStepperSelect extends SeoStepperAction {
  const SeoStepperSelect(this.index);

  final int index;
}

/// Selects the next step without moving past the final step.
final class SeoStepperNext extends SeoStepperAction {
  const SeoStepperNext();
}

/// Selects the previous step without moving before the first step.
final class SeoStepperPrevious extends SeoStepperAction {
  const SeoStepperPrevious();
}

/// Selects the first step.
final class SeoStepperFirst extends SeoStepperAction {
  const SeoStepperFirst();
}

/// Selects the last step.
final class SeoStepperLast extends SeoStepperAction {
  const SeoStepperLast();
}

/// Returns a valid initial state for [count] steps.
SeoStepperState initialSeoStepperState({required int count, int index = 0}) =>
    _normalizedSeoStepperState(SeoStepperState(index: index, count: count));

/// Computes the next stepper state without retaining state or causing effects.
SeoStepperState transitionSeoStepper(
  SeoStepperState state,
  SeoStepperAction action,
) {
  final normalized = _normalizedSeoStepperState(state);
  final count = normalized.count;
  if (count == 0) return normalized;

  final current = normalized.index;
  final last = count - 1;
  final next = switch (action) {
    SeoStepperSelect(:final index) when index >= 0 && index < count => index,
    SeoStepperSelect() => current,
    SeoStepperNext() => (current + 1).clamp(0, last),
    SeoStepperPrevious() => (current - 1).clamp(0, last),
    SeoStepperFirst() => 0,
    SeoStepperLast() => last,
  };
  return SeoStepperState(index: next, count: count);
}

SeoStepperState _normalizedSeoStepperState(SeoStepperState state) {
  final count = state.count < 0 ? 0 : state.count;
  if (count == 0) return const SeoStepperState(index: 0, count: 0);
  return SeoStepperState(index: state.index.clamp(0, count - 1), count: count);
}
