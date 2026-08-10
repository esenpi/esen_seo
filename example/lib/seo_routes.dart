// Die SEO-Routen-Tabelle — die Single Source of Truth für URLs,
// Meta-Daten und (serverseitig) den semantischen Body.
//
// Pures Dart ohne Flutter-Imports: main.dart (App) und bin/server.dart
// (SSR-Server) lesen BEIDE diese Datei — nichts driftet auseinander.
import 'package:esen_seo/core.dart';

const siteBase = 'https://esen.software';

typedef DemoTabData = ({String content, String label});

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

List<SeoNode> demoTabPanelNodes(DemoTabData tab) => [
      SeoNode(tag: 'p', text: tab.content),
    ];

List<SeoTabComponentEntry> demoTabEntries() => [
      for (final tab in demoTabs)
        (label: tab.label, nodes: demoTabPanelNodes(tab)),
    ];

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
      ...buildSeoTabsNodes(
        tabs: demoTabEntries(),
        interactionId: 'demo-tabs',
        interactionLabel: 'Rendering targets',
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
