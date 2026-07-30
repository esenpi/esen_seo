import 'package:esen_seo/esen_seo.dart';
import 'package:flutter/material.dart';

import 'widgets.dart';

/// Die Dokumentationsseite ('/docs') — jede Überschrift, jeder Absatz
/// und jeder Code-Block wird selbst per .seo() als semantisches HTML
/// gespiegelt. Die Seite dokumentiert das Package und IST die Demo.
class DocsPage extends StatefulWidget {
  const DocsPage({super.key});

  @override
  State<DocsPage> createState() => _DocsPageState();
}

class _DocsPageState extends State<DocsPage> {
  final Map<String, GlobalKey> _sectionKeys = {};

  GlobalKey _keyFor(String title) =>
      _sectionKeys.putIfAbsent(title, GlobalKey.new);

  void _scrollTo(String title) {
    final context = _sectionKeys[title]?.currentContext;
    if (context == null) return;
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final sections = _sections();

    return PageScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 28,
        children: [
          Text(
            'Documentation',
            style: Theme.of(context).textTheme.displaySmall,
          ).h1,
          const Para(
            'Everything you need to give a Flutter Web app real SEO — '
            'step by step, copy-paste ready. Open DevTools → Elements '
            'and watch this very page mirror itself into '
            '#esen-seo-content while you read.',
          ),

          // Inhaltsverzeichnis mit Sprungmarken.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final section in sections)
                ActionChip(
                  label: Text(section.title),
                  onPressed: () => _scrollTo(section.title),
                ),
            ],
          ),
          const Divider(),

          for (final section in sections)
            KeyedSubtree(
              key: _keyFor(section.title),
              child: DocSection(
                title: section.title,
                children: section.children,
              ),
            ),
        ],
      ).main,
    );
  }

  List<({String title, List<Widget> children})> _sections() => [
        (
          title: '1. Install & init',
          children: [
            const Para(
              'Add the package and start the pipeline before runApp. '
              'That is the whole setup — on mobile and desktop every '
              'esen_seo call is a no-op, your widgets stay untouched.',
            ),
            const CodeBlock(
              'dependencies:\n'
              '  esen_seo: ^0.1.0',
            ),
            CodeBlock(r'''
void main() {
  // cleanUrls: path URLs (/demo) instead of /#/demo —
  // crawlers ignore hash fragments.
  EsenSeo.init(cleanUrls: true);
  runApp(const MyApp());
}'''
                .trim()),
          ],
        ),
        (
          title: '2. Mirror your widgets',
          children: [
            const Para(
              'One change per widget: append .seo() — or a shorthand '
              'like .h1. The Flutter UI is never affected; the widget '
              'is mirrored as semantic HTML next to the canvas.',
            ),
            CodeBlock(r'''
Text('Welcome').h1                        // → <h1>Welcome</h1>
Text('We build apps.').p                  // → <p>We build apps.</p>
Column(children: [...]).section           // → <section>…</section>
Column(children: [
  Text('First').li,
  Text('Second').li,
]).ul                                     // → <ul><li>…</li></ul>
Image.network(url).seo(alt: 'Our team')   // → <img alt="Our team"/>
GestureDetector(
  onTap: () => context.go('/contact'),
  child: Text('Contact'),
).seo(href: '/contact')                   // → <a href="/contact">'''
                .trim()),
            const Para(
              'Shorthands: .h1–.h6, .p, .span, .li, .blockquote, .code '
              'on Text — .section, .article, .nav, .aside, .header, '
              '.footer, .main, .ul, .ol, .figure on Column — .nav, '
              '.header, .footer, .ul, .tr on Row.',
            ),
            const Para(
              'Smart defaults: even without any .seo() call the page '
              'renders — the first text becomes <h1>, following texts '
              '<p>, images <img> with their semanticLabel as alt text. '
              'The page never breaks.',
            ),
          ],
        ),
        (
          title: '3. Tags & attributes',
          children: [
            const Para(
              'Every standard HTML tag works via the typed constants — '
              'typos are compile errors. HTML attributes go in as a '
              'second argument.',
            ),
            CodeBlock(r'''
Text('Quote').seo(SeoTextTag.blockquote)
Text('12 July').seo(SeoTextTag.time, {'datetime': '2026-07-12'})
Column(children: [...]).seo(SeoContainerTag.section, {'id': 'pricing'})
Text('Exotic').seo(SeoTextTag('bdo'))     // custom tags stay possible

// Images: dimensions help Core Web Vitals (CLS), lazy loading:
Image.network(url).seo(alt: 'Team', width: 800, height: 400, lazy: true)

// Links: rel and hreflang:
GestureDetector(...).seo(href: '/legal', rel: 'nofollow')'''
                .trim()),
            const Para(
              'Safety net: dangerous tags (script, style, iframe, …) '
              'fall back to span/div, event-handler attributes '
              '(onclick, …) and javascript: URLs are dropped. In '
              'SeoMode.strict you get a debug warning for each.',
            ),
          ],
        ),
        (
          title: '4. Meta tags & social previews',
          children: [
            const Para(
              'One setMeta call per page sets <title>, description, '
              'canonical URL, OpenGraph and Twitter Cards. Smart '
              'fallbacks keep it short: og:title falls back to title, '
              'og:image implies a large Twitter card, and so on.',
            ),
            CodeBlock(r'''
EsenSeo.setMeta(SeoMeta(
  title: 'Yahya Esen — Flutter Developer in Munich',
  description: 'Flutter apps with real SEO.',
  canonicalUrl: 'https://esen.software/',
  openGraph: OpenGraphMeta(image: 'https://esen.software/og.png'),
));'''
                .trim()),
            const Para(
              'International pages declare their language variants — '
              'rendered as <link rel="alternate" hreflang="…"> tags:',
            ),
            CodeBlock(r'''
SeoMeta(
  alternates: {
    'de': 'https://esen.software/',
    'en': 'https://esen.software/en/',
    'x-default': 'https://esen.software/',
  },
)'''
                .trim()),
          ],
        ),
        (
          title: '5. Structured data (JSON-LD)',
          children: [
            const Para(
              'Schema.org data unlocks rich results — product prices, '
              'star ratings, FAQs and breadcrumbs directly in Google. '
              'Typed builders cover the common types; everything else '
              'goes through the generic constructor.',
            ),
            CodeBlock(r'''
SeoMeta(
  schemas: [
    SeoSchema.article(headline: 'Real SEO for Flutter Web', author: 'Yahya Esen'),
    SeoSchema.breadcrumbs([
      (name: 'Home', url: 'https://esen.software/'),
      (name: 'Blog', url: 'https://esen.software/blog'),
    ]),
    SeoSchema.faq([
      (question: 'Does it need Puppeteer?', answer: 'No — pure Dart.'),
    ]),
    SeoSchema('Recipe', {'name': 'Lentil soup', 'cookTime': 'PT45M'}),
  ],
)'''
                .trim()),
          ],
        ),
        (
          title: '6. Routing — one table for everything',
          children: [
            const Para(
              'The recommended setup: define your routes once in a '
              'pure-Dart file. The app, the SSR server, the sitemap and '
              'the prerenderer all read the same table — nothing can '
              'drift apart.',
            ),
            CodeBlock(r'''
// lib/seo_routes.dart — no Flutter imports!
import 'package:esen_seo/core.dart';

const siteBase = 'https://esen.software';

final seoRoutes = [
  SeoRoute(
    path: '/',
    meta: (_) => SeoMeta(title: 'Yahya Esen — Flutter Developer in Munich'),
    body: (_) => [SeoNode(tag: 'h1', text: 'Flutter apps that rank.')],
  ),
  SeoRoute(
    path: '/blog/:slug',   // path parameters
    meta: (params) => SeoMeta(title: 'Blog — ${params['slug']}'),
  ),
];'''
                .trim()),
            const Para(
              'In the app, register the observer — meta tags then '
              'update automatically on every navigation, and canonical '
              'URLs are derived from siteBase:',
            ),
            CodeBlock(r'''
MaterialApp(
  navigatorObservers: [
    SeoRouteObserver(routes: seoRoutes, canonicalBase: siteBase),
  ],
  routes: {...},
)'''
                .trim()),
          ],
        ),
        (
          title: '7. SSR server for bots',
          children: [
            const Para(
              'Many crawlers (social link previews, AI bots) never '
              'execute JavaScript. The shelf middleware detects them by '
              'User-Agent and serves the full HTML document straight '
              'from your route table — real users get the Flutter app.',
            ),
            CodeBlock(r'''
// bin/server.dart — pure Dart, runs with `dart run`
final handler = const Pipeline()
    .addMiddleware(seoRedirectMiddleware(
      canonicalHost: 'esen.software', // www → apex (301)
      forceHttps: true,
      redirects: {'/old': '/new'},
    ))
    .addMiddleware(seoBotMiddleware(routes: seoRoutes, siteBase: siteBase))
    .addHandler(createStaticHandler('build/web',
        defaultDocument: 'index.html'));
await io.serve(handler, InternetAddress.anyIPv4, 8080);'''
                .trim()),
            const Bullets([
              'sitemap.xml and robots.txt are generated from the table',
              'unknown paths get a real HTTP 404 (no SPA soft-404)',
              'path parameters like /blog/:slug resolve automatically',
            ]),
          ],
        ),
        (
          title: '8. Static prerendering (no server)',
          children: [
            const Para(
              'Hosting on Firebase Hosting, GitHub Pages or a CDN? Bake '
              'the route table into the build — every route becomes a '
              'real HTML file with meta tags and semantic content in '
              'the page source. No bot detection needed: everyone gets '
              'the same file, and the running app takes the content '
              'over seamlessly (hydration).',
            ),
            CodeBlock(r'''
// bin/prerender.dart
Future<void> main() async {
  await prerenderSite(routes: seoRoutes, siteBase: siteBase);
}'''
                .trim()),
            const CodeBlock(
              'flutter build web\n'
              'dart run bin/prerender.dart\n'
              '# → deploy build/web to any static host',
            ),
            const Para(
              'Trade-off: prerendered pages are a build-time snapshot. '
              'For frequently changing content, use the SSR server.',
            ),
          ],
        ),
        (
          title: '9. Safe & strict mode',
          children: [
            const Para(
              'SeoMode.safe (default) renders everything and never '
              'breaks. SeoMode.strict additionally prints a debug '
              'warning for every widget without .seo() and for every '
              'blocked tag or attribute — perfect while developing.',
            ),
            const CodeBlock('EsenSeo.init(mode: SeoMode.strict);'),
          ],
        ),
        (
          title: '10. Verify your SEO',
          children: [
            const Para('Foolproof checklist — in this order:'),
            const Bullets([
              'DevTools → Elements: #esen-seo-content at the end of '
                  '<body> mirrors this page as semantic HTML',
              'curl -A "Googlebot/2.1" http://localhost:8080 — the SSR '
                  'answer with full HTML in the source',
              'curl http://localhost:8080/sitemap.xml and /robots.txt',
              'After prerendering: View Source (Ctrl+U) shows the '
                  'content directly',
              'Paste your URL into Google\'s Rich Results Test to '
                  'validate the JSON-LD schemas',
              'Submit the sitemap in Google Search Console',
            ]),
          ],
        ),
      ];
}
