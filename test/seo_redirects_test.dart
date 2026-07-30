import 'package:esen_seo/server.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shelf/shelf.dart';

Handler _handler({
  String? canonicalHost,
  bool forceHttps = false,
  bool stripTrailingSlashes = true,
  Map<String, String> redirects = const {},
}) =>
    const Pipeline()
        .addMiddleware(seoRedirectMiddleware(
          canonicalHost: canonicalHost,
          forceHttps: forceHttps,
          stripTrailingSlashes: stripTrailingSlashes,
          redirects: redirects,
        ))
        .addHandler((request) => Response.ok('app'));

Request _get(String url, {Map<String, String> headers = const {}}) =>
    Request('GET', Uri.parse(url), headers: headers);

void main() {
  group('seoRedirectMiddleware', () {
    test('redirects www to the canonical host, preserving path and query',
        () async {
      final response = await _handler(canonicalHost: 'esen.software')(
        _get('https://www.esen.software/demo?a=1'),
      );
      expect(response.statusCode, 301);
      expect(
        response.headers['location'],
        'https://esen.software/demo?a=1',
      );
    });

    test('forces https, honoring x-forwarded-proto behind a proxy', () async {
      final response = await _handler(forceHttps: true)(
        _get(
          'https://esen.software/demo',
          headers: {'x-forwarded-proto': 'http'},
        ),
      );
      expect(response.statusCode, 301);
      expect(response.headers['location'], 'https://esen.software/demo');
    });

    test('strips trailing slashes but keeps the root', () async {
      final handler = _handler();
      final response = await handler(_get('https://esen.software/demo/'));
      expect(response.statusCode, 301);
      expect(response.headers['location'], 'https://esen.software/demo');

      expect(
        (await handler(_get('https://esen.software/'))).statusCode,
        200,
      );
    });

    test('maps exact paths to new paths and absolute URLs', () async {
      final handler = _handler(redirects: {
        '/alte-seite': '/neue-seite',
        '/extern': 'https://anderes-projekt.dev/',
      });
      expect(
        (await handler(_get('https://x.dev/alte-seite'))).headers['location'],
        'https://x.dev/neue-seite',
      );
      expect(
        (await handler(_get('https://x.dev/extern'))).headers['location'],
        'https://anderes-projekt.dev/',
      );
    });

    test('keeps non-default ports', () async {
      final response = await _handler(canonicalHost: 'esen.software')(
        _get('https://www.esen.software:8080/demo'),
      );
      expect(
        response.headers['location'],
        'https://esen.software:8080/demo',
      );
    });

    test('passes clean requests through untouched', () async {
      final response = await _handler(
        canonicalHost: 'esen.software',
        forceHttps: true,
      )(_get('https://esen.software/demo'));
      expect(response.statusCode, 200);
      expect(await response.readAsString(), 'app');
    });
  });
}
