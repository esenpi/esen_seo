import 'package:esen_seo/esen_seo.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  setUp(enableSeoForTests);

  group('Beliebige HTML Tags', () {
    testWidgets('Text().seo() renders any standard tag', (tester) async {
      await pumpSeo(
        tester,
        Column(children: [
          const Text('Ein Zitat').seo(SeoTextTag.blockquote),
          const Text('Bildunterschrift').seo(SeoTextTag.figcaption),
          const Text('Code').seo(SeoTextTag.code),
        ]),
      );
      expect(
          EsenSeo.currentHtml, contains('<blockquote>Ein Zitat</blockquote>'));
      expect(
        EsenSeo.currentHtml,
        contains('<figcaption>Bildunterschrift</figcaption>'),
      );
      expect(EsenSeo.currentHtml, contains('<code>Code</code>'));
    });

    testWidgets('a list renders as ul with li children', (tester) async {
      await pumpSeo(
        tester,
        Column(children: [
          const Text('Erstens').seo(SeoTextTag.li),
          const Text('Zweitens').seo(SeoTextTag.li),
        ]).seo(SeoContainerTag.ul),
      );
      expect(
        EsenSeo.currentHtml,
        '<ul><li>Erstens</li><li>Zweitens</li></ul>',
      );
    });

    testWidgets('uppercase tags are normalized to lowercase', (tester) async {
      await pumpSeo(tester, const Text('Titel').seo(SeoTextTag('H2')));
      expect(EsenSeo.currentHtml, '<h2>Titel</h2>');
    });
  });

  group('Blockierte Tags', () {
    testWidgets('script on a text falls back to span', (tester) async {
      await pumpSeo(tester, const Text('alert(1)').seo(SeoTextTag('script')));
      expect(EsenSeo.currentHtml, '<span>alert(1)</span>');
    });

    testWidgets('style on a container falls back to div', (tester) async {
      await pumpSeo(
        tester,
        Column(children: [const Text('Inhalt').seo(SeoTextTag.p)])
            .seo(SeoContainerTag('style')),
      );
      expect(EsenSeo.currentHtml, '<div><p>Inhalt</p></div>');
    });

    testWidgets('invalid tag names fall back instead of crashing',
        (tester) async {
      await pumpSeo(tester, const Text('Text').seo(SeoTextTag('div><script')));
      expect(EsenSeo.currentHtml, '<span>Text</span>');
    });
  });

  group('Void Elements', () {
    test('allowed void elements render self-closing', () {
      const renderer = HtmlRenderer();
      for (final tag in [
        'area',
        'br',
        'col',
        'hr',
        'img',
        'input',
        'source',
        'track',
        'wbr'
      ]) {
        expect(renderer.renderNode(SeoNode(tag: tag)), '<$tag/>');
      }
    });

    test('head-only and active void elements degrade in body context', () {
      // <base> und <embed> gehören nicht in den Body — der Renderer
      // setzt die Policy jetzt selbst durch, nicht erst der Aufrufer.
      const renderer = HtmlRenderer();
      for (final tag in ['base', 'embed', 'link', 'meta']) {
        expect(renderer.renderNode(SeoNode(tag: tag)), '<div></div>');
      }
    });

    test('the head renderer emits them properly', () {
      const renderer = HtmlRenderer.head();
      expect(
        renderer.renderNode(SeoNode(tag: 'meta', attributes: {'name': 'a'})),
        '<meta name="a"/>',
      );
      expect(renderer.renderNode(SeoNode(tag: 'base')), '<base/>');
    });
  });
}
