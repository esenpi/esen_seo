import 'package:esen_seo/server.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shelf/shelf.dart';

Handler _handler({
  String? canonicalHost,
  bool forceHttps = false,
  bool trustProxy = false,
  bool stripTrailingSlashes = true,
  Map<String, String> redirects = const {},
}) =>
    const Pipeline()
        .addMiddleware(seoRedirectMiddleware(
          canonicalHost: canonicalHost,
          forceHttps: forceHttps,
          trustProxy: trustProxy,
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

    test('only honors x-forwarded-proto for a trusted proxy', () async {
      final direct = await _handler()(
        _get(
          'https://esen.software/demo/',
          headers: {'x-forwarded-proto': 'http'},
        ),
      );
      expect(direct.headers['location'], '/demo');

      final response = await _handler(forceHttps: true, trustProxy: true)(
        _get(
          'http://esen.software/demo',
          headers: {'x-forwarded-proto': 'https'},
        ),
      );
      expect(response.statusCode, 200);
      expect(await response.readAsString(), 'app');
    });

    test('strips trailing slashes but keeps the root', () async {
      final handler = _handler();
      final response = await handler(_get('https://esen.software/demo/'));
      expect(response.statusCode, 301);
      expect(response.headers['location'], '/demo');

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
        '/neue-seite',
      );
      expect(
        (await handler(_get('https://x.dev/extern'))).headers['location'],
        'https://anderes-projekt.dev/',
      );
    });

    test('rejects malformed absolute redirect targets', () async {
      expect(
        () => _handler(redirects: {'/old': 'httpwhatever:value'}),
        throwsArgumentError,
      );
    });

    test('rejects scheme-relative and non-path redirect targets', () {
      for (final target in ['//attacker.invalid/path', 'next-page']) {
        expect(
          () => _handler(redirects: {'/old': target}),
          throwsArgumentError,
          reason: target,
        );
      }
    });

    test('a mapped query and fragment are not encoded into the path', () async {
      final handler = _handler(redirects: {
        '/old': '/new?q=target#details',
        '/keep-query': '/new',
      });

      expect(
        (await handler(_get('https://x.dev/old?source=old')))
            .headers['location'],
        '/new?q=target#details',
      );
      expect(
        (await handler(_get('https://x.dev/keep-query?source=old')))
            .headers['location'],
        '/new?source=old',
      );
    });

    test('forceHttps does not add authority when only the path changes',
        () async {
      final response = await _handler(forceHttps: true)(
        _get('https://untrusted-host.invalid/demo/'),
      );

      expect(response.headers['location'], '/demo');
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
