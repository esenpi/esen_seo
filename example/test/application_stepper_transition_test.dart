import 'package:esen_seo/esen_seo.dart';
import 'package:example/application_stepper_transition.dart';
import 'package:example/seo_routes.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('application stepper wraps at both ends', () {
    expect(
      transitionExampleStepper(
        const SeoStepperState(index: 0, count: 3),
        const SeoStepperPrevious(),
      ),
      const SeoStepperState(index: 2, count: 3),
    );
    expect(
      transitionExampleStepper(
        const SeoStepperState(index: 2, count: 3),
        const SeoStepperNext(),
      ),
      const SeoStepperState(index: 0, count: 3),
    );
  });

  test('DOM-first route selects the compiled stepper identity once', () {
    final route = seoRoutes.singleWhere(
      (route) => route.path == '/dom-first-application-stepper',
    );

    expect(route.delivery, SeoRouteDelivery.domFirst);
    expect(
      route.applicationRuntime,
      const SeoDomFirstApplicationRuntime.stepper('example-stepper'),
    );
    expect(route.domFirstFeatures, isEmpty);
  });

  testWidgets('Flutter executes the same wrapping transition', (tester) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SeoStepper(
          transition: transitionExampleStepper,
          steps: [
            for (final step in demoStepperSteps)
              SeoStep(
                label: step.label,
                content: Text(step.content),
                nodes: demoStepperBodyNodes(step),
              ),
          ],
        ),
      ),
    );

    await tester.tap(find.text('Back'));
    await tester.pump();

    expect(find.text(demoStepperSteps.last.content), findsOneWidget);
    expect(find.text(demoStepperSteps.first.content), findsNothing);
  });
}
