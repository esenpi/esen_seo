import 'package:esen_seo/core.dart';
import 'package:flutter_test/flutter_test.dart';

class _NavItem {
  const _NavItem(this.label, {this.url, this.children = const []});

  final String label;
  final String? url;
  final List<_NavItem> children;
}

void main() {
  const renderer = HtmlRenderer();

  group('pure component builders', () {
    test('all eleven builders are available through core.dart', () {
      const navItems = [
        _NavItem('Products', url: '/products', children: [
          _NavItem('SEO', url: '/products/seo'),
        ]),
      ];

      final output = <String, String>{
        'bar': renderer.render(buildSeoBarChartNodes(
          data: const [(label: 'A', value: 2)],
        )),
        'breadcrumbs': renderer.render(buildSeoBreadcrumbsNodes(
          items: const [(label: 'Home', url: '/')],
        )),
        'dataTable': renderer.render(buildSeoDataTableNodes(
          columns: const ['Name'],
          rows: const [
            ['Value'],
          ],
        )),
        'faq': renderer.render(buildSeoFaqNodes(
          entries: const [(question: 'Question?', answer: 'Answer.')],
        )),
        'figure': renderer.render(buildSeoFigureNodes(
          src: '/image.jpg',
          alt: 'Image',
        )),
        'listView': renderer.render(buildSeoListViewNodes(
          items: const ['Item'],
          nodeBuilder: (item, _) => [SeoNode(tag: 'p', text: item)],
        )),
        'navMenu': renderer.render(buildSeoNavMenuNodes(
          items: navItems,
          itemView: (item) => (
            label: item.label,
            url: item.url,
            children: item.children,
          ),
        )),
        'pie': renderer.render(buildSeoPieChartNodes(
          data: const [(label: 'A', value: 2, colorArgb: null)],
        )),
        'rating': renderer.render(buildSeoRatingNodes(value: 4.5)),
        'tabs': renderer.render(buildSeoTabsNodes(
          tabs: [
            (
              label: 'Overview',
              nodes: [SeoNode(tag: 'p', text: 'Content')],
            ),
          ],
        )),
        'testimonial': renderer.render(buildSeoTestimonialNodes(
          quote: 'Reliable.',
          author: 'A. User',
        )),
      };

      expect(output, hasLength(11));
      expect(output.values, everyElement(isNotEmpty));
      expect(output['navMenu'], contains('<ul><li><a href="/products">'));
      expect(output['tabs'], contains('<section><h3>Overview</h3>'));
      expect(output['tabs'], isNot(contains('data-esen-component')));
      expect(output['tabs'], isNot(contains('<button')));
    });

    test('tabs opt in with stable declarative markup and complete content', () {
      final html = renderer.render(buildSeoTabsNodes(
        tabs: [
          (
            label: 'Overview',
            nodes: [SeoNode(tag: 'p', text: 'Complete overview')],
          ),
          (
            label: 'Details',
            nodes: [SeoNode(tag: 'p', text: 'Complete details')],
          ),
        ],
        interactionId: 'product-tabs',
        interactionLabel: 'Product information',
        initialIndex: 99,
      ));

      expect(
        html,
        startsWith('<div class="esen-seo-tabs" id="product-tabs" '
            'data-esen-component="tabs" '
            'data-esen-label="Product information" '
            'data-esen-initial-index="1">'),
      );
      expect(html, contains('id="product-tabs-panel-0"'));
      expect(html, contains('id="product-tabs-panel-1"'));
      expect('data-esen-tab-panel=""'.allMatches(html), hasLength(2));
      expect(html, contains('<p>Complete overview</p>'));
      expect(html, contains('<p>Complete details</p>'));
      expect(html, isNot(contains('<button')));
      expect(html, isNot(contains('<script')));
      expect(html, isNot(contains(' hidden')));
    });

    test('invalid interaction ids leave tabs static', () {
      final html = renderer.render(buildSeoTabsNodes(
        tabs: [
          (
            label: 'Overview',
            nodes: [SeoNode(tag: 'p', text: 'Content')],
          ),
        ],
        interactionId: '1 invalid id',
      ));

      expect(
        html,
        '<div class="esen-seo-tabs">'
        '<section><h3>Overview</h3><p>Content</p></section>'
        '</div>',
      );
    });

    test('shared formatting retains the pre-extraction output contract', () {
      expect(safeChartValue(double.nan), 0);
      expect(safeDimension(double.infinity, 180), 180);
      expect(cssNumber(54), '54');
      expect(cssPercent(1, 3), '33.3');
      expect(cssColorArgb(0xFF12ABCD), '#12abcd');
      expect(cssColorArgb(0x8012ABCD), '#12abcd80');
      expect(cssColorArgb(0x0012ABCD), '#12abcd00');
    });
  });
}
