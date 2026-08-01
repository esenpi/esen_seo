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
  });
}
