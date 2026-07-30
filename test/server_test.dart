import 'package:esen_seo/server.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shelf/shelf.dart';

const _googlebot =
    'Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)';
const _chrome =
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36';

Request _request(String? userAgent, {String path = ''}) => Request(
      'GET',
      Uri.parse('http://localhost/$path'),
      headers: {if (userAgent != null) 'user-agent': userAgent},
    );

void main() {
  group('BotDetector', () {
    const detector = BotDetector();

    test('recognizes search engine and preview bots', () {
      expect(detector.isBot(_googlebot), isTrue);
      expect(detector.isBot('facebookexternalhit/1.1'), isTrue);
      expect(detector.isBot('Twitterbot/1.0'), isTrue);
      expect(detector.isBot('GPTBot/1.0'), isTrue);
    });

    test('lets real browsers and missing user agents through', () {
      expect(detector.isBot(_chrome), isFalse);
      expect(detector.isBot(null), isFalse);
      expect(detector.isBot(''), isFalse);
    });

    test('extraPatterns extend the default list', () {
      const custom = BotDetector(extraPatterns: ['MeinInternerBot']);
      expect(custom.isBot('MeinInternerBot/2.0'), isTrue);
      expect(custom.isBot(_googlebot), isTrue);
    });

    test('BotDetector.only replaces the default list', () {
      const custom = BotDetector.only(['spezialbot']);
      expect(custom.isBot('SpezialBot/1.0'), isTrue);
      expect(custom.isBot(_googlebot), isFalse);
    });
  });

  group('SeoPage', () {
    test('renders a complete HTML document', () {
      final page = SeoPage(
        meta: const SeoMeta(title: 'Willkommen', description: 'Hallo'),
        bodyHtml: '<h1>Willkommen</h1>',
        lang: 'de',
      );
      final html = page.toHtmlDocument();
      expect(html, startsWith('<!DOCTYPE html><html lang="de">'));
      expect(html, contains('<meta charset="utf-8"/>'));
      expect(html, contains('<title>Willkommen</title>'));
      expect(html, contains('<body><h1>Willkommen</h1></body>'));
      expect(html, endsWith('</html>'));
    });

    test('fromNodes escapes text like the Flutter side', () {
      final page = SeoPage.fromNodes(
        body: [SeoNode(tag: 'p', text: 'A & B')],
      );
      expect(page.toHtmlDocument(), contains('<p>A &amp; B</p>'));
    });
  });

  group('seoBotMiddleware', () {
    final handler =
        const Pipeline().addMiddleware(seoBotMiddleware(resolve: (request) {
      if (request.url.path == 'unbekannt') return null;
      return SeoPage(
        meta: const SeoMeta(title: 'SSR Seite'),
        bodyHtml: '<h1>SSR</h1>',
        lang: 'de',
      );
    })).addHandler((request) => Response.ok('flutter app'));

    test('bots get the semantic HTML document', () async {
      final response = await handler(_request(_googlebot));
      expect(response.headers['content-type'], contains('text/html'));
      expect(response.headers['x-esen-seo'], 'ssr');
      final body = await response.readAsString();
      expect(body, contains('<title>SSR Seite</title>'));
      expect(body, contains('<h1>SSR</h1>'));
    });

    test('real users get the wrapped app handler', () async {
      final response = await handler(_request(_chrome));
      expect(await response.readAsString(), 'flutter app');
      expect(response.headers.containsKey('x-esen-seo'), isFalse);
    });

    test('unresolved routes fall through to the app even for bots', () async {
      final response = await handler(_request(_googlebot, path: 'unbekannt'));
      expect(await response.readAsString(), 'flutter app');
    });
  });
}
