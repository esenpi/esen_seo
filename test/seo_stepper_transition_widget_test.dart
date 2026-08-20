import 'package:esen_seo/esen_seo.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  List<SeoStep> steps() => [
        for (var index = 0; index < 3; index++)
          SeoStep(
            label: 'Step $index',
            content: Text('Body $index'),
            nodes: [SeoNode(tag: 'p', text: 'Body $index')],
          ),
      ];

  testWidgets('Flutter follows the shared stepper transition sequence',
      (tester) async {
    final values = steps();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SeoStepper(steps: values, initialIndex: 1),
      ),
    );

    var expected = initialSeoStepperState(count: values.length, index: 1);
    expect(find.text('Body ${expected.index}'), findsOneWidget);

    for (final selected in const [2, 0, 1, 1]) {
      expected = transitionSeoStepper(
        expected,
        SeoStepperSelect(selected),
      );
      await tester.tap(find.text('Step $selected'));
      await tester.pump();

      for (var index = 0; index < values.length; index++) {
        expect(
          find.text('Body $index'),
          index == expected.index ? findsOneWidget : findsNothing,
        );
      }
    }
  });

  testWidgets('Flutter delegates selection to an application transition',
      (tester) async {
    SeoStepperState keepFirst(
      SeoStepperState state,
      SeoStepperAction action,
    ) =>
        SeoStepperState(index: 0, count: state.count);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SeoStepper(
          transition: keepFirst,
          steps: steps(),
        ),
      ),
    );

    await tester.tap(find.text('Step 2'));
    await tester.pump();

    expect(find.text('Body 0'), findsOneWidget);
    expect(find.text('Body 2'), findsNothing);
  });

  testWidgets('Flutter control availability follows the application transition',
      (tester) async {
    SeoStepperState wrap(
      SeoStepperState state,
      SeoStepperAction action,
    ) {
      if (action is SeoStepperPrevious && state.index == 0) {
        return SeoStepperState(index: state.count - 1, count: state.count);
      }
      return transitionSeoStepper(state, action);
    }

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SeoStepper(
          transition: wrap,
          steps: steps(),
        ),
      ),
    );

    await tester.tap(find.text('Back'));
    await tester.pump();

    expect(find.text('Body 2'), findsOneWidget);
    expect(find.text('Body 0'), findsNothing);
  });

  testWidgets('Flutter applies a focus effect after the accepted state',
      (tester) async {
    SeoStepperEffectResult focusAfterChange(
      SeoStepperState state,
      SeoStepperAction action,
    ) {
      final next = transitionSeoStepper(state, action);
      return SeoStepperEffectResult(
        state: next,
        effect: next == state ? null : const SeoStepperFocusActivePanel(),
      );
    }

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SeoStepper.withEffects(
          effectTransition: focusAfterChange,
          steps: steps(),
        ),
      ),
    );

    expect(
      tester.binding.focusManager.primaryFocus?.debugLabel,
      isNot('SeoStepper active panel'),
    );
    await tester.tap(find.text('Next'));
    await tester.pump();

    expect(find.text('Body 1'), findsOneWidget);
    expect(
      tester.binding.focusManager.primaryFocus?.debugLabel,
      'SeoStepper active panel',
    );
  });

  testWidgets('Flutter rejects invalid effect output atomically',
      (tester) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SeoStepper.withEffects(
          effectTransition: (state, action) => SeoStepperEffectResult(
            state: SeoStepperState(index: state.count, count: state.count),
            effect: const SeoStepperFocusActivePanel(),
          ),
          steps: steps(),
        ),
      ),
    );

    await tester.tap(find.text('Next'));
    await tester.pump();

    expect(find.text('Body 0'), findsOneWidget);
    expect(find.text('Body 1'), findsNothing);
    expect(
      tester.binding.focusManager.primaryFocus?.debugLabel,
      isNot('SeoStepper active panel'),
    );
  });
}
