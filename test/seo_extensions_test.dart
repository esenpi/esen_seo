import 'package:esen_seo/esen_seo.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  setUp(enableSeoForTests);

  group('Text().seo()', () {
    testWidgets('renders explicit h1 tag', (tester) async {
      await pumpSeo(tester, const Text('Willkommen').seo(SeoTextTag.h1));
      expect(EsenSeo.currentHtml, '<h1>Willkommen</h1>');
    });

    testWidgets('renders explicit p tag', (tester) async {
      await pumpSeo(tester, const Text('Ein Absatz').seo(SeoTextTag.p));
      expect(EsenSeo.currentHtml, '<p>Ein Absatz</p>');
    });

    testWidgets('escapes HTML in the content', (tester) async {
      await pumpSeo(tester, const Text('<b>böse</b> & Co').seo(SeoTextTag.p));
      expect(EsenSeo.currentHtml, '<p>&lt;b&gt;böse&lt;/b&gt; &amp; Co</p>');
    });

    testWidgets('keeps the Flutter widget visible and unchanged',
        (tester) async {
      await pumpSeo(tester, const Text('Willkommen').seo(SeoTextTag.h1));
      expect(find.text('Willkommen'), findsOneWidget);
    });
  });

  group('Image().seo()', () {
    testWidgets('renders img tag with src from NetworkImage', (tester) async {
      final image = Image.network(
        'https://example.com/foto.png',
        errorBuilder: (context, error, stackTrace) => const SizedBox(),
      );
      await pumpSeo(tester, image.seo(alt: 'Ein Foto'));
      expect(
        EsenSeo.currentHtml,
        '<img src="https://example.com/foto.png" alt="Ein Foto"/>',
      );
    });

    testWidgets('uses semanticLabel as alt fallback', (tester) async {
      final image = Image.network(
        'https://example.com/foto.png',
        semanticLabel: 'Semantik Foto',
        errorBuilder: (context, error, stackTrace) => const SizedBox(),
      );
      await pumpSeo(tester, image.seo());
      expect(
        EsenSeo.currentHtml,
        '<img src="https://example.com/foto.png" alt="Semantik Foto"/>',
      );
    });
  });

  group('Column().seo()', () {
    testWidgets('renders div with children', (tester) async {
      await pumpSeo(
        tester,
        Column(
          children: [
            const Text('Titel').seo(SeoTextTag.h1),
            const Text('Absatz').seo(SeoTextTag.p),
          ],
        ).seo(),
      );
      expect(EsenSeo.currentHtml, '<div><h1>Titel</h1><p>Absatz</p></div>');
    });

    testWidgets('supports a custom container tag', (tester) async {
      await pumpSeo(
        tester,
        Column(
          children: [const Text('Artikel').seo(SeoTextTag.h2)],
        ).seo(SeoContainerTag.article),
      );
      expect(EsenSeo.currentHtml, '<article><h2>Artikel</h2></article>');
    });
  });

  group('Row().seo()', () {
    testWidgets('semantic tags like tr carry no flex style', (tester) async {
      await pumpSeo(
        tester,
        Row(children: [const Text('Zelle').seo(SeoTextTag.td)])
            .seo(SeoContainerTag.tr),
      );
      expect(EsenSeo.currentHtml, '<tr><td>Zelle</td></tr>');
    });

    testWidgets('renders flex container', (tester) async {
      await pumpSeo(
        tester,
        Row(
          children: [const Text('Links').seo(SeoTextTag.p)],
        ).seo(),
      );
      expect(
        EsenSeo.currentHtml,
        '<div style="display:flex;flex-direction:row"><p>Links</p></div>',
      );
    });
  });

  group('GestureDetector().seo()', () {
    testWidgets('renders anchor with untagged text as label', (tester) async {
      await pumpSeo(
        tester,
        GestureDetector(
          onTap: () {},
          child: const Text('Über uns'),
        ).seo(href: '/about'),
      );
      expect(EsenSeo.currentHtml, '<a href="/about">Über uns</a>');
    });

    testWidgets('renders optional title attribute', (tester) async {
      await pumpSeo(
        tester,
        GestureDetector(
          onTap: () {},
          child: const Text('Kontakt'),
        ).seo(href: '/kontakt', title: 'Kontaktseite'),
      );
      expect(
        EsenSeo.currentHtml,
        '<a href="/kontakt" title="Kontaktseite">Kontakt</a>',
      );
    });
  });
}
