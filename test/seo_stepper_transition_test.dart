import 'package:esen_seo/core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('stepper transition', () {
    test('normalizes empty, negative and stale input', () {
      expect(
        initialSeoStepperState(count: -4, index: 9),
        const SeoStepperState(index: 0, count: 0),
      );
      expect(
        initialSeoStepperState(count: 3, index: -1),
        const SeoStepperState(index: 0, count: 3),
      );
      expect(
        initialSeoStepperState(count: 3, index: 99),
        const SeoStepperState(index: 2, count: 3),
      );
      expect(
        transitionSeoStepper(
          const SeoStepperState(index: 8, count: 2),
          const SeoStepperSelect(9),
        ),
        const SeoStepperState(index: 1, count: 2),
      );
    });

    test('selects without wrapping and handles every boundary action', () {
      var state = initialSeoStepperState(count: 3, index: 1);
      final actions = <SeoStepperAction>[
        const SeoStepperNext(),
        const SeoStepperNext(),
        const SeoStepperPrevious(),
        const SeoStepperFirst(),
        const SeoStepperPrevious(),
        const SeoStepperLast(),
        const SeoStepperSelect(1),
        const SeoStepperSelect(-1),
        const SeoStepperSelect(3),
      ];
      final indices = <int>[];
      for (final action in actions) {
        state = transitionSeoStepper(state, action);
        indices.add(state.index);
      }

      expect(indices, [2, 2, 1, 0, 0, 2, 1, 1, 1]);
      expect(state.count, 3);
    });

    test('does not mutate the input state', () {
      const before = SeoStepperState(index: 0, count: 2);
      final after = transitionSeoStepper(before, const SeoStepperNext());

      expect(before, const SeoStepperState(index: 0, count: 2));
      expect(after, const SeoStepperState(index: 1, count: 2));
      expect(identical(before, after), isFalse);
    });
  });

  group('application transition boundary', () {
    test('keeps the current state for invalid application output', () {
      const current = SeoStepperState(index: 1, count: 3);

      for (final invalid in <SeoStepperTransition>[
        (_, __) => const SeoStepperState(index: -1, count: 3),
        (_, __) => const SeoStepperState(index: 3, count: 3),
        (_, __) => const SeoStepperState(index: 0, count: 4),
        (_, __) => throw StateError('application failure'),
      ]) {
        expect(
          applySeoStepperTransition(
            invalid,
            current,
            const SeoStepperNext(),
          ),
          current,
        );
      }
    });

    test('normalizes input before application code receives it', () {
      late SeoStepperState received;
      final result = applySeoStepperTransition(
        (state, _) {
          received = state;
          return state;
        },
        const SeoStepperState(index: 99, count: 2),
        const SeoStepperNext(),
      );

      expect(received, const SeoStepperState(index: 1, count: 2));
      expect(result, received);
    });
  });
}
