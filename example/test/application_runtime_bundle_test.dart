import 'package:esen_seo/core.dart';
import 'package:example/application_carousel_transition.dart';
import 'package:example/application_stepper_transition.dart';
import 'package:example/application_tabs_transition.dart';
import 'package:example/seo_routes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bundle route binds three independent application state slices', () {
    final route = seoRoutes.singleWhere(
      (candidate) => candidate.path == '/dom-first-application-bundle',
    );
    final runtime = route.applicationRuntime!;

    expect(route.delivery, SeoRouteDelivery.domFirst);
    expect(runtime.kind, 'bundle');
    expect(
      runtime.memberKinds,
      const [
        SeoDomFirstApplicationRuntimeKind.tabs,
        SeoDomFirstApplicationRuntimeKind.carousel,
        SeoDomFirstApplicationRuntimeKind.stepperEffects,
      ],
    );

    expect(
      transitionExampleTabs(
        const SeoTabsState(index: 0, count: 3),
        const SeoTabsNext(),
      ).index,
      1,
    );
    expect(
      transitionExampleCarousel(
        const SeoCarouselState(index: 0, count: 3),
        const SeoCarouselPrevious(),
      ).index,
      2,
    );
    final stepper = transitionExampleStepperEffects(
      const SeoStepperState(index: 0, count: 3),
      const SeoStepperNext(),
      const SeoStepperEffectContext(
        interactionId: exampleStepperInteractionId,
      ),
    );
    expect(stepper.state.index, 1);
    expect(stepper.effect, isA<SeoStepperFocusActivePanel>());
  });
}
