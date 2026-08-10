import 'package:esen_seo/server.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('interaction assets', () {
    test('runtime contains no string-to-code or HTML parsing sink', () {
      expect(seoInteractionRuntime, isNot(contains('innerHTML')));
      expect(seoInteractionRuntime, isNot(contains('outerHTML')));
      expect(seoInteractionRuntime, isNot(contains('document.write')));
      expect(seoInteractionRuntime, isNot(contains('eval(')));
      expect(seoInteractionRuntime, isNot(contains('Function(')));
      expect(seoInteractionRuntime, isNot(contains('</script')));
      expect(
        seoInteractionRuntime,
        isNot(contains("setAttribute('role', 'menu')")),
      );
      expect(seoInteractionRuntime, contains('stepperSelector'));
      expect(seoInteractionRuntime, contains("'aria-current', 'step'"));
    });

    test('script and style wrappers escape an optional nonce', () {
      final script = seoInteractionScriptHtml(nonce: '  one"<two  ');
      final style = seoInteractionStyleHtml(nonce: '  one"<two  ');

      expect(
        script,
        startsWith('<script data-esen-seo-interactions '
            'nonce="one&quot;&lt;two">'),
      );
      expect('</script>'.allMatches(script), hasLength(1));
      expect(
        style,
        startsWith('<style data-esen-seo-style '
            'nonce="one&quot;&lt;two">'),
      );
    });
  });

  group('SeoPage interactions', () {
    final tabs = buildSeoTabsNodes(
      tabs: [
        (
          label: 'Overview',
          nodes: [SeoNode(tag: 'p', text: 'Everything at a glance.')],
        ),
        (
          label: 'Details',
          nodes: [SeoNode(tag: 'p', text: 'All technical details.')],
        ),
      ],
      interactionId: 'demo-tabs',
    );

    test('visible factory keeps source complete and adds trusted assets', () {
      final html = SeoPage.visibleFromNodes(
        meta: const SeoMeta(title: 'Tabs'),
        body: tabs,
      ).toHtmlDocument();

      expect(html, contains('data-esen-seo-shell="visible"'));
      expect(html, contains('<p>Everything at a glance.</p>'));
      expect(html, contains('<p>All technical details.</p>'));
      expect(html, isNot(contains('<button')));
      expect(html, contains('<style data-esen-seo-style>'));
      expect(html, contains('<script data-esen-seo-interactions>'));
    });

    test('existing constructors remain non-interactive by default', () {
      final html = SeoPage.fromNodes(body: tabs).toHtmlDocument();

      expect(html, isNot(contains('data-esen-seo-shell')));
      expect(html, isNot(contains('data-esen-seo-interactions')));
      expect(html, isNot(contains('<style')));
    });
  });
}
