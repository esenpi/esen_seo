import 'package:esen_seo/esen_seo.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  setUp(enableSeoForTests);

  group('Tag Kurzformen', () {
    testWidgets('.h1 and .p render like .seo(...)', (tester) async {
      await pumpSeo(
        tester,
        Column(children: [
          const Text('Titel').h1,
          const Text('Absatz').p,
        ]),
      );
      expect(EsenSeo.currentHtml, contains('<h1>Titel</h1>'));
      expect(EsenSeo.currentHtml, contains('<p>Absatz</p>'));
    });

    testWidgets('a list via .ul and .li', (tester) async {
      await pumpSeo(
        tester,
        Column(children: [
          const Text('Erstens').li,
          const Text('Zweitens').li,
        ]).ul,
      );
      expect(
        EsenSeo.currentHtml,
        '<ul><li>Erstens</li><li>Zweitens</li></ul>',
      );
    });

    testWidgets('.section on Column and .tr on Row', (tester) async {
      await pumpSeo(
        tester,
        Column(children: [
          Row(children: [const Text('Zelle').seo(SeoTextTag.td)]).tr,
        ]).section,
      );
      expect(EsenSeo.currentHtml, contains('<section>'));
      expect(EsenSeo.currentHtml, contains('<td>Zelle</td>'));
      expect(EsenSeo.currentHtml, contains('<tr><td>Zelle</td></tr>'));
    });
  });
}
