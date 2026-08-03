import 'package:esen_seo/esen_seo.dart';
import 'package:esen_seo/server.dart'
    show seoBotMiddleware, seoRobotsTxt, seoSitemapXml;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shelf/shelf.dart';

import 'helpers.dart';

const _googlebot =
    'Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)';

List<SeoRoute> _routes() => [
      SeoRoute(
        path: '/',
        meta: (_) => const SeoMeta(title: 'Home'),
        body: (_) => [SeoNode(tag: 'h1', text: 'Willkommen')],
      ),
      SeoRoute(
        path: '/demo',
        meta: (_) => const SeoMeta(title: 'Demo'),
      ),
      SeoRoute(
        path: '/blog/:slug',
        meta: (params) => SeoMeta(title: 'Blog — ${params['slug']}'),
        body: (params) => [SeoNode(tag: 'h1', text: params['slug']!)],
      ),
    ];

Request _request(String path, {String? userAgent}) => Request(
      'GET',
      Uri.parse('http://localhost/$path'),
      headers: {if (userAgent != null) 'user-agent': userAgent},
    );

/// The resolved metadata of a matched (static) route.
SeoMeta _meta(SeoRouteMatch match, {String? canonicalBase}) =>
    (match.resolveSync(canonicalBase: canonicalBase)! as SeoDocument).meta;

void main() {
  group('SeoRoute matching', () {
    test('matches exact paths and normalizes trailing slashes', () {
      final routes = _routes();
      expect(matchSeoRoute(routes, '/')!.route.path, '/');
      expect(matchSeoRoute(routes, '/demo')!.route.path, '/demo');
      expect(matchSeoRoute(routes, '/demo/')!.route.path, '/demo');
      expect(matchSeoRoute(routes, 'demo')!.route.path, '/demo');
      expect(matchSeoRoute(routes, '/nope'), isNull);
    });

    test('captures :param segments', () {
      final match = matchSeoRoute(_routes(), '/blog/mein-artikel')!;
      expect(match.route.path, '/blog/:slug');
      expect(match.params, {'slug': 'mein-artikel'});
      expect(_meta(match).title, 'Blog — mein-artikel');
    });

    test('param segments must not be empty', () {
      expect(matchSeoRoute(_routes(), '/blog/'), isNull);
    });

    test('derives canonical from base when route sets none', () {
      final routes = _routes();
      expect(
        _meta(matchSeoRoute(routes, '/demo')!, canonicalBase: 'https://x.dev/')
            .canonicalUrl,
        'https://x.dev/demo',
      );
      expect(
        _meta(matchSeoRoute(routes, '/')!, canonicalBase: 'https://x.dev')
            .canonicalUrl,
        'https://x.dev/',
      );
    });

    test('explicit canonical wins over the derived one', () {
      final route = SeoRoute(
        path: '/a',
        meta: (_) => const SeoMeta(canonicalUrl: 'https://x.dev/b'),
      );
      expect(
        _meta(matchSeoRoute([route], '/a')!, canonicalBase: 'https://x.dev')
            .canonicalUrl,
        'https://x.dev/b',
      );
    });
  });

  group('SeoRouteObserver', () {
    testWidgets('applies meta on initial route, push and pop', (tester) async {
      enableSeoForTests();
      await tester.pumpWidget(MaterialApp(
        navigatorObservers: [
          SeoRouteObserver(routes: _routes(), canonicalBase: 'https://x.dev'),
        ],
        initialRoute: '/',
        routes: {
          '/': (_) => const Scaffold(body: Text('home')),
          '/demo': (_) => const Scaffold(body: Text('demo')),
        },
      ));
      expect(EsenSeo.currentHeadHtml, contains('<title>Home</title>'));

      final context = tester.element(find.text('home'));
      Navigator.pushNamed(context, '/demo');
      await tester.pumpAndSettle();
      expect(EsenSeo.currentHeadHtml, contains('<title>Demo</title>'));
      expect(
        EsenSeo.currentHeadHtml,
        contains('<link rel="canonical" href="https://x.dev/demo"/>'),
      );

      Navigator.of(tester.element(find.text('demo'))).pop();
      await tester.pumpAndSettle();
      expect(EsenSeo.currentHeadHtml, contains('<title>Home</title>'));
    });
  });

  group('seoBotMiddleware with routes', () {
    final handler = const Pipeline()
        .addMiddleware(
          seoBotMiddleware(routes: _routes(), siteBase: 'https://x.dev'),
        )
        .addHandler((request) => Response.ok('flutter app'));

    test('serves matched routes with derived canonical', () async {
      final response = await handler(_request('', userAgent: _googlebot));
      final body = await response.readAsString();
      expect(body, contains('<title>Home</title>'));
      expect(body, contains('<h1>Willkommen</h1>'));
      expect(body, contains('<link rel="canonical" href="https://x.dev/"/>'));
    });

    test('resolves :param routes', () async {
      final response =
          await handler(_request('blog/hallo', userAgent: _googlebot));
      final body = await response.readAsString();
      expect(body, contains('<title>Blog — hallo</title>'));
      expect(body, contains('<h1>hallo</h1>'));
    });

    test('unknown page paths become a real 404 for bots', () async {
      final response = await handler(_request('nope', userAgent: _googlebot));
      expect(response.statusCode, 404);
      final body = await response.readAsString();
      expect(body, contains('404'));
      expect(body, contains('noindex'));
    });

    test('asset paths fall through to the app even for bots', () async {
      final response =
          await handler(_request('main.dart.js', userAgent: _googlebot));
      expect(await response.readAsString(), 'flutter app');
    });

    test('real users always get the app', () async {
      final response =
          await handler(_request('nope', userAgent: 'Mozilla/5.0 Chrome'));
      expect(await response.readAsString(), 'flutter app');
    });

    test('serves sitemap.xml to everyone, without param routes', () async {
      final response = await handler(_request('sitemap.xml'));
      expect(response.headers['content-type'], contains('xml'));
      final body = await response.readAsString();
      expect(body, contains('<loc>https://x.dev/</loc>'));
      expect(body, contains('<loc>https://x.dev/demo</loc>'));
      expect(body, isNot(contains(':slug')));
    });

    test('serves robots.txt with sitemap reference', () async {
      final response = await handler(_request('robots.txt'));
      final body = await response.readAsString();
      expect(body, contains('User-agent: *'));
      expect(body, contains('Sitemap: https://x.dev/sitemap.xml'));
    });
  });

  group('sitemap builders', () {
    test('seoSitemapXml includes additional paths', () {
      final xml = seoSitemapXml(
        routes: _routes(),
        siteBase: 'https://x.dev',
        additionalPaths: ['/blog/erster-post'],
      );
      expect(xml, contains('<loc>https://x.dev/blog/erster-post</loc>'));
    });

    test('additional paths that duplicate a route appear only once', () {
      final xml = seoSitemapXml(
        routes: _routes(),
        siteBase: 'https://x.dev',
        additionalPaths: ['/demo', 'demo/', '/blog/erster-post'],
      );
      // '/demo' existiert schon als Route, 'demo/' normalisiert dorthin:
      expect('<loc>https://x.dev/demo</loc>'.allMatches(xml), hasLength(1));
      expect(
        '<loc>https://x.dev/blog/erster-post</loc>'.allMatches(xml),
        hasLength(1),
      );
    });

    test('routes can opt out of the sitemap', () {
      final xml = seoSitemapXml(
        routes: [
          SeoRoute(
            path: '/intern',
            meta: (_) => const SeoMeta(),
            includeInSitemap: false,
          ),
        ],
        siteBase: 'https://x.dev',
      );
      expect(xml, isNot(contains('/intern')));
    });

    test('seoRobotsTxt without sitemap line', () {
      final txt =
          seoRobotsTxt(siteBase: 'https://x.dev', includeSitemap: false);
      expect(txt, isNot(contains('Sitemap:')));
    });

    test('routes with lastModified get a date-only lastmod', () {
      final xml = seoSitemapXml(
        routes: [
          SeoRoute(
            path: '/blog',
            meta: (_) => const SeoMeta(),
            lastModified: DateTime.utc(2026, 7, 31, 14, 30),
          ),
        ],
        siteBase: 'https://x.dev',
      );
      expect(xml, contains('<lastmod>2026-07-31</lastmod>'));
      expect(xml, isNot(contains('14:30')));
    });

    test('alternates become xhtml:link entries with the namespace', () {
      final xml = seoSitemapXml(
        routes: [
          SeoRoute(
            path: '/preise',
            meta: (_) => const SeoMeta(alternates: {
              'de': 'https://x.dev/preise',
              'en': 'https://x.dev/en/pricing',
            }),
          ),
        ],
        siteBase: 'https://x.dev',
      );
      expect(xml, contains('xmlns:xhtml="http://www.w3.org/1999/xhtml"'));
      expect(
        xml,
        contains(
          '<xhtml:link rel="alternate" hreflang="en" '
          'href="https://x.dev/en/pricing"/>',
        ),
      );
    });

    test('plain routes keep the compact form without xhtml namespace', () {
      final xml = seoSitemapXml(routes: _routes(), siteBase: 'https://x.dev');
      expect(xml, isNot(contains('xmlns:xhtml')));
      expect(xml, contains('<url><loc>https://x.dev/demo</loc></url>'));
    });

    test('additional paths inherit lastmod from their :param route', () {
      final xml = seoSitemapXml(
        routes: [
          SeoRoute(
            path: '/blog/:slug',
            meta: (_) => const SeoMeta(),
            lastModified: DateTime.utc(2026, 7, 31),
          ),
        ],
        siteBase: 'https://x.dev',
        additionalPaths: ['/blog/erster-post'],
      );
      expect(xml, contains('<loc>https://x.dev/blog/erster-post</loc>'));
      expect(xml, contains('<lastmod>2026-07-31</lastmod>'));
    });

    test('an alternate the URL policy refuses never reaches sitemap.xml', () {
      // Der Head lässt so eine URL nicht durch — die Sitemap war der
      // eine Ausgabeweg an der Policy vorbei: ein javascript:-Alternate
      // aus CMS-Daten stand wörtlich im ausgelieferten XML.
      final xml = seoSitemapXml(
        routes: [
          SeoRoute(
            path: '/',
            meta: (_) => const SeoMeta(
              title: 'Start',
              alternates: {
                'de': 'javascript:alert(1)',
                'en': 'https://x.dev/en',
              },
            ),
          ),
          SeoRoute(path: '/en', meta: (_) => const SeoMeta(title: 'Home')),
        ],
        siteBase: 'https://x.dev',
      );
      expect(xml, isNot(contains('javascript:')));
      expect(xml, contains('href="https://x.dev/en"'));
    });
  });
}
