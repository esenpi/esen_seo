import 'dart:convert';
import 'dart:io';

import 'package:esen_seo/esen_seo.dart';
import 'package:esen_seo/server.dart'
    show seoBotMiddleware, seoLlmsFullTxt, seoLlmsTxt, submitIndexNow;
import 'package:flutter_test/flutter_test.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

List<SeoRoute> _routes() => [
      SeoRoute(
        path: '/',
        meta: (_) => const SeoMeta(
          title: 'Esen Software',
          description: 'Flutter Apps mit echtem SEO.',
        ),
        body: (_) => [
          SeoNode(tag: 'h1', text: 'Willkommen'),
          SeoNode(tag: 'p', text: 'Flutter  Apps\nmit echtem SEO.'),
          SeoNode(tag: 'ul', children: [
            SeoNode(tag: 'li', text: 'Semantisches HTML'),
            SeoNode(tag: 'li', text: 'Pure Dart'),
          ]),
          SeoNode(tag: 'section', children: [
            SeoNode(tag: 'h2', text: 'Über uns'),
            SeoNode(
              tag: 'a',
              text: 'Zu den Docs',
              attributes: {'href': '/docs'},
            ),
          ]),
          SeoNode(
            tag: 'img',
            attributes: {'src': '/logo.png', 'alt': 'Logo'},
          ),
          SeoSchema.organization(name: 'Esen Software').toNode(),
        ],
      ),
      SeoRoute(
        path: '/docs',
        meta: (_) => const SeoMeta(
          title: 'Docs',
          description: 'So funktioniert esen_seo.',
        ),
      ),
      SeoRoute(
        path: '/blog/:slug',
        meta: (params) => SeoMeta(title: 'Blog — ${params['slug']}'),
      ),
      SeoRoute(
        path: '/intern',
        meta: (_) => const SeoMeta(title: 'Intern'),
        includeInSitemap: false,
      ),
    ];

Request _request(String path) =>
    Request('GET', Uri.parse('http://localhost/$path'));

void main() {
  group('seoLlmsTxt', () {
    test('site identity defaults to the root route meta', () {
      final txt = seoLlmsTxt(routes: _routes(), siteBase: 'https://x.dev');
      expect(txt, startsWith('# Esen Software\n'));
      expect(txt, contains('> Flutter Apps mit echtem SEO.'));
    });

    test('lists pages as markdown links with descriptions', () {
      final txt = seoLlmsTxt(routes: _routes(), siteBase: 'https://x.dev');
      expect(txt, contains('## Pages'));
      expect(txt, contains('- [Esen Software](https://x.dev/):'));
      expect(
        txt,
        contains('- [Docs](https://x.dev/docs): So funktioniert esen_seo.'),
      );
    });

    test('skips :param routes and sitemap opt-outs, adds extra paths', () {
      final txt = seoLlmsTxt(
        routes: _routes(),
        siteBase: 'https://x.dev',
        additionalPaths: ['/blog/erster-post'],
      );
      expect(txt, isNot(contains(':slug')));
      expect(txt, isNot(contains('/intern')));
      expect(
        txt,
        contains('- [Blog — erster-post](https://x.dev/blog/erster-post)'),
      );
    });

    test('explicit title/description override the root meta', () {
      final txt = seoLlmsTxt(
        routes: _routes(),
        siteBase: 'https://x.dev',
        title: 'Anders',
        description: 'Auch anders.',
      );
      expect(txt, startsWith('# Anders\n'));
      expect(txt, contains('> Auch anders.'));
    });
  });

  group('seoLlmsFullTxt', () {
    test('inlines the page content as markdown', () async {
      final txt = await seoLlmsFullTxt(
        routes: _routes(),
        siteBase: 'https://x.dev',
      );
      expect(txt, startsWith('# Esen Software\n'));
      expect(txt, contains('## Esen Software\nhttps://x.dev/'));
      expect(txt, contains('# Willkommen'));
      // Whitespace wird pro Block normalisiert:
      expect(txt, contains('Flutter Apps mit echtem SEO.'));
      expect(txt, contains('- Semantisches HTML\n- Pure Dart'));
      // Container werden durchlaufen, Überschriften-Ebenen bleiben:
      expect(txt, contains('## Über uns'));
      // Relative URLs werden absolut:
      expect(txt, contains('[Zu den Docs](https://x.dev/docs)'));
      expect(txt, contains('![Logo](https://x.dev/logo.png)'));
      // JSON-LD ist kein Inhalt:
      expect(txt, isNot(contains('schema.org')));
    });

    test('routes without a body list their metadata only', () async {
      final txt = await seoLlmsFullTxt(
        routes: _routes(),
        siteBase: 'https://x.dev',
      );
      expect(txt, contains('## Docs\nhttps://x.dev/docs'));
      expect(txt, contains('> So funktioniert esen_seo.'));
    });
  });

  group('middleware serving', () {
    final handler = const Pipeline()
        .addMiddleware(seoBotMiddleware(
          routes: _routes(),
          siteBase: 'https://x.dev',
          indexNowKey: 'abc123def456',
        ))
        .addHandler((_) => Response.ok('flutter app'));

    test('serves llms.txt to everyone', () async {
      final response = await handler(_request('llms.txt'));
      expect(response.statusCode, 200);
      expect(response.headers['content-type'], contains('text/plain'));
      final body = await response.readAsString();
      expect(body, contains('# Esen Software'));
      expect(body, contains('- [Docs](https://x.dev/docs)'));
    });

    test('serves llms-full.txt with inlined content', () async {
      final response = await handler(_request('llms-full.txt'));
      expect(response.statusCode, 200);
      final body = await response.readAsString();
      expect(body, contains('# Willkommen'));
      expect(body, contains('- Semantisches HTML'));
    });

    test('serves the IndexNow key file', () async {
      final response = await handler(_request('abc123def456.txt'));
      expect(response.statusCode, 200);
      expect(await response.readAsString(), 'abc123def456');
    });

    test('other .txt paths still fall through to the app', () async {
      final response = await handler(_request('anders.txt'));
      expect(await response.readAsString(), 'flutter app');
    });
  });

  group('submitIndexNow', () {
    test('posts the JSON payload and accepts HTTP 200', () async {
      Map<String, Object?>? received;
      final server = await shelf_io.serve(
        (Request request) async {
          received =
              jsonDecode(await request.readAsString()) as Map<String, Object?>;
          return Response.ok('');
        },
        InternetAddress.loopbackIPv4,
        0,
      );
      addTearDown(server.close);

      final ok = await submitIndexNow(
        siteBase: 'https://x.dev/',
        key: 'abc123def456',
        paths: ['/', 'docs'],
        endpoint: Uri.parse('http://127.0.0.1:${server.port}/indexnow'),
      );

      expect(ok, isTrue);
      expect(received, {
        'host': 'x.dev',
        'key': 'abc123def456',
        'keyLocation': 'https://x.dev/abc123def456.txt',
        'urlList': ['https://x.dev/', 'https://x.dev/docs'],
      });
    });

    test('returns false on a rejecting endpoint', () async {
      final server = await shelf_io.serve(
        (_) => Response(422),
        InternetAddress.loopbackIPv4,
        0,
      );
      addTearDown(server.close);

      final ok = await submitIndexNow(
        siteBase: 'https://x.dev',
        key: 'abc123def456',
        paths: ['/'],
        endpoint: Uri.parse('http://127.0.0.1:${server.port}/indexnow'),
      );
      expect(ok, isFalse);
    });

    test('an empty path list is a no-op success', () async {
      expect(
        await submitIndexNow(
          siteBase: 'https://x.dev',
          key: 'abc123def456',
          paths: [],
          endpoint: Uri.parse('http://127.0.0.1:1/unreachable'),
        ),
        isTrue,
      );
    });
  });
}
