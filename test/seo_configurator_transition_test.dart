import 'package:esen_seo/src/components/seo_configurator_transition.dart';
import 'package:flutter_test/flutter_test.dart';

const _constraints = SeoConfiguratorConstraints(
  choiceCount: 3,
  minQuantity: 1,
  maxQuantity: 20,
);

const _bases = [1900, 4900, 9900];
const _additionalSites = [900, 700, 500];
const _names = ['Solo', 'Team', 'Agency'];

SeoConfiguratorView _pricingView(SeoConfiguratorState state) {
  final cents = _bases[state.choiceIndex] +
      (state.quantity - 1) * _additionalSites[state.choiceIndex] +
      (state.optionEnabled ? 1500 : 0);
  final price = _money(cents);
  final support = state.optionEnabled ? ', Priority-Support' : '';
  return SeoConfiguratorView(
    priceText: '$price pro Monat',
    summaryText:
        '${_names[state.choiceIndex]}, ${state.quantity} Websites$support',
    announcementText: 'Neuer Preis: $price pro Monat',
    activeChoiceRegion: state.choiceIndex,
    optionRegionVisible: state.optionEnabled,
  );
}

String _money(int cents) =>
    '${cents ~/ 100},${(cents % 100).toString().padLeft(2, '0')} EUR';

void main() {
  group('configurator constraints and default transition', () {
    test('accepts only closed, cross-platform bounds', () {
      expect(isValidSeoConfiguratorConstraints(_constraints), isTrue);
      for (final invalid in const [
        SeoConfiguratorConstraints(
          choiceCount: 0,
          minQuantity: 1,
          maxQuantity: 20,
        ),
        SeoConfiguratorConstraints(
          choiceCount: seoConfiguratorMaxChoices + 1,
          minQuantity: 1,
          maxQuantity: 20,
        ),
        SeoConfiguratorConstraints(
          choiceCount: 1,
          minQuantity: -1,
          maxQuantity: 20,
        ),
        SeoConfiguratorConstraints(
          choiceCount: 1,
          minQuantity: 2,
          maxQuantity: 1,
        ),
        SeoConfiguratorConstraints(
          choiceCount: 1,
          minQuantity: 0,
          maxQuantity: seoConfiguratorMaxQuantity + 1,
        ),
      ]) {
        expect(isValidSeoConfiguratorConstraints(invalid), isFalse);
        expect(
          initialSeoConfiguratorState(constraints: invalid),
          isNull,
        );
      }
    });

    test('canonicalizes only explicit initial input', () {
      expect(
        initialSeoConfiguratorState(
          constraints: _constraints,
          choiceIndex: 99,
          quantity: -4,
          optionEnabled: true,
        ),
        const SeoConfiguratorState(
          choiceIndex: 2,
          quantity: 1,
          optionEnabled: true,
        ),
      );
    });

    test('handles every closed action without crossing boundaries', () {
      var state = const SeoConfiguratorState(
        choiceIndex: 0,
        quantity: 1,
        optionEnabled: false,
      );
      for (final action in const <SeoConfiguratorAction>[
        SeoConfiguratorSelectChoice(1),
        SeoConfiguratorIncrementQuantity(),
        SeoConfiguratorSetOption(true),
        SeoConfiguratorDecrementQuantity(),
        SeoConfiguratorDecrementQuantity(),
        SeoConfiguratorSelectChoice(-1),
        SeoConfiguratorSelectChoice(3),
      ]) {
        state = transitionSeoConfigurator(state, action, _constraints);
      }
      expect(
        state,
        const SeoConfiguratorState(
          choiceIndex: 1,
          quantity: 1,
          optionEnabled: true,
        ),
      );

      const atMaximum = SeoConfiguratorState(
        choiceIndex: 2,
        quantity: 20,
        optionEnabled: false,
      );
      expect(
        transitionSeoConfigurator(
          atMaximum,
          const SeoConfiguratorIncrementQuantity(),
          _constraints,
        ),
        atMaximum,
      );
    });
  });

  group('initial view boundary', () {
    const state = SeoConfiguratorState(
      choiceIndex: 0,
      quantity: 1,
      optionEnabled: false,
    );

    test('returns one canonical fixed-schema view', () {
      final result = evaluateInitialSeoConfiguratorView(
        (_) => const SeoConfiguratorView(
          priceText: '1\u202E9,00 EUR',
          summaryText: 'Solo\u2066, 1 Website',
          announcementText: '\u200ENeuer Preis: 19,00 EUR',
          activeChoiceRegion: 0,
          optionRegionVisible: false,
        ),
        state,
        _constraints,
      );

      expect(result, isNotNull);
      expect(result!.accepted, isFalse);
      expect(result.view.priceText, '19,00 EUR');
      expect(result.view.summaryText, 'Solo, 1 Website');
      expect(result.view.announcementText, 'Neuer Preis: 19,00 EUR');
    });

    test('keeps HTML-looking application text as text data', () {
      final result = evaluateInitialSeoConfiguratorView(
        (_) => const SeoConfiguratorView(
          priceText: '<script>alert(1)</script>',
          summaryText: '<img src=x onerror=alert(1)>',
          announcementText: 'Price <b>changed</b>',
          activeChoiceRegion: 0,
          optionRegionVisible: false,
        ),
        state,
        _constraints,
      );

      expect(result!.view.priceText, '<script>alert(1)</script>');
      expect(result.view.summaryText, '<img src=x onerror=alert(1)>');
    });

    test('rejects invalid state, throwing projection and dishonest regions',
        () {
      expect(
        evaluateInitialSeoConfiguratorView(
          _pricingView,
          const SeoConfiguratorState(
            choiceIndex: 3,
            quantity: 1,
            optionEnabled: false,
          ),
          _constraints,
        ),
        isNull,
      );
      expect(
        evaluateInitialSeoConfiguratorView(
          (_) => throw StateError('projection failed'),
          state,
          _constraints,
        ),
        isNull,
      );
      for (final view in const [
        SeoConfiguratorView(
          priceText: '19,00 EUR',
          summaryText: 'Solo',
          announcementText: '19,00 EUR',
          activeChoiceRegion: 1,
          optionRegionVisible: false,
        ),
        SeoConfiguratorView(
          priceText: '19,00 EUR',
          summaryText: 'Solo',
          announcementText: '19,00 EUR',
          activeChoiceRegion: 0,
          optionRegionVisible: true,
        ),
      ]) {
        expect(
          evaluateInitialSeoConfiguratorView(
            (_) => view,
            state,
            _constraints,
          ),
          isNull,
        );
      }
    });

    test('enforces raw per-slot and aggregate bounds before sanitation', () {
      SeoConfiguratorView view({
        required String price,
        required String summary,
        required String announcement,
      }) =>
          SeoConfiguratorView(
            priceText: price,
            summaryText: summary,
            announcementText: announcement,
            activeChoiceRegion: 0,
            optionRegionVisible: false,
          );

      final exact = view(
        price: 'p' * seoConfiguratorMaxPriceTextLength,
        summary: 's' *
            (seoConfiguratorMaxAggregateTextLength -
                seoConfiguratorMaxPriceTextLength -
                seoConfiguratorMaxAnnouncementTextLength),
        announcement: 'a' * seoConfiguratorMaxAnnouncementTextLength,
      );
      expect(
        evaluateInitialSeoConfiguratorView((_) => exact, state, _constraints),
        isNotNull,
      );

      for (final invalid in [
        view(
          price: 'p' * (seoConfiguratorMaxPriceTextLength + 1),
          summary: 'summary',
          announcement: 'announcement',
        ),
        view(
          price: 'price',
          summary: 's' * (seoConfiguratorMaxSummaryTextLength + 1),
          announcement: 'announcement',
        ),
        view(
          price: 'price',
          summary: 'summary',
          announcement: 'a' * (seoConfiguratorMaxAnnouncementTextLength + 1),
        ),
        view(
          price: 'p' * seoConfiguratorMaxPriceTextLength,
          summary: 's' * seoConfiguratorMaxSummaryTextLength,
          announcement: 'a' *
              (seoConfiguratorMaxAggregateTextLength -
                  seoConfiguratorMaxPriceTextLength -
                  seoConfiguratorMaxSummaryTextLength +
                  1),
        ),
        view(
          price: '\u202E' * (seoConfiguratorMaxPriceTextLength + 1),
          summary: 'summary',
          announcement: 'announcement',
        ),
        view(price: '\u202E', summary: 'summary', announcement: 'announcement'),
        view(
          price: String.fromCharCode(0xD800),
          summary: 'summary',
          announcement: 'announcement',
        ),
        view(
          price: String.fromCharCode(0xDC00),
          summary: 'summary',
          announcement: 'announcement',
        ),
      ]) {
        expect(
          evaluateInitialSeoConfiguratorView(
            (_) => invalid,
            state,
            _constraints,
          ),
          isNull,
        );
      }
    });
  });

  group('atomic application boundary', () {
    test('reproduces the frozen pricing sequence', () {
      const state = SeoConfiguratorState(
        choiceIndex: 0,
        quantity: 1,
        optionEnabled: false,
      );
      var current = evaluateInitialSeoConfiguratorView(
        _pricingView,
        state,
        _constraints,
      )!;
      const actions = <SeoConfiguratorAction>[
        SeoConfiguratorSelectChoice(1),
        SeoConfiguratorIncrementQuantity(),
        SeoConfiguratorIncrementQuantity(),
        SeoConfiguratorSetOption(true),
        SeoConfiguratorSelectChoice(2),
        SeoConfiguratorDecrementQuantity(),
      ];
      const expectedPrices = [
        '49,00 EUR pro Monat',
        '56,00 EUR pro Monat',
        '63,00 EUR pro Monat',
        '78,00 EUR pro Monat',
        '124,00 EUR pro Monat',
        '119,00 EUR pro Monat',
      ];

      for (var index = 0; index < actions.length; index++) {
        final result = evaluateSeoConfiguratorAction(
          transition: transitionSeoConfigurator,
          project: _pricingView,
          current: current,
          action: actions[index],
          constraints: _constraints,
        );
        expect(result, isNotNull);
        expect(result!.accepted, isTrue);
        expect(result.view.priceText, expectedPrices[index]);
        current = result;
      }
      expect(
        current.state,
        const SeoConfiguratorState(
          choiceIndex: 2,
          quantity: 2,
          optionEnabled: true,
        ),
      );
    });

    test('does not call application code for inadmissible controls', () {
      var transitions = 0;
      var projections = 0;
      SeoConfiguratorState transition(
        SeoConfiguratorState state,
        SeoConfiguratorAction action,
        SeoConfiguratorConstraints constraints,
      ) {
        transitions++;
        return transitionSeoConfigurator(state, action, constraints);
      }

      const minimum = SeoConfiguratorState(
        choiceIndex: 0,
        quantity: 1,
        optionEnabled: false,
      );
      final current = evaluateInitialSeoConfiguratorView(
        (state) {
          projections++;
          return _pricingView(state);
        },
        minimum,
        _constraints,
      )!;
      projections = 0;
      for (final action in const <SeoConfiguratorAction>[
        SeoConfiguratorSelectChoice(-1),
        SeoConfiguratorSelectChoice(3),
        SeoConfiguratorDecrementQuantity(),
      ]) {
        final result = evaluateSeoConfiguratorAction(
          transition: transition,
          project: (state) {
            projections++;
            return _pricingView(state);
          },
          current: current,
          action: action,
          constraints: _constraints,
        );
        expect(result!.accepted, isFalse);
        expect(result.state, minimum);
      }
      expect(transitions, 0);
      expect(projections, 0);
    });

    test('does not project or announce a no-op candidate twice', () {
      var transitions = 0;
      var projections = 0;
      SeoConfiguratorState transition(
        SeoConfiguratorState state,
        SeoConfiguratorAction action,
        SeoConfiguratorConstraints constraints,
      ) {
        transitions++;
        return transitionSeoConfigurator(state, action, constraints);
      }

      SeoConfiguratorView project(SeoConfiguratorState state) {
        projections++;
        return _pricingView(state);
      }

      const state = SeoConfiguratorState(
        choiceIndex: 1,
        quantity: 2,
        optionEnabled: true,
      );
      final current = evaluateInitialSeoConfiguratorView(
        project,
        state,
        _constraints,
      )!;
      projections = 0;
      for (final action in const <SeoConfiguratorAction>[
        SeoConfiguratorSelectChoice(1),
        SeoConfiguratorSetOption(true),
      ]) {
        final result = evaluateSeoConfiguratorAction(
          transition: transition,
          project: project,
          current: current,
          action: action,
          constraints: _constraints,
        );

        expect(result!.accepted, isFalse);
        expect(result.state, state);
      }
      expect(transitions, 0);
      expect(projections, 0);
    });

    test('rejects state, exception and view failure without partial output',
        () {
      const current = SeoConfiguratorState(
        choiceIndex: 0,
        quantity: 1,
        optionEnabled: false,
      );
      final expected = evaluateInitialSeoConfiguratorView(
        _pricingView,
        current,
        _constraints,
      )!;

      final transitions = <SeoConfiguratorTransition>[
        (_, __, ___) => const SeoConfiguratorState(
              choiceIndex: 3,
              quantity: 1,
              optionEnabled: false,
            ),
        (_, __, ___) => const SeoConfiguratorState(
              choiceIndex: 1,
              quantity: 21,
              optionEnabled: false,
            ),
        (_, __, ___) => throw StateError('transition failed'),
      ];
      for (final transition in transitions) {
        expect(
          evaluateSeoConfiguratorAction(
            transition: transition,
            project: _pricingView,
            current: expected,
            action: const SeoConfiguratorSelectChoice(1),
            constraints: _constraints,
          ),
          expected,
        );
      }

      SeoConfiguratorView inconsistentProject(SeoConfiguratorState state) =>
          SeoConfiguratorView(
            priceText: state.choiceIndex == 0 ? '19,00 EUR' : '49,00 EUR',
            summaryText: 'Summary',
            announcementText: 'Announcement',
            activeChoiceRegion: 0,
            optionRegionVisible: false,
          );
      final expectedForProjection = evaluateInitialSeoConfiguratorView(
        inconsistentProject,
        current,
        _constraints,
      )!;
      final invalidView = evaluateSeoConfiguratorAction(
        transition: transitionSeoConfigurator,
        project: inconsistentProject,
        current: expectedForProjection,
        action: const SeoConfiguratorSelectChoice(1),
        constraints: _constraints,
      );
      expect(invalidView, expectedForProjection);
    });

    test('rejects a stale or non-canonical current snapshot', () {
      const state = SeoConfiguratorState(
        choiceIndex: 0,
        quantity: 1,
        optionEnabled: false,
      );
      const stale = SeoConfiguratorEvaluation(
        state: state,
        view: SeoConfiguratorView(
          priceText: '1\u202E9,00 EUR',
          summaryText: 'Solo',
          announcementText: '19,00 EUR',
          activeChoiceRegion: 0,
          optionRegionVisible: false,
        ),
        accepted: true,
      );

      expect(
        evaluateSeoConfiguratorAction(
          transition: transitionSeoConfigurator,
          project: _pricingView,
          current: stale,
          action: const SeoConfiguratorSelectChoice(1),
          constraints: _constraints,
        ),
        isNull,
      );
    });
  });
}
