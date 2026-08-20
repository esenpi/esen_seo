import 'package:esen_seo/core.dart';

SeoStepperEffectResult transitionBenchmarkStepperEffects(
  SeoStepperState state,
  SeoStepperAction action,
) {
  final current = initialSeoStepperState(
    count: state.count,
    index: state.index,
  );
  if (current.count == 0) return SeoStepperEffectResult(state: current);
  final last = current.count - 1;
  final next = switch (action) {
    SeoStepperSelect(:final index) when index >= 0 && index <= last => index,
    SeoStepperSelect() => current.index,
    SeoStepperNext() => current.index == last ? 0 : current.index + 1,
    SeoStepperPrevious() => current.index == 0 ? last : current.index - 1,
    SeoStepperFirst() => 0,
    SeoStepperLast() => last,
  };
  final nextState = SeoStepperState(index: next, count: current.count);
  return SeoStepperEffectResult(
    state: nextState,
    effect: nextState == current ? null : const SeoStepperFocusActivePanel(),
  );
}
