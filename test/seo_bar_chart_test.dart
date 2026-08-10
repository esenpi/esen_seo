import 'dart:ui' show PointerDeviceKind, SemanticsAction;

import 'package:esen_seo/esen_seo.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

const _data = [
  SeoBarChartEntry('2024', 12),
  SeoBarChartEntry('2025', 31.5),
  SeoBarChartEntry('2026', 54),
];

void main() {
  group('SeoBarChart', () {
    setUp(enableSeoForTests);

    testWidgets('mirrors as figure with CSS bars and a data table',
        (tester) async {
      await pumpSeo(
        tester,
        const SeoBarChart(title: 'Umsatz pro Jahr', data: _data),
      );
      final html = EsenSeo.currentHtml;

      expect(html, contains('<figure class="esen-seo-bar-chart">'));
      expect(html, contains('<figcaption>Umsatz pro Jahr</figcaption>'));

      // Balken: reine Optik, für Screenreader unsichtbar, Höhe relativ
      // zum Maximum (54 → 100%, 12 → 22.2%):
      expect(html, contains('aria-hidden="true"'));
      expect(html, contains('height:100%'));
      expect(html, contains('height:${(12 / 54 * 100).toStringAsFixed(1)}%'));

      // Tabelle trägt die Semantik — echte Werte im Quelltext:
      expect(html, contains('<tr><th>2024</th><td>12</td></tr>'));
      expect(html, contains('<tr><th>2025</th><td>31.5</td></tr>'));
      expect(html, contains('<tr><th>2026</th><td>54</td></tr>'));

      // Die Flutter-Labels spiegeln nicht doppelt (Subtree ersetzt):
      expect('2026'.allMatches(html), hasLength(2)); // Balken-title + Tabelle
    });

    testWidgets('bar color reaches the CSS', (tester) async {
      await pumpSeo(
        tester,
        const SeoBarChart(data: _data, color: Color(0xFFAB12CD)),
      );
      expect(EsenSeo.currentHtml, contains('background:#ab12cd'));
    });

    testWidgets('bar color preserves alpha in CSS order', (tester) async {
      await pumpSeo(
        tester,
        const SeoBarChart(data: _data, color: Color(0x80AB12CD)),
      );
      expect(EsenSeo.currentHtml, contains('background:#ab12cd80'));
    });

    testWidgets('all-zero data renders without division errors',
        (tester) async {
      await pumpSeo(
        tester,
        const SeoBarChart(data: [SeoBarChartEntry('A', 0)]),
      );
      expect(EsenSeo.currentHtml, contains('height:0%'));
      expect(EsenSeo.currentHtml, contains('<td>0</td>'));
    });

    testWidgets('renders as plain Flutter widgets too', (tester) async {
      await pumpSeo(
        tester,
        const SeoBarChart(title: 'Umsatz pro Jahr', data: _data),
      );
      // Titel + Labels sind echte Flutter-Texte auf dem Schirm:
      expect(find.text('Umsatz pro Jahr'), findsOneWidget);
      expect(find.text('2026'), findsOneWidget);
    });

    testWidgets('gentle motion staggers toward the same final geometry',
        (tester) async {
      await pumpSeo(
        tester,
        const SeoBarChart(data: _data, motion: SeoMotionPreset.gentle),
      );

      List<double?> factors() => tester
          .widgetList<FractionallySizedBox>(
            find.byType(FractionallySizedBox),
          )
          .map((widget) => widget.heightFactor)
          .toList();

      expect(factors(), [0, 0, 0]);
      await tester.pump(const Duration(milliseconds: 80));
      final underway = factors();
      expect(underway[0], greaterThan(0));
      expect(underway[1], greaterThan(0));
      expect(underway[2], 0);

      await tester.pumpAndSettle();
      expect(factors()[0], closeTo(12 / 54, 0.0001));
      expect(factors()[1], closeTo(31.5 / 54, 0.0001));
      expect(factors()[2], 1);
    });

    testWidgets('reduced motion renders the final static state immediately',
        (tester) async {
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: SeoBarChart(
              data: _data,
              motion: SeoMotionPreset.gentle,
            ),
          ),
        ),
      );
      EsenSeo.refresh();

      final factors = tester
          .widgetList<FractionallySizedBox>(
            find.byType(FractionallySizedBox),
          )
          .map((widget) => widget.heightFactor)
          .toList();
      expect(factors[0], closeTo(12 / 54, 0.0001));
      expect(factors[1], closeTo(31.5 / 54, 0.0001));
      expect(factors[2], 1);
      expect(find.byType(MouseRegion), findsNothing);
    });

    testWidgets('pointer emphasis is decorative and returns to rest',
        (tester) async {
      await pumpSeo(
        tester,
        const SeoBarChart(data: _data, motion: SeoMotionPreset.gentle),
      );
      await tester.pumpAndSettle();

      final firstBar = find.byType(MouseRegion).first;
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: tester.getCenter(firstBar));
      await mouse.moveTo(tester.getCenter(firstBar));
      await tester.pumpAndSettle();

      final emphasized = tester.widgetList<Opacity>(find.byType(Opacity));
      expect(emphasized.any((widget) => widget.opacity == 0.92), isTrue);

      await mouse.moveTo(Offset.zero);
      await tester.pumpAndSettle();
      final resting = tester.widgetList<Opacity>(find.byType(Opacity));
      expect(resting.every((widget) => widget.opacity == 1), isTrue);
      await mouse.removePointer();
    });

    testWidgets('touch press emphasizes without creating a tap control',
        (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpSeo(
        tester,
        const SeoBarChart(data: _data, motion: SeoMotionPreset.gentle),
      );
      await tester.pumpAndSettle();

      final firstBar = find.byType(MouseRegion).first;
      final touch = await tester.startGesture(
        tester.getCenter(firstBar),
        kind: PointerDeviceKind.touch,
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widgetList<Opacity>(find.byType(Opacity))
            .any((widget) => widget.opacity == 0.92),
        isTrue,
      );

      final labelSemantics = tester.getSemantics(find.text('2024'));
      expect(
        labelSemantics.getSemanticsData().hasAction(SemanticsAction.tap),
        isFalse,
      );

      await touch.up();
      await tester.pumpAndSettle();
      expect(
        tester
            .widgetList<Opacity>(find.byType(Opacity))
            .every((widget) => widget.opacity == 1),
        isTrue,
      );
      semantics.dispose();
    });
  });
}
