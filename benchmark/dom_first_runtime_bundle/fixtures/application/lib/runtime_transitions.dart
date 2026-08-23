import 'package:esen_seo/core.dart';

const benchmarkStepperInteractionId = 'benchmark-stepper';

SeoTabsState transitionBenchmarkTabs(
  SeoTabsState state,
  SeoTabsAction action,
) {
  final current = initialSeoTabsState(count: state.count, index: state.index);
  if (current.count == 0) return current;
  final last = current.count - 1;
  final next = switch (action) {
    SeoTabsSelect(:final index) when index >= 0 && index <= last => index,
    SeoTabsSelect() => current.index,
    SeoTabsNext() => (current.index + 1).clamp(0, last),
    SeoTabsPrevious() => (current.index - 1).clamp(0, last),
    SeoTabsFirst() => 0,
    SeoTabsLast() => last,
  };
  return SeoTabsState(index: next, count: current.count);
}

SeoCarouselState transitionBenchmarkCarousel(
  SeoCarouselState state,
  SeoCarouselAction action,
) {
  final current = initialSeoCarouselState(
    count: state.count,
    index: state.index,
  );
  if (current.count == 0) return current;
  final last = current.count - 1;
  final next = switch (action) {
    SeoCarouselSelect(:final index) when index >= 0 && index <= last => index,
    SeoCarouselSelect() => current.index,
    SeoCarouselNext() => current.index == last ? 0 : current.index + 1,
    SeoCarouselPrevious() => current.index == 0 ? last : current.index - 1,
    SeoCarouselFirst() => 0,
    SeoCarouselLast() => last,
  };
  return SeoCarouselState(index: next, count: current.count);
}

SeoStepperState transitionBenchmarkStepper(
  SeoStepperState state,
  SeoStepperAction action,
) {
  final current = initialSeoStepperState(
    count: state.count,
    index: state.index,
  );
  if (current.count == 0) return current;
  final last = current.count - 1;
  final next = switch (action) {
    SeoStepperSelect(:final index) when index >= 0 && index <= last => index,
    SeoStepperSelect() => current.index,
    SeoStepperNext() => current.index == last ? 0 : current.index + 1,
    SeoStepperPrevious() => current.index == 0 ? last : current.index - 1,
    SeoStepperFirst() => 0,
    SeoStepperLast() => last,
  };
  return SeoStepperState(index: next, count: current.count);
}

SeoStepperEffectResult transitionBenchmarkStepperEffects(
  SeoStepperState state,
  SeoStepperAction action,
  SeoStepperEffectContext context,
) {
  if (context.interactionId != benchmarkStepperInteractionId) {
    return SeoStepperEffectResult(state: state);
  }
  final next = transitionBenchmarkStepper(state, action);
  return SeoStepperEffectResult(
    state: next,
    effect: next == state ? null : const SeoStepperFocusActivePanel(),
  );
}
