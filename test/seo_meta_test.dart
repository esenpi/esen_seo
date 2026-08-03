import 'package:esen_seo/esen_seo.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  group('SeoMeta.toHtml', () {
    test('renders title, description and canonical link', () {
      const meta = SeoMeta(
        title: 'Willkommen',
        description: 'Flutter Apps mit echtem SEO.',
        canonicalUrl: 'https://esen.software/',
      );
      final html = meta.toHtml();
      expect(html, contains('<title>Willkommen</title>'));
      expect(
        html,
        contains(
          '<meta name="description" content="Flutter Apps mit echtem SEO."/>',
        ),
      );
      expect(
        html,
        contains('<link rel="canonical" href="https://esen.software/"/>'),
      );
    });

    test('renders keywords, author and robots', () {
      const meta = SeoMeta(
        keywords: ['flutter', 'seo'],
        author: 'Yahya Esen',
        robots: 'noindex',
      );
      final html = meta.toHtml();
      expect(html, contains('<meta name="keywords" content="flutter, seo"/>'));
      expect(html, contains('<meta name="author" content="Yahya Esen"/>'));
      expect(html, contains('<meta name="robots" content="noindex"/>'));
    });

    test('derives OpenGraph tags from base fields (smart defaults)', () {
      const meta = SeoMeta(
        title: 'Titel',
        description: 'Beschreibung',
        canonicalUrl: 'https://esen.software/seite',
      );
      final html = meta.toHtml();
      expect(html, contains('<meta property="og:type" content="website"/>'));
      expect(html, contains('<meta property="og:title" content="Titel"/>'));
      expect(
        html,
        contains('<meta property="og:description" content="Beschreibung"/>'),
      );
      expect(
        html,
        contains(
          '<meta property="og:url" content="https://esen.software/seite"/>',
        ),
      );
    });

    test('explicit OpenGraph values override the defaults', () {
      const meta = SeoMeta(
        title: 'Basis',
        openGraph: OpenGraphMeta(
          title: 'OG Titel',
          type: 'article',
          image: 'https://esen.software/og.png',
          imageAlt: 'Vorschau',
          siteName: 'Esen Software',
          locale: 'de_DE',
        ),
      );
      final html = meta.toHtml();
      expect(html, contains('<meta property="og:title" content="OG Titel"/>'));
      expect(html, contains('<meta property="og:type" content="article"/>'));
      expect(
        html,
        contains(
          '<meta property="og:image" content="https://esen.software/og.png"/>',
        ),
      );
      expect(
          html, contains('<meta property="og:image:alt" content="Vorschau"/>'));
      expect(
        html,
        contains('<meta property="og:site_name" content="Esen Software"/>'),
      );
      expect(html, contains('<meta property="og:locale" content="de_DE"/>'));
    });

    test('emits no OpenGraph or Twitter tags without any content', () {
      const meta = SeoMeta(robots: 'noindex');
      final html = meta.toHtml();
      expect(html, isNot(contains('og:')));
      expect(html, isNot(contains('twitter:')));
    });

    test('an OpenGraph image implies twitter:card summary_large_image', () {
      const meta = SeoMeta(
        title: 'Titel',
        openGraph: OpenGraphMeta(image: 'https://esen.software/og.png'),
      );
      expect(
        meta.toHtml(),
        contains('<meta name="twitter:card" content="summary_large_image"/>'),
      );
    });

    test('explicit Twitter values override the defaults', () {
      const meta = SeoMeta(
        title: 'Titel',
        twitter: TwitterCardMeta(
          card: 'summary',
          site: '@esensoftware',
          creator: '@yahya',
        ),
      );
      final html = meta.toHtml();
      expect(html, contains('<meta name="twitter:card" content="summary"/>'));
      expect(
        html,
        contains('<meta name="twitter:site" content="@esensoftware"/>'),
      );
      expect(html, contains('<meta name="twitter:creator" content="@yahya"/>'));
    });

    test('renders hreflang alternates', () {
      const meta = SeoMeta(
        title: 'Preise',
        alternates: {
          'de': 'https://x.dev/de/preise',
          'en': 'https://x.dev/en/pricing',
          'x-default': 'https://x.dev/en/pricing',
        },
      );
      final html = meta.toHtml();
      expect(
        html,
        contains(
          '<link rel="alternate" hreflang="de" href="https://x.dev/de/preise"/>',
        ),
      );
      expect(
        html,
        contains(
          '<link rel="alternate" hreflang="x-default" href="https://x.dev/en/pricing"/>',
        ),
      );
    });

    test('copyWith keeps alternates', () {
      const meta = SeoMeta(alternates: {'de': 'https://x.dev/de'});
      expect(
        meta.copyWith(title: 'Neu').alternates,
        {'de': 'https://x.dev/de'},
      );
    });

    test('renders extraMeta as name/content tags', () {
      const meta = SeoMeta(
        title: 'Titel',
        extraMeta: {
          'google-site-verification': 'AbC123',
          'theme-color': '#0a0f1e',
        },
      );
      final html = meta.toHtml();
      expect(
        html,
        contains('<meta name="google-site-verification" content="AbC123"/>'),
      );
      expect(html, contains('<meta name="theme-color" content="#0a0f1e"/>'));
    });

    test('extraMeta refuses an unsafe referrer policy', () {
      const unsafe = SeoMeta(extraMeta: {'referrer': 'unsafe-url'});
      const safe = SeoMeta(extraMeta: {'Referrer': 'strict-origin'});

      expect(unsafe.toHtml(), isNot(contains('referrer')));
      expect(
        safe.toHtml(),
        contains('<meta name="Referrer" content="strict-origin"/>'),
      );
    });

    test('copyWith keeps extraMeta', () {
      const meta = SeoMeta(extraMeta: {'theme-color': '#fff'});
      expect(
        meta.copyWith(title: 'Neu').extraMeta,
        {'theme-color': '#fff'},
      );
    });

    test('escapes content values', () {
      const meta = SeoMeta(description: 'A & B "C"');
      expect(
        meta.toHtml(),
        contains(
          '<meta name="description" content="A &amp; B &quot;C&quot;"/>',
        ),
      );
    });
  });

  group('EsenSeo.setMeta', () {
    test('exposes the head fragment via currentHeadHtml', () {
      enableSeoForTests();
      EsenSeo.setMeta(const SeoMeta(title: 'Willkommen'));
      expect(EsenSeo.currentHeadHtml, contains('<title>Willkommen</title>'));
    });

    test('a second call replaces the previous head fragment', () {
      enableSeoForTests();
      EsenSeo.setMeta(const SeoMeta(title: 'Seite 1'));
      EsenSeo.setMeta(const SeoMeta(title: 'Seite 2'));
      expect(EsenSeo.currentHeadHtml, isNot(contains('Seite 1')));
      expect(EsenSeo.currentHeadHtml, contains('<title>Seite 2</title>'));
    });
  });
}
