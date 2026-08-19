// Die SEO-Routen-Tabelle — die Single Source of Truth für URLs,
// Meta-Daten und (serverseitig) den semantischen Body.
//
// Pures Dart ohne Flutter-Imports: main.dart (App) und bin/server.dart
// (SSR-Server) lesen BEIDE diese Datei — nichts driftet auseinander.
import 'package:esen_seo/core.dart';

const siteBase = 'https://esen.software';

typedef DemoTabData = ({String content, String label});
typedef DemoCarouselData = ({String content, String label});
typedef DemoStepperData = ({String content, String label});

class DemoNavData {
  const DemoNavData(this.label, {this.url, this.children = const []});

  final String label;
  final String? url;
  final List<DemoNavData> children;
}

const demoNavItems = <DemoNavData>[
  DemoNavData('Home', url: '/'),
  DemoNavData('Documentation', url: '/docs', children: [
    DemoNavData('Live demo', url: '/demo'),
    DemoNavData('Full guide', url: '/docs'),
  ]),
  DemoNavData('More', children: [
    DemoNavData('Dynamic routes', url: '/blog/dynamic-routes'),
  ]),
];

const demoTabs = <DemoTabData>[
  (
    label: 'Flutter',
    content: 'The same data renders as a native Flutter tab on every platform.',
  ),
  (
    label: 'HTML',
    content: 'Every panel is present as semantic HTML before JavaScript runs.',
  ),
  (
    label: 'JavaScript',
    content:
        'The visible web page progressively gains accessible tab controls.',
  ),
];

const demoRichTextSpans = <SeoRichTextSpan>[
  SeoRichTextSpan.text('One model keeps '),
  SeoRichTextSpan.strong(text: 'important text'),
  SeoRichTextSpan.text(', '),
  SeoRichTextSpan.emphasis(text: 'emphasis'),
  SeoRichTextSpan.text(', '),
  SeoRichTextSpan.code(text: 'inline code'),
  SeoRichTextSpan.text(' and '),
  SeoRichTextSpan.link(href: '/docs', text: 'real links'),
  SeoRichTextSpan.text(' in Flutter and HTML.'),
];

const demoCarouselSlides = <DemoCarouselData>[
  (
    label: 'One source',
    content: 'Flutter and semantic HTML are derived from the same slide data.',
  ),
  (
    label: 'Complete source',
    content: 'Every slide remains readable before JavaScript is available.',
  ),
  (
    label: 'Progressive controls',
    content: 'Vanilla JavaScript adds navigation only after validation.',
  ),
];

const demoStepperSteps = <DemoStepperData>[
  (
    label: 'Choose content',
    content: 'Define every step once in a shared data model.',
  ),
  (
    label: 'Render everywhere',
    content: 'Flutter stays lazy while semantic HTML contains every body.',
  ),
  (
    label: 'Enhance safely',
    content: 'Validated vanilla JavaScript adds controls to the visible shell.',
  ),
];

List<SeoNode> demoTabPanelNodes(DemoTabData tab) => [
      SeoNode(tag: 'p', text: tab.content),
    ];

List<SeoTabComponentEntry> demoTabEntries() => [
      for (final tab in demoTabs)
        (label: tab.label, nodes: demoTabPanelNodes(tab)),
    ];

List<SeoNode> demoCarouselSlideNodes(DemoCarouselData slide) => [
      SeoNode(tag: 'p', text: slide.content),
    ];

List<SeoCarouselComponentEntry> demoCarouselEntries() => [
      for (final slide in demoCarouselSlides)
        (label: slide.label, nodes: demoCarouselSlideNodes(slide)),
    ];

List<SeoNode> demoStepperBodyNodes(DemoStepperData step) => [
      SeoNode(tag: 'p', text: step.content),
    ];

List<SeoStepperComponentEntry> demoStepperEntries() => [
      for (final step in demoStepperSteps)
        (label: step.label, nodes: demoStepperBodyNodes(step)),
    ];

List<SeoNode> demoStepperNodes({
  String interactionId = 'demo-stepper',
  String interactionLabel = 'Publishing flow',
}) =>
    buildSeoStepperNodes(
      steps: demoStepperEntries(),
      interactionId: interactionId,
      interactionLabel: interactionLabel,
    );

List<SeoNode> demoCarouselNodes({
  String interactionId = 'demo-carousel',
  String interactionLabel = 'Rendering carousel',
}) =>
    buildSeoCarouselNodes(
      slides: demoCarouselEntries(),
      interactionId: interactionId,
      interactionLabel: interactionLabel,
    );

List<SeoNode> demoNavNodes() => buildSeoNavMenuNodes(
      items: demoNavItems,
      itemView: (item) => (
        label: item.label,
        url: item.url,
        children: item.children,
      ),
      label: 'Demo navigation',
      interactionId: 'demo-nav',
    );

// A tiny in-memory "database" so the dynamic route below runs anywhere,
// without a real backend. In a CMS this is a Postgres/Firestore read.
const _posts = <String, ({String title, String teaser, String body})>{
  'why-flutter-seo': (
    title: 'Why Flutter Web needs real SEO',
    teaser: 'A widget tree is not a document — here is the gap.',
    body: 'Flutter renders to a canvas, so a crawler finds no headings, '
        'paragraphs or links to read. esen_seo mirrors the tree as '
        'semantic HTML from the same source.',
  ),
  'dynamic-routes': (
    title: 'One read, one page: dynamic routes',
    teaser: 'Title, description and body from a single database record.',
    body: 'SeoRoute.dynamic resolves metadata and body together, so the '
        'page a user sees and the entry in sitemap.xml can never drift '
        'apart.',
  ),
};

final seoRoutes = [
  SeoRoute(
    path: '/',
    // canonicalUrl wird automatisch aus siteBase + Pfad abgeleitet.
    meta: (_) => SeoMeta(
      title: 'esen_seo — Real SEO for Flutter Web',
      description: 'No Puppeteer, no tricks. Pure Dart that mirrors your '
          'Flutter widgets as clean semantic HTML.',
      openGraph: const OpenGraphMeta(
        image: 'https://picsum.photos/seed/esen_seo/1200/630',
      ),
      schemas: [
        SeoSchema.organization(name: 'Esen Software', url: siteBase),
        SeoSchema.website(name: 'esen_seo', url: siteBase),
      ],
    ),
    body: (_) => [
      SeoNode(tag: 'h1', text: 'Real SEO for Flutter Web'),
      SeoNode(tag: 'p', text: 'No Puppeteer. No tricks. Pure Dart.'),
      SeoNode(tag: 'ul', children: [
        SeoNode(tag: 'li', text: 'Semantic HTML — h1 to h6, p, section...'),
        SeoNode(tag: 'li', text: 'Meta Tags, OpenGraph, Twitter Cards'),
        SeoNode(tag: 'li', text: 'Schema.org JSON-LD'),
        SeoNode(tag: 'li', text: 'Bot-aware SSR Server — pure Dart'),
        SeoNode(tag: 'li', text: 'Smart Defaults — page never breaks'),
      ]),
      SeoNode(tag: 'section', children: [
        SeoNode(tag: 'h2', text: 'About'),
        SeoNode(
          tag: 'p',
          text: 'esen_seo mirrors your Flutter widget tree as clean '
              'semantic HTML — right in the DOM, without Puppeteer or '
              'headless Chrome.',
        ),
      ]),
      SeoNode(
        tag: 'a',
        text: 'View Live Demo',
        attributes: {'href': '/demo'},
      ),
    ],
  ),
  SeoRoute(
    path: '/demo',
    meta: (_) => SeoMeta(
      title: 'Live Demo — esen_seo',
      description: 'See esen_seo in action',
      schemas: [
        SeoSchema.breadcrumbs([
          (name: 'Home', url: '$siteBase/'),
          (name: 'Demo', url: '$siteBase/demo'),
        ]),
        SeoSchema.faq([
          (
            question: 'Does esen_seo work on mobile?',
            answer: 'Yes! On mobile all .seo() calls are no-ops — '
                'zero performance impact.',
          ),
          (
            question: 'Does it need Puppeteer?',
            answer: 'No. esen_seo uses pure Dart for server-side rendering.',
          ),
        ]),
      ],
    ),
    body: (_) => [
      SeoNode(tag: 'h1', text: 'Live Demo'),
      SeoNode(tag: 'p', text: 'See esen_seo in action.'),
      ...buildSeoRichTextNodes(spans: demoRichTextSpans),
      ...demoNavNodes(),
      ...demoCarouselNodes(),
      ...buildSeoTabsNodes(
        tabs: demoTabEntries(),
        interactionId: 'demo-tabs',
        interactionLabel: 'Rendering targets',
      ),
      ...demoStepperNodes(),
      SeoNode(tag: 'a', text: 'Back to Home', attributes: {'href': '/'}),
    ],
  ),
  SeoRoute(
    path: '/dom-first-tabs',
    delivery: SeoRouteDelivery.domFirst,
    domFirstFeatures: const {SeoDomFirstFeature.tabs},
    meta: (_) => SeoMeta(
      title: 'DOM-first Tabs — esen_seo',
      description: 'A permanent semantic HTML route with accessible tabs '
          'compiled from the same pure Dart transition as Flutter.',
      schemas: [
        SeoSchema.breadcrumbs([
          (name: 'Home', url: '$siteBase/'),
          (name: 'DOM-first Tabs', url: '$siteBase/dom-first-tabs'),
        ]),
      ],
    ),
    body: (_) => [
      SeoNode(tag: 'h1', text: 'DOM-first Tabs'),
      SeoNode(
        tag: 'p',
        text: 'This route is complete HTML before JavaScript runs and does '
            'not load the Flutter web engine.',
      ),
      ...buildSeoTabsNodes(
        tabs: demoTabEntries(),
        interactionId: 'dom-first-demo-tabs',
        interactionLabel: 'Rendering targets',
      ),
      SeoNode(tag: 'a', text: 'Back to Home', attributes: {'href': '/'}),
    ],
  ),
  SeoRoute(
    path: '/dom-first-carousel',
    delivery: SeoRouteDelivery.domFirst,
    domFirstFeatures: const {SeoDomFirstFeature.carousel},
    meta: (_) => SeoMeta(
      title: 'DOM-first Carousel — esen_seo',
      description: 'A complete semantic carousel progressively enhanced by '
          'the package-owned compiled Dart transition.',
      schemas: [
        SeoSchema.breadcrumbs([
          (name: 'Home', url: '$siteBase/'),
          (name: 'DOM-first Carousel', url: '$siteBase/dom-first-carousel'),
        ]),
      ],
    ),
    body: (_) => [
      SeoNode(tag: 'h1', text: 'DOM-first Carousel'),
      SeoNode(
        tag: 'p',
        text: 'Every slide is present before JavaScript runs. The compiled '
            'adapter adds accessible navigation without loading Flutter.',
      ),
      ...demoCarouselNodes(
        interactionId: 'dom-first-demo-carousel',
        interactionLabel: 'Rendering carousel',
      ),
      SeoNode(tag: 'a', text: 'Back to Home', attributes: {'href': '/'}),
    ],
  ),
  SeoRoute(
    path: '/dom-first-application-tabs',
    delivery: SeoRouteDelivery.domFirst,
    applicationRuntime:
        const SeoDomFirstApplicationRuntime.tabs('example-tabs'),
    meta: (_) => SeoMeta(
      title: 'Application Tabs — esen_seo',
      description: 'Application-authored pure Dart state logic compiled for '
          'the permanent semantic page.',
    ),
    body: (_) => [
      SeoNode(tag: 'h1', text: 'Application-owned Tabs'),
      SeoNode(
        tag: 'p',
        text: 'The application transition stops at either end instead of '
            'wrapping. Flutter and this DOM-first route call the same '
            'pure Dart function.',
      ),
      ...buildSeoTabsNodes(
        tabs: demoTabEntries(),
        interactionId: 'application-demo-tabs',
        interactionLabel: 'Application rendering targets',
      ),
      SeoNode(tag: 'a', text: 'Back to Home', attributes: {'href': '/'}),
    ],
  ),
  SeoRoute(
    path: '/dom-first-application-stepper',
    delivery: SeoRouteDelivery.domFirst,
    applicationRuntime:
        const SeoDomFirstApplicationRuntime.stepper('example-stepper'),
    meta: (_) => SeoMeta(
      title: 'Application Stepper — esen_seo',
      description: 'Application-authored pure Dart stepper logic compiled '
          'for the permanent semantic page.',
    ),
    body: (_) => [
      SeoNode(tag: 'h1', text: 'Application-owned Stepper'),
      SeoNode(
        tag: 'p',
        text: 'The application transition wraps previous and next at either '
            'end. Flutter and this DOM-first route call the same pure Dart '
            'function.',
      ),
      ...demoStepperNodes(
        interactionId: 'application-demo-stepper',
        interactionLabel: 'Application publishing flow',
      ),
      SeoNode(tag: 'a', text: 'Back to Home', attributes: {'href': '/'}),
    ],
  ),
  SeoRoute(
    path: '/dom-first-application-carousel',
    delivery: SeoRouteDelivery.domFirst,
    applicationRuntime:
        const SeoDomFirstApplicationRuntime.carousel('example-carousel'),
    meta: (_) => SeoMeta(
      title: 'Application Carousel — esen_seo',
      description: 'Application-authored pure Dart carousel logic compiled '
          'for the permanent semantic page.',
    ),
    body: (_) => [
      SeoNode(tag: 'h1', text: 'Application-owned Carousel'),
      SeoNode(
        tag: 'p',
        text: 'The application transition wraps previous and next at either '
            'end. Flutter and this DOM-first route call the same pure Dart '
            'function.',
      ),
      ...demoCarouselNodes(
        interactionId: 'application-demo-carousel',
        interactionLabel: 'Application rendering carousel',
      ),
      SeoNode(tag: 'a', text: 'Back to Home', attributes: {'href': '/'}),
    ],
  ),
  SeoRoute(
    path: '/docs',
    // Erscheint als <lastmod> in der sitemap.xml.
    lastModified: DateTime.utc(2026, 7, 31),
    meta: (_) => SeoMeta(
      title: 'Documentation — esen_seo',
      description: 'How to add real SEO to a Flutter Web app: widget '
          'extensions, meta tags, JSON-LD, routing, SSR server and '
          'static prerendering — step by step.',
      schemas: [
        SeoSchema.breadcrumbs([
          (name: 'Home', url: '$siteBase/'),
          (name: 'Documentation', url: '$siteBase/docs'),
        ]),
      ],
    ),
    body: (_) => [
      SeoNode(tag: 'h1', text: 'Documentation'),
      SeoNode(
        tag: 'p',
        text: 'Everything you need to give a Flutter Web app real SEO — '
            'step by step, copy-paste ready.',
      ),
      SeoNode(tag: 'section', children: [
        SeoNode(tag: 'h2', text: '1. Install & init'),
        SeoNode(
          tag: 'p',
          text: 'Add the package and call EsenSeo.init(cleanUrls: true) '
              'before runApp. On mobile and desktop every call is a no-op.',
        ),
      ]),
      SeoNode(tag: 'section', children: [
        SeoNode(tag: 'h2', text: '2. Mirror your widgets'),
        SeoNode(
          tag: 'p',
          text: 'One change per widget: Text(...).h1, Column(...).section, '
              'Image(...).seo(alt: ...), GestureDetector(...).seo(href: ...). '
              'Smart defaults render pages even without any .seo() calls.',
        ),
      ]),
      SeoNode(tag: 'section', children: [
        SeoNode(tag: 'h2', text: '3. Tags & attributes'),
        SeoNode(
          tag: 'p',
          text: 'Typed tags with IDE autocomplete, HTML attributes as a '
              'second argument, width/height/lazy for images, rel/hreflang '
              'for links. Dangerous tags and attributes are blocked safely.',
        ),
      ]),
      SeoNode(tag: 'section', children: [
        SeoNode(tag: 'h2', text: '4. Meta tags & social previews'),
        SeoNode(
          tag: 'p',
          text: 'EsenSeo.setMeta sets title, description, canonical, '
              'OpenGraph, Twitter Cards and hreflang alternates with '
              'smart fallbacks.',
        ),
      ]),
      SeoNode(tag: 'section', children: [
        SeoNode(tag: 'h2', text: '5. Structured data (JSON-LD)'),
        SeoNode(
          tag: 'p',
          text: 'Typed Schema.org builders for Article, Product (with '
              'AggregateRating), Review, Event, LocalBusiness, '
              'Organization, WebSite, BreadcrumbList and FAQPage — plus a '
              'generic constructor for every other type.',
        ),
      ]),
      SeoNode(tag: 'section', children: [
        SeoNode(tag: 'h2', text: '6. Routing — one table for everything'),
        SeoNode(
          tag: 'p',
          text: 'Define routes once in pure Dart: the app applies meta '
              'tags automatically on navigation, the server renders the '
              'same pages for bots, sitemap.xml and canonical URLs are '
              'derived from the same table.',
        ),
      ]),
      SeoNode(tag: 'section', children: [
        SeoNode(tag: 'h2', text: '7. SSR server for bots'),
        SeoNode(
          tag: 'p',
          text: 'A shelf middleware serves crawlers real HTML documents, '
              'plus sitemap.xml, robots.txt, llms.txt, real 404s and 301 '
              'redirects.',
        ),
      ]),
      SeoNode(tag: 'section', children: [
        SeoNode(tag: 'h2', text: '8. Static prerendering'),
        SeoNode(
          tag: 'p',
          text: 'prerenderSite() bakes every route into build/web as a '
              'real HTML file — full SEO on static hosting without any '
              'server.',
        ),
      ]),
      SeoNode(tag: 'section', children: [
        SeoNode(tag: 'h2', text: '9. llms.txt & IndexNow'),
        SeoNode(
          tag: 'p',
          text: 'llms.txt and llms-full.txt make the site legible to AI '
              'assistants; submitIndexNow() pings search engines about '
              'changed URLs within minutes instead of days.',
        ),
      ]),
      SeoNode(tag: 'section', children: [
        SeoNode(tag: 'h2', text: '10. Safe & strict mode'),
        SeoNode(
          tag: 'p',
          text: 'SeoMode.safe never breaks; SeoMode.strict warns about '
              'widgets without .seo() and blocked tags while developing.',
        ),
      ]),
      SeoNode(tag: 'section', children: [
        SeoNode(tag: 'h2', text: '11. Verify your SEO'),
        SeoNode(
          tag: 'p',
          text: 'Check #esen-seo-content in DevTools, curl the server '
              'with a bot user agent, validate JSON-LD with the Rich '
              'Results Test and submit the sitemap in Search Console.',
        ),
      ]),
      SeoNode(tag: 'a', text: 'Back to Home', attributes: {'href': '/'}),
    ],
  ),
  // A dynamic, database-style route. One resolve() read produces the
  // metadata AND the body for /blog/<slug>, and enumeratePaths lists the
  // concrete URLs so the sitemap, llms.txt and the prerenderer can bake
  // them. An unknown slug resolves to a real 404.
  SeoRoute.dynamic(
    path: '/blog/:slug',
    enumeratePaths: () async =>
        _posts.keys.map((slug) => '/blog/$slug').toList(),
    resolve: (request) async {
      final post = _posts[request.param('slug')];
      if (post == null) return SeoDocument.notFound();
      return SeoDocument(
        meta: SeoMeta(
          title: '${post.title} — esen_seo',
          description: post.teaser,
          schemas: [
            SeoSchema.breadcrumbs([
              (name: 'Home', url: '$siteBase/'),
              (name: post.title, url: '$siteBase/blog/${request['slug']}'),
            ]),
          ],
        ),
        // The head request (sitemap/llms) needs no body — skipping it
        // keeps enumeration cheap.
        body: request.detail == SeoDetail.head
            ? const []
            : [
                SeoNode(tag: 'h1', text: post.title),
                SeoNode(tag: 'p', text: post.body),
                SeoNode(
                    tag: 'a', text: 'Back to Home', attributes: {'href': '/'}),
              ],
        lastModified: DateTime.utc(2026, 8, 1),
      );
    },
  ),
];
