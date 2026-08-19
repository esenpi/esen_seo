import 'package:esen_seo/core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('carousel transition', () {
    test('normalizes empty, negative and stale input', () {
      expect(
        initialSeoCarouselState(count: -4, index: 9),
        const SeoCarouselState(index: 0, count: 0),
      );
      expect(
        initialSeoCarouselState(count: 3, index: -1),
        const SeoCarouselState(index: 0, count: 3),
      );
      expect(
        initialSeoCarouselState(count: 3, index: 99),
        const SeoCarouselState(index: 2, count: 3),
      );
      expect(
        transitionSeoCarousel(
          const SeoCarouselState(index: 8, count: 2),
          const SeoCarouselSelect(9),
        ),
        const SeoCarouselState(index: 1, count: 2),
      );
    });

    test('selects without wrapping and handles every boundary action', () {
      var state = initialSeoCarouselState(count: 3, index: 1);
      final actions = <SeoCarouselAction>[
        const SeoCarouselNext(),
        const SeoCarouselNext(),
        const SeoCarouselPrevious(),
        const SeoCarouselFirst(),
        const SeoCarouselPrevious(),
        const SeoCarouselLast(),
        const SeoCarouselSelect(1),
        const SeoCarouselSelect(-1),
        const SeoCarouselSelect(3),
      ];
      final indices = <int>[];
      for (final action in actions) {
        state = transitionSeoCarousel(state, action);
        indices.add(state.index);
      }

      expect(indices, [2, 2, 1, 0, 0, 2, 1, 1, 1]);
      expect(state.count, 3);
    });

    test('does not mutate the input state', () {
      const before = SeoCarouselState(index: 0, count: 2);
      final after = transitionSeoCarousel(before, const SeoCarouselNext());

      expect(before, const SeoCarouselState(index: 0, count: 2));
      expect(after, const SeoCarouselState(index: 1, count: 2));
      expect(identical(before, after), isFalse);
    });
  });

  group('application transition boundary', () {
    test('keeps the current state for invalid application output', () {
      const current = SeoCarouselState(index: 1, count: 3);

      for (final invalid in <SeoCarouselTransition>[
        (_, __) => const SeoCarouselState(index: -1, count: 3),
        (_, __) => const SeoCarouselState(index: 3, count: 3),
        (_, __) => const SeoCarouselState(index: 0, count: 4),
        (_, __) => throw StateError('application failure'),
      ]) {
        expect(
          applySeoCarouselTransition(
            invalid,
            current,
            const SeoCarouselNext(),
          ),
          current,
        );
      }
    });

    test('normalizes input before application code receives it', () {
      late SeoCarouselState received;
      final result = applySeoCarouselTransition(
        (state, _) {
          received = state;
          return state;
        },
        const SeoCarouselState(index: 99, count: 2),
        const SeoCarouselNext(),
      );

      expect(received, const SeoCarouselState(index: 1, count: 2));
      expect(result, received);
    });

    test('control availability follows the selected transition', () {
      SeoCarouselState wrap(
        SeoCarouselState state,
        SeoCarouselAction action,
      ) {
        if (action is SeoCarouselPrevious && state.index == 0) {
          return SeoCarouselState(index: state.count - 1, count: state.count);
        }
        return transitionSeoCarousel(state, action);
      }

      const state = SeoCarouselState(index: 0, count: 3);
      expect(
        canApplySeoCarouselAction(
          transitionSeoCarousel,
          state,
          const SeoCarouselPrevious(),
        ),
        isFalse,
      );
      expect(
        canApplySeoCarouselAction(
          wrap,
          state,
          const SeoCarouselPrevious(),
        ),
        isTrue,
      );
    });
  });
}
