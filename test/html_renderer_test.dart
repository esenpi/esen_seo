import 'package:esen_seo/src/renderer/html_renderer.dart';
import 'package:esen_seo/src/renderer/seo_node.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const renderer = HtmlRenderer();

  group('HtmlRenderer', () {
    test('renders a simple text element', () {
      final node = SeoNode(tag: 'h1', text: 'Willkommen');
      expect(renderer.renderNode(node), '<h1>Willkommen</h1>');
    });

    test('renders attributes', () {
      final node = SeoNode(
        tag: 'a',
        text: 'Über uns',
        attributes: {'href': '/about', 'title': 'Mehr'},
      );
      expect(
        renderer.renderNode(node),
        '<a href="/about" title="Mehr">Über uns</a>',
      );
    });

    test('renders img as self-closing element', () {
      final node = SeoNode(
        tag: 'img',
        attributes: {'src': 'foto.png', 'alt': 'Ein Foto'},
      );
      expect(renderer.renderNode(node), '<img src="foto.png" alt="Ein Foto"/>');
    });

    test('renders nested children in order', () {
      final node = SeoNode(
        tag: 'div',
        children: [
          SeoNode(tag: 'h1', text: 'Titel'),
          SeoNode(tag: 'p', text: 'Absatz'),
        ],
      );
      expect(
        renderer.renderNode(node),
        '<div><h1>Titel</h1><p>Absatz</p></div>',
      );
    });

    test('renders raw text nodes without a tag', () {
      final node = SeoNode(
        tag: 'a',
        attributes: {'href': '/x'},
        children: [SeoNode.text('Label')],
      );
      expect(renderer.renderNode(node), '<a href="/x">Label</a>');
    });

    test('escapes text content', () {
      final node = SeoNode(tag: 'p', text: 'A & B <C>');
      expect(renderer.renderNode(node), '<p>A &amp; B &lt;C&gt;</p>');
    });

    test('escapes attribute values', () {
      final node = SeoNode(
        tag: 'img',
        attributes: {'src': 'x.png', 'alt': 'ein "Zitat" & mehr'},
      );
      expect(
        renderer.renderNode(node),
        '<img src="x.png" alt="ein &quot;Zitat&quot; &amp; mehr"/>',
      );
    });

    test('render joins multiple top-level nodes', () {
      final nodes = [
        SeoNode(tag: 'h1', text: 'Titel'),
        SeoNode(tag: 'p', text: 'Absatz'),
      ];
      expect(renderer.render(nodes), '<h1>Titel</h1><p>Absatz</p>');
    });
  });
}
