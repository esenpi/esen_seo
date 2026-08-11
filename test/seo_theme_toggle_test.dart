import 'package:esen_seo/esen_seo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pure builder emits an inert, bounded component marker', () {
    final html = const HtmlRenderer().render(
      buildSeoThemeToggleNodes(
        lightLabel: 'Hell',
        darkLabel: 'Dunkel',
        lightSemanticLabel: 'Hellen Modus aktivieren',
        darkSemanticLabel: 'Dunklen Modus aktivieren',
      ),
    );

    expect(html, contains('data-esen-component="theme-toggle"'));
    expect(html, isNot(contains(' id=')));
    expect(html, contains('hidden'));
    expect(html, isNot(contains('<button')));
    expect(html, isNot(contains('<script')));
  });

  test('blank and oversized labels remain inert', () {
    final blank = const HtmlRenderer().render(
      buildSeoThemeToggleNodes(lightLabel: '   '),
    );
    final oversized = const HtmlRenderer().render(
      buildSeoThemeToggleNodes(darkLabel: 'x' * 161),
    );

    expect(blank, isNot(contains('data-esen-component')));
    expect(oversized, isNot(contains('data-esen-component')));
    expect(blank, contains('hidden'));
    expect(oversized, contains('hidden'));
  });

  test('compact behavior is declared in the shared component marker', () {
    final html = const HtmlRenderer().render(
      buildSeoThemeToggleNodes(compactOnSmallScreens: true),
    );

    expect(html, contains('data-esen-compact="true"'));
    expect(
      seoDomFirstThemeToggleStylesheet,
      contains('@media (max-width:600px)'),
    );
  });

  testWidgets('Flutter control reports the next resolved brightness',
      (tester) async {
    bool? requested;
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SeoThemeToggle(
            isDark: false,
            onChanged: (value) => requested = value,
            lightLabel: 'Hell',
            darkLabel: 'Dunkel',
            lightSemanticLabel: 'Hellen Modus aktivieren',
            darkSemanticLabel: 'Dunklen Modus aktivieren',
          ),
        ),
      ),
    );

    expect(find.text('Dunkel'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Dunklen Modus aktivieren'),
      findsOneWidget,
    );
    await tester.tap(find.text('Dunkel'));
    expect(requested, isTrue);
    semantics.dispose();
  });

  testWidgets('compact Flutter control keeps only the symbol on mobile',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SeoThemeToggle(
            isDark: false,
            onChanged: (_) {},
            darkLabel: 'Dunkel',
            darkSemanticLabel: 'Dunklen Modus aktivieren',
            compactOnSmallScreens: true,
          ),
        ),
      ),
    );

    expect(find.text('Dunkel'), findsNothing);
    expect(find.text('\u263e'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Dunklen Modus aktivieren'),
      findsOneWidget,
    );
    expect(tester.getSize(find.byType(OutlinedButton)), const Size(48, 48));
    semantics.dispose();
  });
}
