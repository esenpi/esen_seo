import 'package:esen_seo/src/renderer/tag_policy.dart';
import 'package:flutter_test/flutter_test.dart';

/// The URL policy is an allow list: a value is refused unless its
/// scheme is known-safe. These tests pin both halves — that ordinary
/// links keep working, and that nothing executable gets through, no
/// matter how it is disguised.
void main() {
  group('URL attributes — what passes', () {
    const allowed = [
      '/blog',
      'blog/post.html',
      '../bild.png',
      '#anker',
      '?q=suche',
      '//cdn.example.com/bild.png',
      'https://example.com/seite',
      'HTTPS://EXAMPLE.COM/GROSS',
      'http://example.com',
      'mailto:hallo@example.com',
      'tel:+4989123456',
      'sms:+4989123456',
      'ftp://files.example.com/datei.zip',
      '/pfad mit leerzeichen',
      '/pfad?a=1&b=2',
    ];

    for (final url in allowed) {
      test('allows "$url"', () {
        expect(isAllowedSeoAttribute('href', url), isTrue);
        expect(isAllowedSeoAttribute('src', url), isTrue);
      });
    }
  });

  group('URL attributes — what is refused', () {
    const refused = {
      'javascript:alert(1)': 'plain script URL',
      'JaVaScRiPt:alert(1)': 'mixed case',
      '  javascript:alert(1)': 'leading whitespace',
      'java\tscript:alert(1)': 'tab inside the scheme',
      'java\nscript:alert(1)': 'newline inside the scheme',
      'java\rscript:alert(1)': 'carriage return inside the scheme',
      '\x01javascript:alert(1)': 'leading control character',
      'vbscript:msgbox(1)': 'vbscript',
      'data:text/html,<script>alert(1)</script>': 'inline HTML document',
      'data:image/svg+xml,<svg onload=alert(1)>': 'SVG can carry script',
      'blob:https://example.com/uuid': 'unknown scheme',
      'file:///etc/passwd': 'local file',
      'chrome://settings': 'browser internals',
      'intent://scan/#Intent;scheme=x;end': 'app intent',
      'jav\x00ascript:alert(1)': 'null byte inside the scheme',
    };

    refused.forEach((url, why) {
      test('refuses $why', () {
        expect(
          isAllowedSeoAttribute('href', url),
          isFalse,
          reason: 'accepted: $url',
        );
      });
    });

    test('refuses the same values in every URL attribute', () {
      for (final name in [
        'href',
        'src',
        'srcset',
        'cite',
        'action',
        'formaction',
        'poster',
        'data'
      ]) {
        expect(
          isAllowedSeoAttribute(name, 'javascript:alert(1)'),
          isFalse,
          reason: '$name let it through',
        );
      }
    });

    test('an unknown scheme is refused even though nobody listed it', () {
      // Der Kern der Erlaubnisliste: Wir müssen neue Angriffe nicht
      // kennen, um sie abzuweisen.
      expect(isAllowedSeoAttribute('href', 'nochniegehoert:tuwas'), isFalse);
    });
  });

  group('non-URL attributes are unaffected', () {
    test('text-valued attributes may contain anything printable', () {
      expect(isAllowedSeoAttribute('title', 'javascript:alert(1)'), isTrue);
      expect(isAllowedSeoAttribute('class', 'a b c'), isTrue);
      expect(isAllowedSeoAttribute('data-note', 'x:y'), isTrue);
    });

    test('event handlers stay blocked', () {
      expect(isAllowedSeoAttribute('onclick', 'x()'), isFalse);
      expect(isAllowedSeoAttribute('onerror', 'x()'), isFalse);
    });

    test('invalid attribute names stay blocked', () {
      expect(isAllowedSeoAttribute('1foo', 'x'), isFalse);
      expect(isAllowedSeoAttribute('a b', 'x'), isFalse);
      expect(isAllowedSeoAttribute('', 'x'), isFalse);
    });
  });
}
