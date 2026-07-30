import 'package:esen_seo/esen_seo.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  setUp(enableSeoForTests);

  group('HTML-Attribute', () {
    testWidgets('time with datetime attribute', (tester) async {
      await pumpSeo(
        tester,
        const Text('12. Juli').seo(SeoTextTag.time, {'datetime': '2026-07-12'}),
      );
      expect(
        EsenSeo.currentHtml,
        '<time datetime="2026-07-12">12. Juli</time>',
      );
    });

    testWidgets('id and lang on containers', (tester) async {
      await pumpSeo(
        tester,
        Column(children: [const Text('Inhalt').seo(SeoTextTag.p)])
            .seo(SeoContainerTag.section, {'id': 'preise', 'lang': 'de'}),
      );
      expect(
        EsenSeo.currentHtml,
        '<section id="preise" lang="de"><p>Inhalt</p></section>',
      );
    });

    testWidgets('blockquote with cite attribute', (tester) async {
      await pumpSeo(
        tester,
        const Text('Zitat')
            .seo(SeoTextTag.blockquote, {'cite': 'https://example.com/q'}),
      );
      expect(
        EsenSeo.currentHtml,
        '<blockquote cite="https://example.com/q">Zitat</blockquote>',
      );
    });

    testWidgets('attribute names are normalized to lowercase', (tester) async {
      await pumpSeo(
        tester,
        const Text('Text').seo(SeoTextTag.p, {'ID': 'abschnitt'}),
      );
      expect(EsenSeo.currentHtml, '<p id="abschnitt">Text</p>');
    });

    testWidgets('a custom style on Row overrides the flex default',
        (tester) async {
      await pumpSeo(
        tester,
        Row(children: [const Text('Zelle').seo(SeoTextTag.span)])
            .seo(SeoContainerTag.div, {'style': 'display:grid'}),
      );
      expect(EsenSeo.currentHtml, contains('style="display:grid"'));
      expect(EsenSeo.currentHtml, isNot(contains('flex-direction')));
    });
  });

  group('Image Attribute', () {
    Image networkImage({double? width, double? height}) => Image.network(
          'https://example.com/foto.png',
          width: width,
          height: height,
          errorBuilder: (context, error, stack) => const SizedBox(),
        );

    testWidgets('width, height and lazy loading', (tester) async {
      await pumpSeo(
        tester,
        networkImage().seo(alt: 'Foto', width: 800, height: 400, lazy: true),
      );
      expect(
        EsenSeo.currentHtml,
        contains('width="800" height="400" loading="lazy"'),
      );
    });

    testWidgets('dimensions fall back to the widget properties',
        (tester) async {
      await pumpSeo(
        tester,
        networkImage(width: 300.4, height: 150.6).seo(alt: 'Foto'),
      );
      expect(EsenSeo.currentHtml, contains('width="300" height="151"'));
    });

    testWidgets('without any dimensions no width/height is emitted',
        (tester) async {
      await pumpSeo(tester, networkImage().seo(alt: 'Foto'));
      expect(EsenSeo.currentHtml, isNot(contains('width=')));
    });
  });

  group('Link Attribute', () {
    testWidgets('rel and hreflang', (tester) async {
      await pumpSeo(
        tester,
        GestureDetector(
          onTap: () {},
          child: const Text('Impressum'),
        ).seo(href: '/impressum', rel: 'nofollow', hreflang: 'de'),
      );
      expect(
        EsenSeo.currentHtml,
        '<a href="/impressum" rel="nofollow" hreflang="de">Impressum</a>',
      );
    });
  });

  group('Attribut-Policy', () {
    testWidgets('event handlers are dropped', (tester) async {
      await pumpSeo(
        tester,
        const Text('Text')
            .seo(SeoTextTag.p, {'onclick': 'alert(1)', 'id': 'ok'}),
      );
      expect(EsenSeo.currentHtml, '<p id="ok">Text</p>');
    });

    testWidgets('javascript: URLs in href are dropped', (tester) async {
      await pumpSeo(
        tester,
        GestureDetector(
          onTap: () {},
          child: const Text('Link'),
        ).seo(href: 'javascript:alert(1)'),
      );
      expect(EsenSeo.currentHtml, '<a>Link</a>');
    });

    testWidgets('invalid attribute names are dropped', (tester) async {
      await pumpSeo(
        tester,
        const Text('Text').seo(SeoTextTag.p, {'x"y=': 'böse'}),
      );
      expect(EsenSeo.currentHtml, '<p>Text</p>');
    });

    testWidgets('data- and aria- attributes stay allowed', (tester) async {
      await pumpSeo(
        tester,
        const Text('Text')
            .seo(SeoTextTag.p, {'data-testid': 'intro', 'aria-label': 'x'}),
      );
      expect(
        EsenSeo.currentHtml,
        '<p data-testid="intro" aria-label="x">Text</p>',
      );
    });
  });
}
