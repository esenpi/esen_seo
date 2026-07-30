import 'package:esen_seo/esen_seo.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  setUp(enableSeoForTests);

  group('Nesting', () {
    testWidgets('column with nested row keeps the hierarchy', (tester) async {
      await pumpSeo(
        tester,
        Column(
          children: [
            const Text('Titel').seo(SeoTextTag.h1),
            Row(
              children: [
                const Text('Links').seo(SeoTextTag.p),
                const Text('Rechts').seo(SeoTextTag.p),
              ],
            ).seo(),
          ],
        ).seo(),
      );
      expect(
        EsenSeo.currentHtml,
        '<div>'
        '<h1>Titel</h1>'
        '<div style="display:flex;flex-direction:row">'
        '<p>Links</p><p>Rechts</p>'
        '</div>'
        '</div>',
      );
    });

    testWidgets('seo widgets are found through non-seo wrappers',
        (tester) async {
      await pumpSeo(
        tester,
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Center(
                child: const Text('Tief verschachtelt').seo(SeoTextTag.h1),
              ),
            ),
          ],
        ).seo(),
      );
      expect(EsenSeo.currentHtml, '<div><h1>Tief verschachtelt</h1></div>');
    });

    testWidgets('link inside a column keeps tagged children', (tester) async {
      await pumpSeo(
        tester,
        Column(
          children: [
            const Text('Navigation').seo(SeoTextTag.h1),
            GestureDetector(
              onTap: () {},
              child: const Text('Mehr lesen'),
            ).seo(href: '/blog'),
          ],
        ).seo(SeoContainerTag.nav),
      );
      expect(
        EsenSeo.currentHtml,
        '<nav><h1>Navigation</h1><a href="/blog">Mehr lesen</a></nav>',
      );
    });

    testWidgets('three levels of containers', (tester) async {
      await pumpSeo(
        tester,
        Column(
          children: [
            Column(
              children: [
                Column(
                  children: [const Text('Kern').seo(SeoTextTag.p)],
                ).seo(SeoContainerTag.article),
              ],
            ).seo(SeoContainerTag.section),
          ],
        ).seo(),
      );
      expect(
        EsenSeo.currentHtml,
        '<div><section><article><p>Kern</p></article></section></div>',
      );
    });

    testWidgets('mixed tagged and untagged children stay in order',
        (tester) async {
      await pumpSeo(
        tester,
        Column(
          children: [
            const Text('Titel').seo(SeoTextTag.h1),
            const Text('Ohne Tag'),
            Image.network(
              'https://example.com/bild.png',
              errorBuilder: (context, error, stackTrace) => const SizedBox(),
            ).seo(alt: 'Bild'),
          ],
        ).seo(),
      );
      expect(
        EsenSeo.currentHtml,
        '<div>'
        '<h1>Titel</h1>'
        '<p>Ohne Tag</p>'
        '<img src="https://example.com/bild.png" alt="Bild"/>'
        '</div>',
      );
    });
  });
}
