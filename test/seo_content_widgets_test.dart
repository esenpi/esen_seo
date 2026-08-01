import 'package:esen_seo/esen_seo.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  setUp(enableSeoForTests);

  group('SeoFaq', () {
    const entries = [
      SeoFaqEntry('Braucht es Puppeteer?', 'Nein — reines Dart.'),
      SeoFaqEntry('Läuft es auf Mobile?', 'Ja, dort sind alle Aufrufe No-ops.'),
    ];

    testWidgets('mirrors every answer, collapsed or not', (tester) async {
      await pumpSeo(tester, const SeoFaq(title: 'Fragen', entries: entries));
      final html = EsenSeo.currentHtml;

      expect(html, contains('<section class="esen-seo-faq">'));
      expect(html, contains('<h2>Fragen</h2>'));
      // Entscheidend: Die Antworten stehen im Quelltext, obwohl das
      // Accordion auf dem Schirm zugeklappt ist.
      expect(
        html,
        contains('<details><summary>Braucht es Puppeteer?</summary>'
            '<p>Nein — reines Dart.</p></details>'),
      );
      expect(html, contains('<p>Ja, dort sind alle Aufrufe No-ops.</p>'));
    });

    testWidgets('heading level is configurable and clamped', (tester) async {
      await pumpSeo(
        tester,
        const SeoFaq(title: 'Fragen', entries: entries, titleLevel: 9),
      );
      expect(EsenSeo.currentHtml, contains('<h6>Fragen</h6>'));
    });

    testWidgets('empty entries mirror nothing', (tester) async {
      await pumpSeo(tester, const SeoFaq(entries: []));
      expect(tester.takeException(), isNull);
      expect(EsenSeo.currentHtml, isEmpty);
    });

    testWidgets('expanding on screen does not change the mirror',
        (tester) async {
      await pumpSeo(tester, const SeoFaq(entries: entries));
      final collapsed = EsenSeo.currentHtml;
      await tester.tap(find.text('Braucht es Puppeteer?'));
      await tester.pump();
      EsenSeo.refresh();
      expect(find.text('Nein — reines Dart.'), findsOneWidget);
      expect(EsenSeo.currentHtml, collapsed);
    });

    test('schemaFor builds matching FAQPage structured data', () {
      final json = SeoFaq.schemaFor(entries).toJson();
      expect(json['@type'], 'FAQPage');
      final questions = json['mainEntity'] as List;
      expect(questions, hasLength(2));
      expect((questions.first as Map)['name'], 'Braucht es Puppeteer?');
    });
  });

  group('SeoBreadcrumbs', () {
    const items = [
      SeoBreadcrumbEntry('Start', url: '/'),
      SeoBreadcrumbEntry('Blog', url: '/blog'),
      SeoBreadcrumbEntry('Flutter SEO'),
    ];

    testWidgets('mirrors as nav > ol > li with links', (tester) async {
      await pumpSeo(tester, const SeoBreadcrumbs(items: items));
      expect(
        EsenSeo.currentHtml,
        '<nav class="esen-seo-breadcrumbs" aria-label="Breadcrumb"><ol>'
        '<li><a href="/">Start</a><span aria-hidden="true">/</span></li>'
        '<li><a href="/blog">Blog</a><span aria-hidden="true">/</span></li>'
        '<li><span aria-current="page">Flutter SEO</span></li>'
        '</ol></nav>',
      );
    });

    testWidgets('empty items mirror nothing', (tester) async {
      await pumpSeo(tester, const SeoBreadcrumbs(items: []));
      expect(tester.takeException(), isNull);
      expect(EsenSeo.currentHtml, isEmpty);
    });

    testWidgets('a single current page needs no separator', (tester) async {
      await pumpSeo(
        tester,
        const SeoBreadcrumbs(items: [SeoBreadcrumbEntry('Nur hier')]),
      );
      expect(EsenSeo.currentHtml, isNot(contains('aria-hidden')));
    });

    testWidgets('taps report the entry back to the app', (tester) async {
      SeoBreadcrumbEntry? tapped;
      await pumpSeo(
        tester,
        SeoBreadcrumbs(items: items, onTap: (item) => tapped = item),
      );
      await tester.tap(find.text('Blog'));
      expect(tapped?.url, '/blog');
    });

    test('schemaFor resolves relative URLs and skips the current page', () {
      final json = SeoBreadcrumbs.schemaFor(items, base: 'https://x.dev/')!;
      final list = json.toJson()['itemListElement'] as List;
      // Die aktuelle Seite bleibt drin — nur ohne item, das ist erlaubt.
      expect(list, hasLength(3));
      expect((list.first as Map)['item'], 'https://x.dev/');
      expect((list[1] as Map)['item'], 'https://x.dev/blog');
      expect((list[1] as Map)['position'], 2);
      expect((list[2] as Map).containsKey('item'), isFalse);
      expect((list[2] as Map)['name'], 'Flutter SEO');
    });
  });

  group('SeoBreadcrumbs edge cases', () {
    testWidgets('a blank url is not a link anywhere', (tester) async {
      // Bildschirm, Spiegel und Schema müssen sich einig sein, was ein
      // Link ist — sonst klickt man ins Leere.
      SeoBreadcrumbEntry? tapped;
      await pumpSeo(
        tester,
        SeoBreadcrumbs(
          items: const [
            SeoBreadcrumbEntry('Start', url: '/'),
            SeoBreadcrumbEntry('Aktuell', url: '   '),
          ],
          onTap: (item) => tapped = item,
        ),
      );
      await tester.tap(find.text('Aktuell'));
      expect(tapped, isNull);
      expect(EsenSeo.currentHtml, contains('<span aria-current="page">'));
      expect(EsenSeo.currentHtml, isNot(contains('href="   "')));
    });

    testWidgets('surrounding whitespace is trimmed off the href',
        (tester) async {
      await pumpSeo(
        tester,
        const SeoBreadcrumbs(items: [
          SeoBreadcrumbEntry('Blog', url: '  /blog  '),
          SeoBreadcrumbEntry('Hier'),
        ]),
      );
      expect(EsenSeo.currentHtml, contains('<a href="/blog">Blog</a>'));
    });

    testWidgets('only the last step is the current page', (tester) async {
      await pumpSeo(
        tester,
        const SeoBreadcrumbs(items: [
          SeoBreadcrumbEntry('Ohne Link'),
          SeoBreadcrumbEntry('Blog', url: '/blog'),
          SeoBreadcrumbEntry('Hier'),
        ]),
      );
      expect('aria-current'.allMatches(EsenSeo.currentHtml), hasLength(1));
      expect(
        EsenSeo.currentHtml,
        contains('<span aria-current="page">Hier</span>'),
      );
    });

    test('schemaFor returns null instead of an empty BreadcrumbList', () {
      expect(SeoBreadcrumbs.schemaFor(const []), isNull);
    });

    test('a lone current page still yields a valid ListItem', () {
      final list = SeoBreadcrumbs.schemaFor(
        const [SeoBreadcrumbEntry('Nur hier')],
      )!
          .toJson()['itemListElement'] as List;
      expect(list, hasLength(1));
      expect((list.single as Map)['name'], 'Nur hier');
      expect((list.single as Map).containsKey('item'), isFalse);
    });
  });

  group('SeoFaq edge cases', () {
    testWidgets('a blank title emits no empty heading', (tester) async {
      await pumpSeo(
        tester,
        const SeoFaq(title: '   ', entries: [SeoFaqEntry('Q', 'A')]),
      );
      expect(EsenSeo.currentHtml, isNot(contains('<h2>')));
    });

    testWidgets('a declared h1 counts for the smart defaults', (tester) async {
      await pumpSeo(
        tester,
        Column(children: const [
          SeoFaq(title: 'Fragen', titleLevel: 1, entries: [
            SeoFaqEntry('Q', 'A'),
          ]),
          Text('Danach'),
        ]),
      );
      // Der Text danach darf nicht zum zweiten <h1> werden.
      expect('<h1'.allMatches(EsenSeo.currentHtml), hasLength(1));
      expect(EsenSeo.currentHtml, contains('<p>Danach</p>'));
    });
  });

  group('SeoFigure', () {
    testWidgets('mirrors image with alt, dimensions and caption',
        (tester) async {
      await pumpSeo(
        tester,
        const SeoFigure(
          src: 'https://x.dev/team.jpg',
          alt: 'Das Team',
          caption: 'Sommer 2026',
          width: 1200,
          height: 800,
          lazy: true,
        ),
      );
      expect(
        EsenSeo.currentHtml,
        '<figure class="esen-seo-figure">'
        '<img src="https://x.dev/team.jpg" alt="Das Team" width="1200" '
        'height="800" loading="lazy"/>'
        '<figcaption>Sommer 2026</figcaption></figure>',
      );
    });

    testWidgets('non-positive dimensions are omitted', (tester) async {
      await pumpSeo(
        tester,
        const SeoFigure(src: 'a.jpg', alt: '', width: 0, height: -5),
      );
      final html = EsenSeo.currentHtml;
      expect(html, isNot(contains('width=')));
      expect(html, isNot(contains('height=')));
      // Leeres alt bleibt stehen — das heißt „dekorativ", nicht „fehlt".
      expect(html, contains('alt=""'));
    });

    testWidgets('known dimensions reserve a ratio, not a fixed size',
        (tester) async {
      // Ein 1200er Bild darf auf einem schmalen Schirm nicht überlaufen.
      await tester.binding.setSurfaceSize(const Size(360, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pumpSeo(
        tester,
        const SeoFigure(src: 'a.jpg', alt: 'A', width: 1200, height: 800),
      );
      expect(tester.takeException(), isNull);
      final box = tester.getSize(find.byType(AspectRatio));
      expect(box.width, lessThanOrEqualTo(360));
      expect(box.width / box.height, closeTo(1.5, 0.01));
    });

    testWidgets('without a caption no figcaption is emitted', (tester) async {
      await pumpSeo(
        tester,
        const SeoFigure(src: 'a.jpg', alt: 'A', caption: ''),
      );
      expect(EsenSeo.currentHtml, isNot(contains('figcaption')));
    });
  });

  group('SeoTestimonial', () {
    testWidgets('mirrors quote and attribution as figure', (tester) async {
      await pumpSeo(
        tester,
        const SeoTestimonial(
          quote: 'Endlich rankt unsere App.',
          author: 'Maria Schmidt',
          role: 'CTO, Beispiel GmbH',
          sourceUrl: 'https://example.com/case',
        ),
      );
      expect(
        EsenSeo.currentHtml,
        '<figure class="esen-seo-testimonial">'
        '<blockquote cite="https://example.com/case">'
        '<p>Endlich rankt unsere App.</p></blockquote>'
        '<figcaption>— Maria Schmidt, CTO, Beispiel GmbH</figcaption>'
        '</figure>',
      );
    });

    testWidgets('a bare quote needs neither figcaption nor cite',
        (tester) async {
      await pumpSeo(tester, const SeoTestimonial(quote: 'Kurz und gut.'));
      expect(
        EsenSeo.currentHtml,
        '<figure class="esen-seo-testimonial"><blockquote>'
        '<p>Kurz und gut.</p></blockquote></figure>',
      );
    });

    testWidgets('an executable cite URL is dropped by the policy',
        (tester) async {
      await pumpSeo(
        tester,
        const SeoTestimonial(
          quote: 'Zitat',
          sourceUrl: 'javascript:alert(1)',
        ),
      );
      expect(EsenSeo.currentHtml, contains('<blockquote>'));
      expect(EsenSeo.currentHtml, isNot(contains('javascript')));
    });

    testWidgets('special characters are escaped, not injected', (tester) async {
      await pumpSeo(
        tester,
        const SeoTestimonial(quote: '5 > 3 & "gut"', author: '<b>X</b>'),
      );
      final html = EsenSeo.currentHtml;
      expect(html, contains('5 &gt; 3 &amp; "gut"'));
      expect(html, contains('&lt;b&gt;X&lt;/b&gt;'));
      expect(html, isNot(contains('<b>')));
    });
  });
}
