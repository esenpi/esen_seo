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
    test('all fourteen builders are available through core.dart', () {
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
        'carousel': renderer.render(buildSeoCarouselNodes(
          slides: [
            (
              label: 'First slide',
              nodes: [SeoNode(tag: 'p', text: 'First content')],
            ),
          ],
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
        'richText': renderer.render(buildSeoRichTextNodes(
          spans: const [SeoRichTextSpan.strong(text: 'Important')],
        )),
        'stepper': renderer.render(buildSeoStepperNodes(
          steps: [
            (
              label: 'Account',
              nodes: [SeoNode(tag: 'p', text: 'Account content')],
            ),
          ],
        )),
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

      expect(output, hasLength(14));
      expect(output.values, everyElement(isNotEmpty));
      expect(output['navMenu'], contains('<ul><li><a href="/products">'));
      expect(output['navMenu'], isNot(contains('data-esen-component')));
      expect(output['navMenu'], isNot(contains('<button')));
      expect(output['carousel'], contains('<section><h3>First slide</h3>'));
      expect(output['carousel'], isNot(contains('data-esen-component')));
      expect(output['carousel'], isNot(contains('<button')));
      expect(output['tabs'], contains('<section><h3>Overview</h3>'));
      expect(output['tabs'], isNot(contains('data-esen-component')));
      expect(output['tabs'], isNot(contains('<button')));
      expect(output['richText'], contains('<strong>Important</strong>'));
      expect(output['stepper'], contains('<ol><li><h3>Account</h3>'));
    });

    test('carousel opts in with stable ids and complete slide content', () {
      final html = renderer.render(buildSeoCarouselNodes(
        slides: [
          (
            label: 'Overview',
            nodes: [SeoNode(tag: 'p', text: 'Complete overview')],
          ),
          (
            label: 'Details',
            nodes: [SeoNode(tag: 'p', text: 'Complete details')],
          ),
        ],
        headingLevel: 9,
        interactionId: 'product-carousel',
        interactionLabel: 'Product gallery',
        previousLabel: 'Previous product',
        nextLabel: 'Next product',
        initialIndex: 99,
      ));

      expect(
        html,
        startsWith('<div class="esen-seo-carousel" id="product-carousel" '
            'data-esen-component="carousel" '
            'data-esen-label="Product gallery" '
            'data-esen-previous-label="Previous product" '
            'data-esen-next-label="Next product" '
            'data-esen-initial-index="1">'),
      );
      expect(html, contains('id="product-carousel-slide-0"'));
      expect(html, contains('id="product-carousel-slide-1"'));
      expect('data-esen-carousel-slide=""'.allMatches(html), hasLength(2));
      expect(html, contains('<h6>Overview</h6><p>Complete overview</p>'));
      expect(html, contains('<h6>Details</h6><p>Complete details</p>'));
      expect(html, isNot(contains('<button')));
      expect(html, isNot(contains('<script')));
      expect(html, isNot(contains(' hidden')));
    });

    test('invalid interaction ids leave carousels static', () {
      final html = renderer.render(buildSeoCarouselNodes(
        slides: [
          (
            label: 'Overview',
            nodes: [SeoNode(tag: 'p', text: 'Content')],
          ),
        ],
        interactionId: 'invalid id',
      ));

      expect(
        html,
        '<div class="esen-seo-carousel">'
        '<section><h3>Overview</h3><p>Content</p></section>'
        '</div>',
      );
    });

    test('nav menu opts in with stable branch ids and complete links', () {
      const navItems = [
        _NavItem('Home', url: '/'),
        _NavItem('Products', url: '/products', children: [
          _NavItem('Apps', url: '/products/apps'),
          _NavItem('More', children: [
            _NavItem('Consulting', url: '/products/consulting'),
          ]),
        ]),
      ];
      final html = renderer.render(buildSeoNavMenuNodes(
        items: navItems,
        itemView: (item) => (
          label: item.label,
          url: item.url,
          children: item.children,
        ),
        label: 'Primary navigation',
        interactionId: 'primary-nav',
      ));

      expect(
        html,
        startsWith('<nav class="esen-seo-nav" '
            'aria-label="Primary navigation" id="primary-nav" '
            'data-esen-component="nav-menu">'
            '<ul data-esen-nav-root-list="">'),
      );
      expect(html, contains('id="primary-nav-submenu-1"'));
      expect(html, contains('id="primary-nav-submenu-1-1"'));
      expect('data-esen-nav-branch=""'.allMatches(html), hasLength(2));
      expect('data-esen-nav-submenu=""'.allMatches(html), hasLength(2));
      expect(html, contains('<a href="/products/apps">Apps</a>'));
      expect(html, contains('<a href="/products/consulting">Consulting</a>'));
      expect(html, isNot(contains('<button')));
      expect(html, isNot(contains(' hidden')));
    });

    test('invalid interaction ids leave nav menus byte-identical', () {
      const navItems = [
        _NavItem('Products', children: [
          _NavItem('Apps', url: '/apps'),
        ]),
      ];
      final html = renderer.render(buildSeoNavMenuNodes(
        items: navItems,
        itemView: (item) => (
          label: item.label,
          url: item.url,
          children: item.children,
        ),
        interactionId: 'invalid id',
      ));

      expect(
        html,
        '<nav class="esen-seo-nav" aria-label="Hauptnavigation"><ul>'
        '<li><span>Products</span><ul>'
        '<li><a href="/apps">Apps</a></li>'
        '</ul></li></ul></nav>',
      );
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

    test('stepper opts in with ordered complete content and stable ids', () {
      final html = renderer.render(buildSeoStepperNodes(
        steps: [
          (
            label: 'Account',
            nodes: [SeoNode(tag: 'p', text: 'Account content')],
          ),
          (
            label: 'Review',
            nodes: [SeoNode(tag: 'p', text: 'Review content')],
          ),
        ],
        headingLevel: 9,
        interactionId: 'checkout-steps',
        interactionLabel: 'Checkout',
        previousLabel: 'Previous',
        nextLabel: 'Continue',
        positionLabel: 'Stage',
        initialIndex: 99,
      ));

      expect(
        html,
        startsWith('<div class="esen-seo-stepper" id="checkout-steps" '
            'data-esen-component="stepper" data-esen-label="Checkout" '
            'data-esen-previous-label="Previous" '
            'data-esen-next-label="Continue" '
            'data-esen-position-label="Stage" '
            'data-esen-initial-index="1">'
            '<ol data-esen-step-list="">'),
      );
      expect(html, contains('id="checkout-steps-step-0"'));
      expect(html, contains('id="checkout-steps-panel-1"'));
      expect('data-esen-step=""'.allMatches(html), hasLength(2));
      expect('data-esen-step-panel=""'.allMatches(html), hasLength(2));
      expect(html, contains('<h6>Account</h6>'));
      expect(html, contains('<p>Review content</p>'));
      expect(html, isNot(contains('<button')));
      expect(html, isNot(contains(' hidden')));
    });

    test('invalid interaction ids leave steppers static and complete', () {
      final html = renderer.render(buildSeoStepperNodes(
        steps: [
          (
            label: 'Account',
            nodes: [SeoNode(tag: 'p', text: 'Account content')],
          ),
        ],
        interactionId: 'invalid id',
      ));

      expect(
        html,
        '<div class="esen-seo-stepper"><ol><li><h3>Account</h3>'
        '<div><p>Account content</p></div></li></ol></div>',
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
