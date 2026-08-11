import 'package:esen_seo/core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('tabs transition', () {
    test('normalizes empty, negative and stale input', () {
      expect(
        initialSeoTabsState(count: -4, index: 9),
        const SeoTabsState(index: 0, count: 0),
      );
      expect(
        initialSeoTabsState(count: 3, index: -1),
        const SeoTabsState(index: 0, count: 3),
      );
      expect(
        initialSeoTabsState(count: 3, index: 99),
        const SeoTabsState(index: 2, count: 3),
      );
      expect(
        transitionSeoTabs(
          const SeoTabsState(index: 8, count: 2),
          const SeoTabsSelect(9),
        ),
        const SeoTabsState(index: 1, count: 2),
      );
    });

    test('selects, wraps and handles boundary actions deterministically', () {
      var state = initialSeoTabsState(count: 3, index: 1);
      final actions = <SeoTabsAction>[
        const SeoTabsNext(),
        const SeoTabsNext(),
        const SeoTabsPrevious(),
        const SeoTabsFirst(),
        const SeoTabsPrevious(),
        const SeoTabsLast(),
        const SeoTabsSelect(1),
        const SeoTabsSelect(-1),
        const SeoTabsSelect(3),
      ];
      final indices = <int>[];
      for (final action in actions) {
        state = transitionSeoTabs(state, action);
        indices.add(state.index);
      }

      expect(indices, [2, 0, 2, 0, 2, 2, 1, 1, 1]);
      expect(state.count, 3);
    });

    test('does not mutate the input state', () {
      const before = SeoTabsState(index: 0, count: 2);
      final after = transitionSeoTabs(before, const SeoTabsNext());

      expect(before, const SeoTabsState(index: 0, count: 2));
      expect(after, const SeoTabsState(index: 1, count: 2));
      expect(identical(before, after), isFalse);
    });
  });

  group('application transition boundary', () {
    test('keeps the current state for invalid application output', () {
      const current = SeoTabsState(index: 1, count: 3);

      for (final invalid in <SeoTabsTransition>[
        (_, __) => const SeoTabsState(index: -1, count: 3),
        (_, __) => const SeoTabsState(index: 3, count: 3),
        (_, __) => const SeoTabsState(index: 0, count: 4),
        (_, __) => throw StateError('application failure'),
      ]) {
        expect(
          applySeoTabsTransition(invalid, current, const SeoTabsNext()),
          current,
        );
      }
    });

    test('normalizes input before application code receives it', () {
      late SeoTabsState received;
      final result = applySeoTabsTransition(
        (state, _) {
          received = state;
          return state;
        },
        const SeoTabsState(index: 99, count: 2),
        const SeoTabsNext(),
      );

      expect(received, const SeoTabsState(index: 1, count: 2));
      expect(result, received);
    });
  });
}
