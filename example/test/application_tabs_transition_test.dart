import 'package:esen_seo/core.dart';
import 'package:example/application_tabs_transition.dart';
import 'package:example/seo_routes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('application tabs stop at both ends', () {
    expect(
      transitionExampleTabs(
        const SeoTabsState(index: 0, count: 3),
        const SeoTabsPrevious(),
      ),
      const SeoTabsState(index: 0, count: 3),
    );
    expect(
      transitionExampleTabs(
        const SeoTabsState(index: 2, count: 3),
        const SeoTabsNext(),
      ),
      const SeoTabsState(index: 2, count: 3),
    );
  });

  test('DOM-first route selects the compiled identity once', () {
    final route = seoRoutes.singleWhere(
      (route) => route.path == '/dom-first-application-tabs',
    );

    expect(route.delivery, SeoRouteDelivery.domFirst);
    expect(
      route.applicationRuntime,
      const SeoDomFirstApplicationRuntime.tabs('example-tabs'),
    );
    expect(route.domFirstFeatures, isEmpty);
  });
}
