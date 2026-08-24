import 'dart:ui' show SemanticsFlag;

import 'package:esen_seo/esen_seo.dart';
import 'package:esen_seo/src/components/seo_configurator_transition.dart';
import 'package:esen_seo/src/widgets/seo_configurator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsData;
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

const _constraints = SeoConfiguratorConstraints(
  choiceCount: 3,
  minQuantity: 1,
  maxQuantity: 20,
);

const _initialState = SeoConfiguratorState(
  choiceIndex: 0,
  quantity: 1,
  optionEnabled: false,
);

SeoConfiguratorView _pricingView(SeoConfiguratorState state) {
  const base = [1900, 4900, 9900];
  const additional = [900, 700, 500];
  final cents = base[state.choiceIndex] +
      (state.quantity - 1) * additional[state.choiceIndex] +
      (state.optionEnabled ? 1500 : 0);
  return SeoConfiguratorView(
    priceText: '${cents ~/ 100} EUR',
    summaryText:
        'Plan ${state.choiceIndex + 1}, ${state.quantity} sites, support '
        '${state.optionEnabled ? "on" : "off"}',
    announcementText: 'Price ${cents ~/ 100} EUR',
    activeChoiceRegion: state.choiceIndex,
    optionRegionVisible: state.optionEnabled,
  );
}

List<SeoConfiguratorChoice> _choices() => [
      for (var index = 0; index < 3; index++)
        SeoConfiguratorChoice(
          label: const ['Solo', 'Team', 'Agency'][index],
          content: Text('Flutter description $index'),
          nodes: [SeoNode(tag: 'p', text: 'Semantic description $index')],
        ),
    ];

SeoConfigurator _widget({
  Key? key,
  SeoConfiguratorTransition transition = transitionSeoConfigurator,
  ValueChanged<SeoConfiguratorEvaluation>? onChanged,
  SeoConfiguratorState initialState = _initialState,
}) =>
    SeoConfigurator(
      key: key,
      choices: _choices(),
      optionContent: const Text('Flutter support details'),
      optionNodes: [SeoNode(tag: 'p', text: 'Semantic support details')],
      constraints: _constraints,
      initialState: initialState,
      project: _pricingView,
      transition: transition,
      interactionId: 'cms-pricing-configurator',
      heading: 'Choose a subscription',
      interactionLabel: 'Subscription calculator',
      choiceGroupLabel: 'Subscriptions',
      quantityLabel: 'Sites',
      optionLabel: 'Priority support',
      priceLabel: 'Price',
      decrementLabel: 'Remove one site',
      incrementLabel: 'Add one site',
      onChanged: onChanged,
    );

Future<void> _pump(WidgetTester tester, SeoConfigurator widget) => pumpSeo(
      tester,
      MaterialApp(home: Scaffold(body: widget)),
    );

bool _hasFlag(SemanticsData data, SemanticsFlag flag) {
  // Flutter 3.27 does not expose SemanticsData.flagsCollection yet.
  // ignore: deprecated_member_use
  return data.hasFlag(flag);
}

void main() {
  setUp(enableSeoForTests);

  testWidgets('native initial view and complete semantic source share data',
      (tester) async {
    await _pump(tester, _widget());

    expect(find.text('Price: 19 EUR'), findsOneWidget);
    expect(find.text('Flutter description 0'), findsOneWidget);
    expect(find.text('Flutter description 1'), findsNothing);
    expect(find.text('Flutter support details'), findsNothing);
    expect(EsenSeo.currentHtml, contains('<p>Semantic description 0</p>'));
    expect(EsenSeo.currentHtml, contains('<p>Semantic description 1</p>'));
    expect(EsenSeo.currentHtml, contains('<p>Semantic description 2</p>'));
    expect(EsenSeo.currentHtml, contains('<p>Semantic support details</p>'));
    expect(EsenSeo.currentHtml, contains('>19 EUR</span>'));
  });

  testWidgets('frozen action sequence follows the shared validated snapshots',
      (tester) async {
    final changes = <SeoConfiguratorEvaluation>[];
    await _pump(tester, _widget(onChanged: changes.add));

    await tester.tap(find.widgetWithText(OutlinedButton, 'Team'));
    await tester.pump();
    expect(find.text('Price: 49 EUR'), findsOneWidget);

    await tester.tap(find.byTooltip('Add one site'));
    await tester.pump();
    await tester.tap(find.byTooltip('Add one site'));
    await tester.pump();
    expect(find.text('Price: 63 EUR'), findsOneWidget);

    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(find.text('Price: 78 EUR'), findsOneWidget);
    expect(find.text('Flutter support details'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Agency'));
    await tester.pump();
    expect(find.text('Price: 124 EUR'), findsOneWidget);

    await tester.tap(find.byTooltip('Remove one site'));
    await tester.pump();
    expect(find.text('Price: 119 EUR'), findsOneWidget);

    expect(
      changes.map((entry) => entry.state).toList(),
      const [
        SeoConfiguratorState(
          choiceIndex: 1,
          quantity: 1,
          optionEnabled: false,
        ),
        SeoConfiguratorState(
          choiceIndex: 1,
          quantity: 2,
          optionEnabled: false,
        ),
        SeoConfiguratorState(
          choiceIndex: 1,
          quantity: 3,
          optionEnabled: false,
        ),
        SeoConfiguratorState(
          choiceIndex: 1,
          quantity: 3,
          optionEnabled: true,
        ),
        SeoConfiguratorState(
          choiceIndex: 2,
          quantity: 3,
          optionEnabled: true,
        ),
        SeoConfiguratorState(
          choiceIndex: 2,
          quantity: 2,
          optionEnabled: true,
        ),
      ],
    );
  });

  testWidgets('rejected application output leaves native view atomic',
      (tester) async {
    final changes = <SeoConfiguratorEvaluation>[];
    SeoConfiguratorState dishonestTransition(
      SeoConfiguratorState state,
      SeoConfiguratorAction action,
      SeoConfiguratorConstraints constraints,
    ) =>
        const SeoConfiguratorState(
          choiceIndex: 99,
          quantity: 99,
          optionEnabled: true,
        );

    await _pump(
      tester,
      _widget(transition: dishonestTransition, onChanged: changes.add),
    );
    await tester.tap(find.widgetWithText(OutlinedButton, 'Team'));
    await tester.pump();

    expect(find.text('Price: 19 EUR'), findsOneWidget);
    expect(find.text('Flutter description 0'), findsOneWidget);
    expect(find.text('Flutter description 1'), findsNothing);
    expect(changes, isEmpty);
  });

  testWidgets('quantity controls enforce closed boundaries', (tester) async {
    await _pump(
      tester,
      _widget(
        initialState: const SeoConfiguratorState(
          choiceIndex: 0,
          quantity: 1,
          optionEnabled: false,
        ),
      ),
    );

    expect(
      tester
          .widget<IconButton>(
            find.ancestor(
              of: find.byTooltip('Remove one site'),
              matching: find.byType(IconButton),
            ),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<IconButton>(
            find.ancestor(
              of: find.byTooltip('Add one site'),
              matching: find.byType(IconButton),
            ),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('choice controls expose mutually exclusive semantics',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, _widget());

    final solo = tester
        .getSemantics(find.widgetWithText(OutlinedButton, 'Solo'))
        .getSemanticsData();
    final team = tester
        .getSemantics(find.widgetWithText(OutlinedButton, 'Team'))
        .getSemanticsData();
    expect(_hasFlag(solo, SemanticsFlag.isButton), isTrue);
    expect(_hasFlag(solo, SemanticsFlag.isSelected), isTrue);
    expect(_hasFlag(solo, SemanticsFlag.hasCheckedState), isTrue);
    expect(_hasFlag(solo, SemanticsFlag.isChecked), isTrue);
    expect(_hasFlag(solo, SemanticsFlag.isInMutuallyExclusiveGroup), isTrue);
    expect(_hasFlag(team, SemanticsFlag.isButton), isTrue);
    expect(_hasFlag(team, SemanticsFlag.isSelected), isFalse);
    expect(_hasFlag(team, SemanticsFlag.hasCheckedState), isTrue);
    expect(_hasFlag(team, SemanticsFlag.isChecked), isFalse);
    expect(_hasFlag(team, SemanticsFlag.isInMutuallyExclusiveGroup), isTrue);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Team'));
    await tester.pump();

    final selectedTeam = tester
        .getSemantics(find.widgetWithText(OutlinedButton, 'Team'))
        .getSemanticsData();
    expect(_hasFlag(selectedTeam, SemanticsFlag.isSelected), isTrue);
    expect(_hasFlag(selectedTeam, SemanticsFlag.isChecked), isTrue);
    semantics.dispose();
  });

  testWidgets('live announcement does not replace readable price semantics',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, _widget());

    await tester.tap(find.widgetWithText(OutlinedButton, 'Team'));
    await tester.pump();

    final announcement = tester
        .getSemantics(find.bySemanticsLabel('Price 49 EUR'))
        .getSemanticsData();
    final price =
        tester.getSemantics(find.text('Price: 49 EUR')).getSemanticsData();
    expect(_hasFlag(announcement, SemanticsFlag.isLiveRegion), isTrue);
    expect(price.label, 'Price: 49 EUR');
    semantics.dispose();
  });

  testWidgets('semantic HTML remains initial while Flutter state changes',
      (tester) async {
    await _pump(tester, _widget());
    final initialHtml = EsenSeo.currentHtml;

    await tester.tap(find.widgetWithText(OutlinedButton, 'Team'));
    await tester.pump();
    EsenSeo.refresh();

    expect(find.text('Price: 49 EUR'), findsOneWidget);
    expect(EsenSeo.currentHtml.codeUnits, initialHtml.codeUnits);
  });

  testWidgets('initial projection is reused by Flutter and semantic output',
      (tester) async {
    var projections = 0;
    SeoConfiguratorView project(SeoConfiguratorState state) {
      projections++;
      return _pricingView(state);
    }

    await _pump(
      tester,
      SeoConfigurator(
        choices: _choices(),
        optionContent: const Text('Option'),
        optionNodes: const [],
        constraints: _constraints,
        initialState: _initialState,
        project: project,
        interactionId: 'projection-count',
      ),
    );

    expect(projections, 1);
    expect(find.text('Estimated price: 19 EUR'), findsOneWidget);
    expect(EsenSeo.currentHtml, contains('>19 EUR</span>'));
  });

  testWidgets('reselecting current values invokes no application code',
      (tester) async {
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

    await _pump(
      tester,
      SeoConfigurator(
        choices: _choices(),
        optionContent: const Text('Option'),
        optionNodes: const [],
        constraints: _constraints,
        initialState: _initialState,
        project: project,
        transition: transition,
      ),
    );
    projections = 0;

    await tester.tap(find.widgetWithText(OutlinedButton, 'Solo'));
    await tester.pump();

    expect(transitions, 0);
    expect(projections, 0);
    expect(find.text('Estimated price: 19 EUR'), findsOneWidget);
  });

  testWidgets('parent updates preserve state until initial identity changes',
      (tester) async {
    const key = ValueKey('pricing-configurator');
    await _pump(tester, _widget(key: key));
    await tester.tap(find.widgetWithText(OutlinedButton, 'Team'));
    await tester.pump();
    expect(find.text('Price: 49 EUR'), findsOneWidget);

    await _pump(tester, _widget(key: key));
    expect(find.text('Price: 49 EUR'), findsOneWidget);

    await _pump(
      tester,
      _widget(
        key: key,
        initialState: const SeoConfiguratorState(
          choiceIndex: 2,
          quantity: 2,
          optionEnabled: true,
        ),
      ),
    );
    expect(find.text('Price: 119 EUR'), findsOneWidget);
    expect(find.text('Flutter description 2'), findsOneWidget);
    expect(find.text('Flutter support details'), findsOneWidget);
  });
}
