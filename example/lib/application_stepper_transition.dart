import 'package:esen_seo/core.dart';

/// Example-owned stepper logic: previous and next wrap at either end.
SeoStepperState transitionExampleStepper(
  SeoStepperState state,
  SeoStepperAction action,
) {
  final normalized = initialSeoStepperState(
    count: state.count,
    index: state.index,
  );
  if (normalized.count == 0) return normalized;
  final last = normalized.count - 1;
  final next = switch (action) {
    SeoStepperSelect(:final index) when index >= 0 && index <= last => index,
    SeoStepperSelect() => normalized.index,
    SeoStepperNext() => normalized.index == last ? 0 : normalized.index + 1,
    SeoStepperPrevious() => normalized.index == 0 ? last : normalized.index - 1,
    SeoStepperFirst() => 0,
    SeoStepperLast() => last,
  };
  return SeoStepperState(index: next, count: normalized.count);
}

/// Adds one focus request after an accepted application step change.
SeoStepperEffectResult transitionExampleStepperEffects(
  SeoStepperState state,
  SeoStepperAction action,
) {
  final next = transitionExampleStepper(state, action);
  return SeoStepperEffectResult(
    state: next,
    effect: next == state ? null : const SeoStepperFocusActivePanel(),
  );
}
