import 'package:esen_seo/esen_seo.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

class _BuildProbe extends StatelessWidget {
  const _BuildProbe(this.index, this.onBuild);

  final int index;
  final ValueChanged<int> onBuild;

  @override
  Widget build(BuildContext context) {
    onBuild(index);
    return Text('Flutter body $index');
  }
}

class _LifecycleProbe extends StatefulWidget {
  const _LifecycleProbe(this.index, this.onInit, this.onDispose);

  final int index;
  final ValueChanged<int> onInit;
  final ValueChanged<int> onDispose;

  @override
  State<_LifecycleProbe> createState() => _LifecycleProbeState();
}

class _LifecycleProbeState extends State<_LifecycleProbe> {
  @override
  void initState() {
    super.initState();
    widget.onInit(widget.index);
  }

  @override
  void dispose() {
    widget.onDispose(widget.index);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text('State ${widget.index}');
}

void main() {
  setUp(enableSeoForTests);

  final steps = [
    SeoStep(
      label: 'Account',
      content: const Text('Flutter account'),
      nodes: [SeoNode(tag: 'p', text: 'Semantic account')],
    ),
    SeoStep(
      label: 'Address',
      content: const Text('Flutter address'),
      nodes: [SeoNode(tag: 'p', text: 'Semantic address')],
    ),
    SeoStep(
      label: 'Review',
      content: const Text('Flutter review'),
      nodes: [SeoNode(tag: 'p', text: 'Semantic review')],
    ),
  ];

  testWidgets('mirrors every step independently of the Flutter state',
      (tester) async {
    final changes = <int>[];
    await pumpSeo(
      tester,
      SeoStepper(
        steps: steps,
        interactionId: 'checkout-steps',
        interactionLabel: 'Checkout',
        onStepChanged: changes.add,
      ),
    );
    final initialHtml = EsenSeo.currentHtml;

    expect(find.text('Flutter account'), findsOneWidget);
    expect(find.text('Flutter address'), findsNothing);
    expect(initialHtml, contains('<h3>Account</h3>'));
    expect(initialHtml, contains('<h3>Address</h3>'));
    expect(initialHtml, contains('<h3>Review</h3>'));
    expect(initialHtml, contains('<p>Semantic review</p>'));
    expect(initialHtml, isNot(contains('<button')));

    await tester.tap(find.text('Address'));
    await tester.pump();
    EsenSeo.refresh();

    expect(find.text('Flutter address'), findsOneWidget);
    expect(changes, [1]);
    expect(EsenSeo.currentHtml, initialHtml);
  });

  testWidgets('unvisited bodies stay lazy and visited state remains mounted',
      (tester) async {
    final initialized = <int>[];
    final disposed = <int>[];
    final lifecycleSteps = [
      for (var index = 0; index < 3; index++)
        SeoStep(
          label: 'Step $index',
          content: _LifecycleProbe(index, initialized.add, disposed.add),
          nodes: [SeoNode(tag: 'p', text: 'Semantic $index')],
        ),
    ];

    await pumpSeo(tester, SeoStepper(steps: lifecycleSteps));
    expect(initialized, [0]);
    expect(disposed, isEmpty);

    await tester.tap(find.text('Next'));
    await tester.pump();
    expect(initialized, [0, 1]);
    expect(disposed, isEmpty);

    await tester.tap(find.text('Back'));
    await tester.pump();
    expect(initialized, [0, 1]);
    expect(disposed, isEmpty);
    expect(find.text('State 0'), findsOneWidget);
    expect(find.text('State 1'), findsNothing);
    expect(find.text('State 1', skipOffstage: false), findsOneWidget);
  });

  testWidgets('inactive visited bodies cannot retain focus', (tester) async {
    final firstFocus = FocusNode();
    final secondFocus = FocusNode();
    addTearDown(firstFocus.dispose);
    addTearDown(secondFocus.dispose);
    final focusSteps = [
      SeoStep(
        label: 'First',
        content: Focus(
          focusNode: firstFocus,
          child: const Text('First focus target'),
        ),
        nodes: [SeoNode(tag: 'p', text: 'First semantic')],
      ),
      SeoStep(
        label: 'Second',
        content: Focus(
          focusNode: secondFocus,
          child: const Text('Second focus target'),
        ),
        nodes: [SeoNode(tag: 'p', text: 'Second semantic')],
      ),
    ];

    await pumpSeo(tester, SeoStepper(steps: focusSteps));
    firstFocus.requestFocus();
    await tester.pump();
    expect(firstFocus.hasFocus, isTrue);

    await tester.tap(find.text('Next'));
    await tester.pump();

    expect(firstFocus.hasFocus, isFalse);
    expect(firstFocus.canRequestFocus, isFalse);
    expect(secondFocus.canRequestFocus, isTrue);
  });

  testWidgets('distant bodies stay unbuilt while their HTML is immediate',
      (tester) async {
    final built = <int>{};
    final manySteps = [
      for (var index = 0; index < 20; index++)
        SeoStep(
          label: 'Step $index',
          content: _BuildProbe(index, built.add),
          nodes: [SeoNode(tag: 'p', text: 'Semantic body $index')],
        ),
    ];

    await pumpSeo(tester, SeoStepper(steps: manySteps));

    expect(built, contains(0));
    expect(built, isNot(contains(19)));
    expect(EsenSeo.currentHtml, contains('<h3>Step 19</h3>'));
    expect(EsenSeo.currentHtml, contains('<p>Semantic body 19</p>'));
  });

  testWidgets('initial index is clamped and controls respect boundaries',
      (tester) async {
    final changes = <int>[];
    await pumpSeo(
      tester,
      SeoStepper(
        steps: steps,
        initialIndex: 99,
        onStepChanged: changes.add,
      ),
    );

    expect(find.text('Flutter review'), findsOneWidget);
    expect(find.text('3 / 3'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pump();
    expect(changes, isEmpty);

    await tester.tap(find.text('Back'));
    await tester.pump();
    expect(find.text('Flutter address'), findsOneWidget);
    expect(changes, [1]);
  });

  testWidgets('replacement data resets visited bodies to the requested step',
      (tester) async {
    const key = ValueKey('stepper');
    await pumpSeo(
      tester,
      SeoStepper(key: key, steps: steps, initialIndex: 2),
    );
    expect(find.text('Flutter review'), findsOneWidget);

    final replacements = [
      SeoStep(
        label: 'New first',
        content: const Text('New first body'),
        nodes: [SeoNode(tag: 'p', text: 'New first semantic')],
      ),
      SeoStep(
        label: 'New second',
        content: const Text('New second body'),
        nodes: [SeoNode(tag: 'p', text: 'New second semantic')],
      ),
    ];
    await pumpSeo(
      tester,
      SeoStepper(key: key, steps: replacements, initialIndex: 0),
    );

    expect(find.text('New first body'), findsOneWidget);
    expect(find.text('Flutter review', skipOffstage: false), findsNothing);
    expect(EsenSeo.currentHtml, contains('<h3>New second</h3>'));
  });

  testWidgets('a single step needs no Flutter controls', (tester) async {
    await pumpSeo(tester, SeoStepper(steps: [steps.first]));

    expect(find.text('Flutter account'), findsOneWidget);
    expect(find.text('Back'), findsNothing);
    expect(find.text('Next'), findsNothing);
    expect(EsenSeo.currentHtml, contains('<ol><li><h3>Account</h3>'));
  });

  testWidgets('narrow layouts scroll labels and keep controls contained',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(140, 500));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpSeo(
      tester,
      SeoStepper(
        steps: steps,
        previousLabel: 'A very long previous label',
        nextLabel: 'A very long next label',
      ),
    );

    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty input renders and mirrors nothing', (tester) async {
    await pumpSeo(tester, const SeoStepper(steps: []));

    expect(find.byType(Stack), findsNothing);
    expect(EsenSeo.currentHtml, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
