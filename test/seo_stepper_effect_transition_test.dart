import 'package:esen_seo/core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const current = SeoStepperState(index: 0, count: 3);
  const next = SeoStepperState(index: 1, count: 3);

  test('effect results support const application definitions', () {
    const result = SeoStepperEffectResult(
      state: next,
      effect: SeoStepperFocusActivePanel(),
    );

    expect(result.effects, const [SeoStepperFocusActivePanel()]);
  });

  test('validates and normalizes one focus effect with the next state', () {
    final result = applySeoStepperEffectTransition(
      (state, action) => SeoStepperEffectResult(
        state: next,
        effect: const SeoStepperFocusActivePanel(),
      ),
      current,
      const SeoStepperNext(),
    );

    expect(result.state, next);
    expect(result.effects, const [SeoStepperFocusActivePanel()]);
    expect(() => result.effects.add(const SeoStepperFocusActivePanel()),
        throwsUnsupportedError);
  });

  test('rejects state and effects together when the result is invalid', () {
    final invalid = <SeoStepperEffectTransition>[
      (state, action) => SeoStepperEffectResult(
            state: SeoStepperState(index: 3, count: state.count),
            effect: const SeoStepperFocusActivePanel(),
          ),
      (state, action) => throw StateError('application failure'),
    ];

    for (final transition in invalid) {
      final result = applySeoStepperEffectTransition(
        transition,
        current,
        const SeoStepperNext(),
      );
      expect(result.state, current);
      expect(result.effects, isEmpty);
    }
  });

  test('a no-op cannot smuggle an effect through an accepted dispatch', () {
    final result = applySeoStepperEffectTransition(
      (state, action) => SeoStepperEffectResult(
        state: state,
        effect: const SeoStepperFocusActivePanel(),
      ),
      current,
      const SeoStepperSelect(0),
    );

    expect(result.state, current);
    expect(result.effects, isEmpty);
  });

  test('availability follows the atomically accepted state result', () {
    SeoStepperEffectResult transition(
      SeoStepperState state,
      SeoStepperAction action,
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
      ),
      isTrue,
    );
    expect(
      canApplySeoStepperEffectAction(
        transition,
        current,
        const SeoStepperPrevious(),
      ),
      isFalse,
    );
  });
}
