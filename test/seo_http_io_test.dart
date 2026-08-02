@TestOn('vm')
library;

import 'dart:io';

import 'package:esen_seo/server.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;

/// These run over a REAL socket, not an in-memory `Response`.
///
/// A header the adapter cannot encode does not show up as a wrong value
/// — the request hangs or the connection dies, which an in-memory test
/// cannot see. That gap let a non-ASCII resolver header through as
/// "allowed": it can never split a response, but `shelf_io` refuses it
/// and the page never arrives. A CMS-supplied header must not be able to
/// take a page down.
void main() {
  late HttpServer server;
  late HttpClient client;
  late String base;

  Future<void> start(List<SeoRoute> routes) async {
    final handler = const Pipeline()
        .addMiddleware(
            seoBotMiddleware(routes: routes, siteBase: 'https://x.dev'))
        .addHandler((_) => Response.ok('app'));
    server = await io.serve(handler, '127.0.0.1', 0);
    base = 'http://127.0.0.1:${server.port}';
    client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
  }

  tearDown(() async {
    client.close(force: true);
    await server.close(force: true);
  });

  List<SeoRoute> tableWith(Map<String, String> headers) => [
        SeoRoute.dynamic(
          path: '/p',
          resolve: (_) async => SeoDocument(
            meta: const SeoMeta(title: 'P'),
            body: [SeoNode(tag: 'h1', text: 'Produkt')],
            headers: headers,
          ),
        ),
      ];

  Future<HttpClientResponse> get(String path) async {
    final req = await client.getUrl(Uri.parse('$base$path'));
    req.followRedirects = false;
    req.headers.set('user-agent', 'Googlebot/2.1');
    return req.close().timeout(const Duration(seconds: 5));
  }

  test('a non-ASCII header value cannot stall the response', () async {
    // U+2028 was once allowed on the grounds that it cannot split a
    // response. True, and beside the point: the adapter rejects it and
    // the page never arrives at all.
    await start(tableWith({'x-robots-tag': 'noarchive evil'}));
    final res = await get('/p');
    await res.drain<void>();
    expect(res.statusCode, 200);
    expect(res.headers.value('x-robots-tag'), isNull);
  });

  test('an invalid header name cannot stall the response', () async {
    await start(tableWith({'x bad name': 'v', 'x-robots-tag': 'noindex'}));
    final res = await get('/p');
    await res.drain<void>();
    expect(res.statusCode, 200);
    expect(res.headers.value('x-robots-tag'), 'noindex');
  });

  test('the allow list survives a real adapter', () async {
    await start(tableWith({
      'cache-control': 'public, max-age=600',
      'x-robots-tag': 'noarchive',
      'set-cookie': 'session=attacker',
      'content-encoding': 'gzip',
      'vary': 'Accept-Language',
    }));
    final res = await get('/p');
    final body = await res.transform(const SystemEncoding().decoder).join();

    expect(res.statusCode, 200);
    expect(res.headers.value('cache-control'), 'public, max-age=600');
    expect(res.headers.value('x-robots-tag'), 'noarchive');
    expect(res.headers.value('set-cookie'), isNull);
    // content-encoding would have made the body unreadable.
    expect(res.headers.value('content-encoding'), isNull);
    expect(body, contains('<h1>Produkt</h1>'));
    final vary = res.headers.value('vary')!;
    expect(vary, contains('User-Agent'));
    expect(vary, contains('Accept-Language'));
  });

  test('bot and human reach the same redirect target over the wire', () async {
    await start([
      SeoRoute.dynamic(
        path: '/old-page.html',
        resolve: (_) async => const SeoRedirect('/neu'),
      ),
    ]);
    Future<HttpClientResponse> ask(String ua) async {
      final req = await client.getUrl(Uri.parse('$base/old-page.html'));
      req.followRedirects = false;
      req.headers.set('user-agent', ua);
      return req.close().timeout(const Duration(seconds: 5));
    }

    final bot = await ask('Googlebot/2.1');
    await bot.drain<void>();
    final human = await ask('Mozilla/5.0');
    await human.drain<void>();
    expect(bot.statusCode, 301);
    expect(human.statusCode, 301);
    expect(human.headers.value('location'), bot.headers.value('location'));
  });
}
