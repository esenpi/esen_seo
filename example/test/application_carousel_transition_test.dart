import 'package:esen_seo/esen_seo.dart';
import 'package:example/application_carousel_transition.dart';
import 'package:example/seo_routes.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('application carousel wraps at both ends', () {
    expect(
      transitionExampleCarousel(
        const SeoCarouselState(index: 0, count: 3),
        const SeoCarouselPrevious(),
      ),
      const SeoCarouselState(index: 2, count: 3),
    );
    expect(
      transitionExampleCarousel(
        const SeoCarouselState(index: 2, count: 3),
        const SeoCarouselNext(),
      ),
      const SeoCarouselState(index: 0, count: 3),
    );
  });

  test('DOM-first route selects the compiled carousel identity once', () {
    final route = seoRoutes.singleWhere(
      (route) => route.path == '/dom-first-application-carousel',
    );

    expect(route.delivery, SeoRouteDelivery.domFirst);
    expect(
      route.applicationRuntime,
      const SeoDomFirstApplicationRuntime.carousel('example-carousel'),
    );
    expect(route.domFirstFeatures, isEmpty);
  });

  testWidgets('Flutter executes the same wrapping transition', (tester) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SeoCarousel(
          height: 180,
          transition: transitionExampleCarousel,
          slides: [
            for (final slide in demoCarouselSlides)
              SeoCarouselSlide(
                label: slide.label,
                content: Text(slide.content),
                nodes: demoCarouselSlideNodes(slide),
              ),
          ],
        ),
      ),
    );

    await tester.tap(find.text('\u2039'));
    await tester.pumpAndSettle();

    expect(find.text(demoCarouselSlides.last.content), findsOneWidget);
    expect(find.text(demoCarouselSlides.first.content), findsNothing);
  });
}
