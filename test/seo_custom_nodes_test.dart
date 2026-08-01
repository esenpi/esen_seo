import 'package:esen_seo/esen_seo.dart';
import 'package:esen_seo/src/controller/seo_controller.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  group('.seoNodes()', () {
    setUp(enableSeoForTests);

    testWidgets('declares a custom HTML translation', (tester) async {
      await pumpSeo(
        tester,
        const SizedBox(width: 40, height: 40).seoNodes([
          SeoNode(tag: 'aside', text: 'Hinweis', attributes: {'class': 'x'}),
        ]),
      );
      expect(EsenSeo.currentHtml, '<aside class="x">Hinweis</aside>');
    });

    testWidgets('replaces the subtree — nothing mirrors twice', (tester) async {
      await pumpSeo(
        tester,
        Column(children: [
          const Text('Innen'), // würde sonst per Smart Default zu <h1>
        ]).seoNodes([SeoNode(tag: 'p', text: 'Nur ich')]),
      );
      expect(EsenSeo.currentHtml, '<p>Nur ich</p>');
      expect(EsenSeo.currentHtml, isNot(contains('Innen')));
    });

    testWidgets('sanitizes tags and attributes recursively', (tester) async {
      await pumpSeo(
        tester,
        const SizedBox().seoNodes([
          SeoNode(tag: 'script', text: 'evil()', children: [
            SeoNode(
              tag: 'span',
              text: 'ok',
              attributes: {'onclick': 'evil()', 'class': 'fine'},
            ),
          ]),
        ]),
      );
      // Geblockter Tag fällt auf div zurück, Handler fliegen raus:
      expect(
        EsenSeo.currentHtml,
        '<div>evil()<span class="fine">ok</span></div>',
      );
    });

    testWidgets('an empty tag with children falls back to div', (tester) async {
      // Sonst verschwände der komplette Teilbaum lautlos aus dem
      // Spiegel — das Sicherheitsnetz muss auch hier greifen.
      await pumpSeo(
        tester,
        const SizedBox().seoNodes([
          SeoNode(tag: '', children: [SeoNode(tag: 'span', text: 'drin')]),
        ]),
      );
      expect(EsenSeo.currentHtml, '<div><span>drin</span></div>');
    });

    testWidgets('an empty tag without children stays a text node',
        (tester) async {
      await pumpSeo(
        tester,
        const SizedBox().seoNodes([SeoNode.text('nur Text')]),
      );
      expect(EsenSeo.currentHtml, 'nur Text');
    });

    testWidgets('raw text never enters from user land', (tester) async {
      await pumpSeo(
        tester,
        const SizedBox().seoNodes([
          SeoNode(tag: 'p', rawText: '<b>unescaped</b>'),
        ]),
      );
      expect(EsenSeo.currentHtml, '<p></p>');
    });

    testWidgets('text content is escaped by the renderer', (tester) async {
      await pumpSeo(
        tester,
        const SizedBox().seoNodes([
          SeoNode(tag: 'p', text: 'a < b & c'),
        ]),
      );
      expect(EsenSeo.currentHtml, '<p>a &lt; b &amp; c</p>');
    });

    test('is a no-op off the web', () {
      SeoController.debugForceEnable = false;
      addTearDown(() => SeoController.debugForceEnable = true);
      const child = SizedBox();
      expect(identical(child.seoNodes([]), child), isTrue);
    });
  });
}
