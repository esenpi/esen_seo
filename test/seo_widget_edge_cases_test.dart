import 'package:esen_seo/esen_seo.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// Die Widgets bekommen ihre Daten oft ungeprüft aus Datenbanken oder
/// Berechnungen — NaN (0/0), Infinity, negative Werte und leere Listen
/// dürfen weder das Flutter-Layout crashen noch kaputtes HTML spiegeln.
void main() {
  setUp(enableSeoForTests);

  group('SeoBarChart robustness', () {
    testWidgets('NaN and infinity render as zero bars, never crash',
        (tester) async {
      await pumpSeo(
        tester,
        const SeoBarChart(data: [
          SeoBarChartEntry('nan', double.nan),
          SeoBarChartEntry('inf', double.infinity),
          SeoBarChartEntry('ok', 10),
        ]),
      );
      expect(tester.takeException(), isNull);
      final html = EsenSeo.currentHtml;
      expect(html, isNot(contains('NaN')));
      expect(html, isNot(contains('Infinity')));
      expect(html, contains('<tr><th>nan</th><td>0</td></tr>'));
      expect(html, contains('<tr><th>ok</th><td>10</td></tr>'));
      expect(html, contains('height:100%'));
    });

    testWidgets('negative values clamp to zero', (tester) async {
      await pumpSeo(
        tester,
        const SeoBarChart(data: [
          SeoBarChartEntry('minus', -5),
          SeoBarChartEntry('plus', 5),
        ]),
      );
      expect(tester.takeException(), isNull);
      expect(EsenSeo.currentHtml, contains('<tr><th>minus</th><td>0</td>'));
      expect(EsenSeo.currentHtml, contains('height:0%'));
    });
  });

  group('SeoPieChart robustness', () {
    testWidgets('an empty palette falls back to the default palette',
        (tester) async {
      await pumpSeo(
        tester,
        const SeoPieChart(
          palette: [],
          data: [SeoPieChartEntry('A', 1), SeoPieChartEntry('B', 1)],
        ),
      );
      expect(tester.takeException(), isNull);
      expect(EsenSeo.currentHtml, contains('#2563eb 0% 50%'));
    });

    testWidgets('NaN, infinity and negatives never crash the painter',
        (tester) async {
      await pumpSeo(
        tester,
        const SeoPieChart(data: [
          SeoPieChartEntry('nan', double.nan),
          SeoPieChartEntry('minus', -3),
          SeoPieChartEntry('ok', 3),
        ]),
      );
      expect(tester.takeException(), isNull);
      final html = EsenSeo.currentHtml;
      expect(html, isNot(contains('NaN')));
      // Das eine valide Segment trägt 100%:
      expect(html, contains('<tr><th>ok</th><td>3</td><td>100%</td>'));
      expect(html, contains('<tr><th>nan</th><td>0</td><td>0%</td>'));
    });
  });

  group('SeoRating robustness', () {
    testWidgets('a scale below 1 is normalized instead of throwing',
        (tester) async {
      await pumpSeo(tester, const SeoRating(value: 3, max: -2));
      expect(tester.takeException(), isNull);
      expect(EsenSeo.currentHtml, contains('★ 3/1'));
    });

    testWidgets('a NaN value renders as zero stars', (tester) async {
      await pumpSeo(tester, const SeoRating(value: double.nan));
      expect(tester.takeException(), isNull);
      expect(EsenSeo.currentHtml, contains('☆☆☆☆☆ 0/5'));
      expect(EsenSeo.currentHtml, isNot(contains('NaN')));
    });
  });

  group('dimension and number formatting', () {
    testWidgets('an infinite chart height falls back to the default',
        (tester) async {
      await pumpSeo(
        tester,
        const SeoBarChart(
          data: [SeoBarChartEntry('a', 1)],
          height: double.infinity,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(EsenSeo.currentHtml, contains('height:220px'));
    });

    testWidgets('a NaN pie diameter falls back instead of breaking layout',
        (tester) async {
      await pumpSeo(
        tester,
        const SeoPieChart(
          data: [SeoPieChartEntry('a', 1)],
          diameter: double.nan,
        ),
      );
      expect(tester.takeException(), isNull);
      final html = EsenSeo.currentHtml;
      expect(html, isNot(contains('NaN')));
      expect(html, contains('width:180px'));
    });

    testWidgets('huge values keep their magnitude instead of saturating',
        (tester) async {
      await pumpSeo(
        tester,
        const SeoBarChart(data: [SeoBarChartEntry('big', 1e19)]),
      );
      // 1e19.round() würde auf den int64-Maximalwert überlaufen:
      expect(EsenSeo.currentHtml, isNot(contains('9223372036854775807')));
      expect(EsenSeo.currentHtml, contains('<td>10000000000000000000</td>'));
    });
  });

  group('SeoRating limits', () {
    testWidgets('an absurd scale drops the stars, keeps the exact score',
        (tester) async {
      await pumpSeo(tester, const SeoRating(value: 3, max: 1000000));
      expect(tester.takeException(), isNull);
      final html = EsenSeo.currentHtml;
      expect(html, contains('3/1000000'));
      expect(html, isNot(contains('☆')));
      expect(html.length, lessThan(200));
    });
  });

  group('URL policy', () {
    testWidgets('control characters cannot smuggle a script scheme',
        (tester) async {
      // Browser entfernen Tab/Zeilenumbruch beim URL-Parsing — ohne
      // Prüfung würde daraus wieder ein ausführbares Schema.
      await pumpSeo(
        tester,
        const SizedBox().seoNodes([
          SeoNode(
            tag: 'a',
            text: 'Klick',
            attributes: {'href': 'java\tscript:alert(1)'},
          ),
        ]),
      );
      expect(EsenSeo.currentHtml, '<a>Klick</a>');
      expect(EsenSeo.currentHtml, isNot(contains('script')));
    });

    testWidgets('ordinary URLs still pass', (tester) async {
      await pumpSeo(
        tester,
        const SizedBox().seoNodes([
          SeoNode(
            tag: 'a',
            text: 'Docs',
            attributes: {'href': 'https://esen.software/docs'},
          ),
        ]),
      );
      expect(
        EsenSeo.currentHtml,
        '<a href="https://esen.software/docs">Docs</a>',
      );
    });
  });

  group('SeoDataTable robustness', () {
    testWidgets('empty columns render nothing instead of breaking',
        (tester) async {
      await pumpSeo(
        tester,
        const SeoDataTable(columns: [], rows: [
          ['verwaist'],
        ]),
      );
      expect(tester.takeException(), isNull);
      expect(EsenSeo.currentHtml, isNot(contains('verwaist')));
    });

    testWidgets('empty rows render header only', (tester) async {
      await pumpSeo(
        tester,
        const SeoDataTable(columns: ['A'], rows: []),
      );
      expect(tester.takeException(), isNull);
      expect(EsenSeo.currentHtml, contains('<th>A</th>'));
      expect(EsenSeo.currentHtml, contains('<tbody></tbody>'));
    });
  });
}
