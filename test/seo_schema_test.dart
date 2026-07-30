import 'dart:convert';

import 'package:esen_seo/esen_seo.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  group('SeoSchema', () {
    test('generic schema carries @context and @type', () {
      final schema = SeoSchema('Recipe', {'name': 'Linsensuppe'});
      expect(schema.toJson(), {
        '@context': 'https://schema.org',
        '@type': 'Recipe',
        'name': 'Linsensuppe',
      });
    });

    test('null properties are dropped', () {
      final schema = SeoSchema('Thing', {'name': 'A', 'url': null});
      expect(schema.toJson().containsKey('url'), isFalse);
    });

    test('article factory builds author and ISO dates', () {
      final schema = SeoSchema.article(
        headline: 'Flutter SEO ohne Puppeteer',
        author: 'Yahya Esen',
        datePublished: DateTime.utc(2026, 7, 22),
      );
      final json = schema.toJson();
      expect(json['@type'], 'Article');
      expect(json['headline'], 'Flutter SEO ohne Puppeteer');
      expect(json['author'], {'@type': 'Person', 'name': 'Yahya Esen'});
      expect(json['datePublished'], '2026-07-22T00:00:00.000Z');
      expect(json.containsKey('description'), isFalse);
    });

    test('product factory nests the offer', () {
      final schema = SeoSchema.product(
        name: 'Rotes Rennrad',
        price: 799.0,
        priceCurrency: 'EUR',
      );
      expect(schema.toJson()['offers'], {
        '@type': 'Offer',
        'price': '799.00',
        'priceCurrency': 'EUR',
      });
    });

    test('breadcrumbs get 1-based positions', () {
      final schema = SeoSchema.breadcrumbs([
        (name: 'Start', url: 'https://example.com/'),
        (name: 'Blog', url: 'https://example.com/blog'),
      ]);
      final items = schema.toJson()['itemListElement'] as List;
      expect(items, hasLength(2));
      expect(items[0], {
        '@type': 'ListItem',
        'position': 1,
        'name': 'Start',
        'item': 'https://example.com/',
      });
      expect((items[1] as Map)['position'], 2);
    });

    test('faq factory builds questions with accepted answers', () {
      final schema = SeoSchema.faq([
        (question: 'Braucht es Puppeteer?', answer: 'Nein, reines Dart.'),
      ]);
      final entities = schema.toJson()['mainEntity'] as List;
      expect(entities.single, {
        '@type': 'Question',
        'name': 'Braucht es Puppeteer?',
        'acceptedAnswer': {'@type': 'Answer', 'text': 'Nein, reines Dart.'},
      });
    });

    test('toJsonString escapes < so </script> cannot break out', () {
      final schema = SeoSchema('Thing', {'name': '</script><b>böse</b>'});
      final raw = schema.toJsonString();
      expect(raw, isNot(contains('</script>')));
      expect(raw, contains(r'\u003C/script>'));
      // Der Escape ist verlustfrei: dekodiert kommt der Original-Text raus.
      expect(jsonDecode(raw)['name'], '</script><b>böse</b>');
    });
  });

  group('SeoMeta.schemas', () {
    test('renders a script tag with type application/ld+json', () {
      final meta = SeoMeta(
        title: 'Titel',
        schemas: [
          SeoSchema.organization(name: 'Esen Software'),
        ],
      );
      final html = meta.toHtml();
      expect(html, contains('<script type="application/ld+json">'));
      expect(html, contains('"@type":"Organization"'));
      expect(html, contains('"name":"Esen Software"'));
      expect(html, contains('</script>'));
    });

    test('multiple schemas become separate script tags', () {
      final meta = SeoMeta(
        schemas: [
          SeoSchema.website(name: 'Esen', url: 'https://esen.software'),
          SeoSchema.breadcrumbs(
              [(name: 'Start', url: 'https://esen.software')]),
        ],
      );
      final html = meta.toHtml();
      expect('application/ld+json'.allMatches(html), hasLength(2));
    });

    test('EsenSeo.setMeta exposes the JSON-LD via currentHeadHtml', () {
      enableSeoForTests();
      EsenSeo.setMeta(SeoMeta(
        schemas: [SeoSchema.organization(name: 'Esen Software')],
      ));
      expect(
        EsenSeo.currentHeadHtml,
        contains('<script type="application/ld+json">'),
      );
    });
  });
}
