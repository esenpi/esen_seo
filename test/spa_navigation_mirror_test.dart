// The SPA gap: `markDirty` fires on SeoWidget mount/update/dispose, so
// the post-frame refresh after a push runs DURING the route transition
// — while the outgoing route is still onstage. When the transition
// finishes and the Navigator finally puts the old route Offstage,
// nothing marks the mirror dirty again: no widget mounted, updated or
// disposed at that moment. The mirror keeps serving the previous
// page's HTML to a URL, title and canonical that all say otherwise.
import 'package:esen_seo/esen_seo.dart';
import 'package:esen_seo/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(enableSeoForParity);

  Widget app(GlobalKey<NavigatorState> navigator) => MaterialApp(
        navigatorKey: navigator,
        routes: {
          '/': (_) => Scaffold(body: Text('Startseite Willkommen').h1),
          '/demo': (_) => Scaffold(body: Text('Live Demo Seite').h1),
        },
      );

  testWidgets('after pushNamed the mirror shows the new page, not the old',
      (tester) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(app(navigator));
    await tester.pumpAndSettle();
    EsenSeo.refresh();
    expect(EsenSeo.currentHtml, contains('Startseite Willkommen'));

    navigator.currentState!.pushNamed('/demo');
    await tester.pumpAndSettle(); // transition fully completed

    expect(
      EsenSeo.currentHtml,
      contains('Live Demo Seite'),
      reason: 'the visible page is /demo — the mirror must say so too',
    );
    expect(
      EsenSeo.currentHtml,
      isNot(contains('Startseite Willkommen')),
      reason: 'the old route is Offstage after the transition and must '
          'not leak into the mirror',
    );
  });

  testWidgets('after pop the mirror returns to the previous page',
      (tester) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(app(navigator));
    await tester.pumpAndSettle();

    navigator.currentState!.pushNamed('/demo');
    await tester.pumpAndSettle();
    navigator.currentState!.pop();
    await tester.pumpAndSettle();

    expect(EsenSeo.currentHtml, contains('Startseite Willkommen'));
    expect(EsenSeo.currentHtml, isNot(contains('Live Demo Seite')));
  });
}
