import 'package:esen_seo/esen_seo.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  setUp(enableSeoForTests);

  group('SeoPieChart', () {
    const data = [
      SeoPieChartEntry('Flutter', 46),
      SeoPieChartEntry('React Native', 32),
      SeoPieChartEntry('Andere', 22),
    ];

    testWidgets('mirrors as conic-gradient circle plus share table',
        (tester) async {
      await pumpSeo(
        tester,
        const SeoPieChart(title: 'Marktanteile', data: data),
      );
      final html = EsenSeo.currentHtml;

      expect(html, contains('<figure class="esen-seo-pie-chart">'));
      expect(html, contains('<figcaption>Marktanteile</figcaption>'));

      // Reine CSS-Torte, keine Bilder, kein JS:
      expect(html, contains('border-radius:50%'));
      expect(html, contains('conic-gradient(#2563eb 0% 46%'));
      expect(html, contains('#f59e0b 46% 78%'));
      expect(html, contains('#10b981 78% 100%'));

      // Tabelle mit Label, Wert und Anteil:
      expect(html, contains('<tr><th>Flutter</th><td>46</td><td>46%</td>'));
      // Kein doppelter Titel: figcaption ja, table-caption nein.
      expect(html, isNot(contains('<caption>')));
      expect(
        html,
        contains('<tr><th>React Native</th><td>32</td><td>32%</td>'),
      );
    });

    testWidgets('explicit segment colors win over the palette', (tester) async {
      await pumpSeo(
        tester,
        const SeoPieChart(data: [
          SeoPieChartEntry('A', 1, color: Color(0xFF112233)),
          SeoPieChartEntry('B', 1),
        ]),
      );
      expect(EsenSeo.currentHtml, contains('#112233 0% 50%'));
      // Zweites Segment fällt auf die Palette zurück (Index 1):
      expect(EsenSeo.currentHtml, contains('#f59e0b 50% 100%'));
    });

    testWidgets('zero total renders a neutral circle, no gradient',
        (tester) async {
      await pumpSeo(
        tester,
        const SeoPieChart(data: [SeoPieChartEntry('A', 0)]),
      );
      expect(EsenSeo.currentHtml, isNot(contains('conic-gradient')));
      expect(EsenSeo.currentHtml, contains('background:#e5e7eb'));
      expect(EsenSeo.currentHtml, contains('<td>0%</td>'));
    });

    testWidgets('renders as Flutter widgets with a legend', (tester) async {
      await pumpSeo(
        tester,
        const SeoPieChart(title: 'Marktanteile', data: data),
      );
      expect(find.text('Marktanteile'), findsOneWidget);
      expect(find.text('Flutter (46)'), findsOneWidget);
    });
  });

  group('SeoRating', () {
    testWidgets('mirrors stars plus the exact score as text', (tester) async {
      await pumpSeo(
        tester,
        const SeoRating(value: 4.5, label: '128 Bewertungen'),
      );
      expect(
        EsenSeo.currentHtml,
        '<p class="esen-seo-rating">★★★★☆ 4.5/5 (128 Bewertungen)</p>',
      );
    });

    testWidgets('without a label only the score follows', (tester) async {
      await pumpSeo(tester, const SeoRating(value: 3, max: 5));
      expect(
        EsenSeo.currentHtml,
        '<p class="esen-seo-rating">★★★☆☆ 3/5</p>',
      );
    });

    testWidgets('value is clamped to the scale', (tester) async {
      await pumpSeo(tester, const SeoRating(value: 9, max: 5));
      expect(EsenSeo.currentHtml, contains('★★★★★ 9/5'));
    });

    testWidgets('renders as Flutter text', (tester) async {
      await pumpSeo(tester, const SeoRating(value: 4.5));
      expect(find.text('★★★★☆'), findsOneWidget);
      expect(find.text('4.5/5'), findsOneWidget);
    });
  });

  group('SeoDataTable', () {
    testWidgets('mirrors as table with caption, thead and tbody',
        (tester) async {
      await pumpSeo(
        tester,
        const SeoDataTable(
          title: 'Technische Daten',
          columns: ['Merkmal', 'Wert'],
          rows: [
            ['Gewicht', '8,4 kg'],
            ['Rahmen', 'Carbon'],
          ],
        ),
      );
      expect(
        EsenSeo.currentHtml,
        '<table class="esen-seo-data-table">'
        '<caption>Technische Daten</caption>'
        '<thead><tr><th>Merkmal</th><th>Wert</th></tr></thead>'
        '<tbody>'
        '<tr><td>Gewicht</td><td>8,4 kg</td></tr>'
        '<tr><td>Rahmen</td><td>Carbon</td></tr>'
        '</tbody></table>',
      );
    });

    testWidgets('ragged rows are padded and truncated, never break',
        (tester) async {
      await pumpSeo(
        tester,
        const SeoDataTable(
          columns: ['A', 'B'],
          rows: [
            ['nur-a'],
            ['a', 'b', 'zuviel'],
          ],
        ),
      );
      final html = EsenSeo.currentHtml;
      expect(html, contains('<tr><td>nur-a</td><td></td></tr>'));
      expect(html, contains('<tr><td>a</td><td>b</td></tr>'));
      expect(html, isNot(contains('zuviel')));
    });

    testWidgets('renders as a Flutter table', (tester) async {
      await pumpSeo(
        tester,
        const SeoDataTable(
          columns: ['Merkmal', 'Wert'],
          rows: [
            ['Gewicht', '8,4 kg'],
          ],
        ),
      );
      expect(find.text('Merkmal'), findsOneWidget);
      expect(find.text('8,4 kg'), findsOneWidget);
    });
  });
}
