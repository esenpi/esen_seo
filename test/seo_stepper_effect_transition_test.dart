import 'package:esen_seo/core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const current = SeoStepperState(index: 0, count: 3);
  const next = SeoStepperState(index: 1, count: 3);
  const context = SeoStepperEffectContext(interactionId: 'test-stepper');

  test('effect results support const application definitions', () {
    const result = SeoStepperEffectResult(
      state: next,
      effect: SeoStepperFocusActivePanel(),
    );

    expect(result.effects, const [SeoStepperFocusActivePanel()]);
  });

  test('validates and normalizes one focus effect with the next state', () {
    final result = applySeoStepperEffectTransition(
      (state, action, context) => SeoStepperEffectResult(
        state: next,
        effect: const SeoStepperFocusActivePanel(),
      ),
      current,
      const SeoStepperNext(),
      context,
    );

    expect(result.state, next);
    expect(result.effects, const [SeoStepperFocusActivePanel()]);
    expect(() => result.effects.add(const SeoStepperFocusActivePanel()),
        throwsUnsupportedError);
  });

  test('rejects state and effects together when the result is invalid', () {
    final invalid = <SeoStepperEffectTransition>[
      (state, action, context) => SeoStepperEffectResult(
            state: SeoStepperState(index: 3, count: state.count),
            effect: const SeoStepperFocusActivePanel(),
          ),
      (state, action, context) => throw StateError('application failure'),
    ];

    for (final transition in invalid) {
      final result = applySeoStepperEffectTransition(
        transition,
        current,
        const SeoStepperNext(),
        context,
      );
      expect(result.state, current);
      expect(result.effects, isEmpty);
    }
  });

  test('a no-op cannot smuggle an effect through an accepted dispatch', () {
    final result = applySeoStepperEffectTransition(
      (state, action, context) => SeoStepperEffectResult(
        state: state,
        effect: const SeoStepperFocusActivePanel(),
      ),
      current,
      const SeoStepperSelect(0),
      context,
    );

    expect(result.state, current);
    expect(result.effects, isEmpty);
  });

  test('availability follows the atomically accepted state result', () {
    SeoStepperEffectResult transition(
      SeoStepperState state,
      SeoStepperAction action,
      SeoStepperEffectContext context,
    ) =>
        SeoStepperEffectResult(
          state: action is SeoStepperNext ? next : state,
          effect: const SeoStepperFocusActivePanel(),
        );

    expect(
      canApplySeoStepperEffectAction(
        transition,
        current,
        const SeoStepperNext(),
        context,
      ),
      isTrue,
    );
    expect(
      canApplySeoStepperEffectAction(
        transition,
        current,
        const SeoStepperPrevious(),
        context,
      ),
      isFalse,
    );
  });
}
