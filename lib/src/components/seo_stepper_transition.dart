/// Pure state transition shared by Flutter and DOM-first stepper presentations.
library;

/// A state-free stepper transition shared by platform presentations.
typedef SeoStepperTransition = SeoStepperState Function(
  SeoStepperState state,
  SeoStepperAction action,
);

/// A pure stepper transition that may request one closed platform effect.
typedef SeoStepperEffectTransition = SeoStepperEffectResult Function(
  SeoStepperState state,
  SeoStepperAction action,
);

/// The atomically validated output of a [SeoStepperEffectTransition].
final class SeoStepperEffectResult {
  const SeoStepperEffectResult({
    required this.state,
    this.effect,
  });

  /// The requested next selection state.
  final SeoStepperState state;

  /// The optional closed effect applied after the state.
  final SeoStepperEffect? effect;

  /// The immutable zero-or-one effect sequence applied after the state.
  List<SeoStepperEffect> get effects => effect == null
      ? const <SeoStepperEffect>[]
      : List<SeoStepperEffect>.unmodifiable([effect!]);
}

/// A closed imperative intent emitted by a pure stepper transition.
sealed class SeoStepperEffect {
  const SeoStepperEffect();
}

/// Requests focus for the package-owned active step panel.
final class SeoStepperFocusActivePanel extends SeoStepperEffect {
  const SeoStepperFocusActivePanel();

  @override
  bool operator ==(Object other) => other is SeoStepperFocusActivePanel;

  @override
  int get hashCode => runtimeType.hashCode;
}

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

/// Executes [transition] and atomically validates its state and effect output.
///
/// A valid accepted action must change the normalized state and may request at
/// most one [SeoStepperFocusActivePanel]. Invalid output, a no-op carrying an
/// effect, or a thrown exception retains [state] and emits no effect.
SeoStepperEffectResult applySeoStepperEffectTransition(
  SeoStepperEffectTransition transition,
  SeoStepperState state,
  SeoStepperAction action,
) {
  final current = _normalizedSeoStepperState(state);
  final SeoStepperEffectResult result;
  try {
    result = transition(current, action);
  } catch (_) {
    return _noSeoStepperEffect(current);
  }
  final next = result.state;
  if (next.count != current.count ||
      next.index < 0 ||
      next.index >= current.count) {
    return _noSeoStepperEffect(current);
  }
  if (next == current) return _noSeoStepperEffect(current);
  final effect = switch (result.effect) {
    null => null,
    SeoStepperFocusActivePanel() => const SeoStepperFocusActivePanel(),
  };
  return SeoStepperEffectResult(state: next, effect: effect);
}

/// Whether [action] can change [state] through an effect-capable transition.
///
/// The effect sequence is validated but never exposed or executed by this
/// availability probe.
bool canApplySeoStepperEffectAction(
  SeoStepperEffectTransition transition,
  SeoStepperState state,
  SeoStepperAction action,
) {
  final current = _normalizedSeoStepperState(state);
  return applySeoStepperEffectTransition(transition, current, action).state !=
      current;
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

SeoStepperEffectResult _noSeoStepperEffect(SeoStepperState state) =>
    SeoStepperEffectResult(state: state);
