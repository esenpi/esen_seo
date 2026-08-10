import 'package:esen_seo/esen_seo.dart';
import 'package:flutter/material.dart';

import 'docs_page.dart';
import 'seo_routes.dart';
import 'theme.dart';
import 'widgets.dart';

void main() {
  // cleanUrls: Path-URLs (/demo) statt Hash-Fragmente (/#/demo) —
  // Crawler ignorieren Fragmente. Der SeoRouteObserver unten setzt die
  // Meta-Daten pro Route automatisch aus der geteilten Tabelle.
  EsenSeo.init(cleanUrls: true);
  runApp(const EsenSeoExampleApp());
}

final Map<String, WidgetBuilder> _pages = {
  '/': (_) => const HomePage(),
  '/demo': (_) => const DemoPage(),
  '/docs': (_) => const DocsPage(),
};

class EsenSeoExampleApp extends StatelessWidget {
  const EsenSeoExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'esen_seo Example',
      // Aus theme.dart — dieselbe Funktion, die der Theme-Guard-Test
      // bewacht. Ein inline definiertes Theme könnte lautlos vom
      // generierten Shell-CSS wegdriften.
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      // Wendet bei jeder Navigation die Meta-Daten der passenden
      // SeoRoute an — kein EsenSeo.setMeta() pro Seite nötig.
      navigatorObservers: [
        SeoRouteObserver(routes: seoRoutes, canonicalBase: siteBase),
      ],
      initialRoute: '/',
      // Statische Hosts liefern Deep-Links gern mit Trailing Slash aus
      // (/docs → /docs/). normalizeSeoPath macht die App tolerant, sonst
      // fiele die Route auf '/' zurück.
      onGenerateRoute: (settings) {
        final name = normalizeSeoPath(settings.name ?? '/');
        final builder = _pages[name] ?? _pages['/']!;
        return MaterialPageRoute(
          builder: builder,
          settings: RouteSettings(name: name, arguments: settings.arguments),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// SEITE 1 — Home ('/')
// ---------------------------------------------------------------------------

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return PageScaffold(
      // .main → <main>: der Hauptinhalt der Seite, einmal pro Seite.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 20,
        children: [
          // .h1 → <h1>: die Hauptüberschrift (Kurzform von
          // .seo(SeoTextTag.h1)).
          Text('Real SEO for Flutter Web', style: textTheme.displaySmall).h1,
          // .p → <p>: ein normaler Absatz.
          Text(
            'No Puppeteer. No tricks. Pure Dart.',
            style: textTheme.titleLarge,
          ).p,

          // .ul + .li → <ul><li>…</li></ul>: eine echte HTML-Liste.
          const Bullets([
            'Semantic HTML — h1 to h6, p, section...',
            'Meta Tags, OpenGraph, Twitter Cards',
            'Schema.org JSON-LD',
            'Bot-aware SSR Server — pure Dart',
            'Static prerendering — no server needed',
            'Smart Defaults — page never breaks',
          ]),

          // Image().seo(...) → <img src="..." alt="..." width="800"
          // height="400" loading="lazy"/>. Explizite Dimensionen helfen
          // Crawlern beim Layout (Core Web Vitals: CLS); ohne alt würde
          // das semanticLabel übernommen.
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              'https://picsum.photos/800/400',
              semanticLabel: 'Demo Image',
              errorBuilder: (context, error, stack) => const SizedBox.shrink(),
            ).seo(
              alt: 'esen_seo demo image',
              width: 800,
              height: 400,
              lazy: true,
            ),
          ),

          // .section → <section>: gruppiert Überschrift + Inhalt.
          const DocSection(
            title: 'About',
            children: [
              Para(
                'esen_seo mirrors your Flutter widget tree as clean '
                'semantic HTML — right in the DOM, without Puppeteer or '
                'headless Chrome.',
              ),
            ],
          ),

          DocSection(
            title: 'How it works',
            children: [
              const Para('Add .seo() to your widgets:'),
              const Bullets([
                'Text widgets become h1, h2, p...',
                'Images become img with alt text',
                'Columns become div, section, article...',
                'GestureDetectors become anchor links',
              ]),
              // Interner Link: für den User Flutter-Navigation, für
              // Bots ein <a href>. Der SeoRouteObserver setzt beim
              // Navigieren automatisch die Meta-Daten der Ziel-Route.
              SeoLink(
                label: 'Read the full documentation →',
                href: '/docs',
                onTap: () => Navigator.pushNamed(context, '/docs'),
              ),
            ],
          ),
        ],
      ).main,
    );
  }
}

// ---------------------------------------------------------------------------
// SEITE 2 — Demo ('/demo')
// ---------------------------------------------------------------------------

class DemoPage extends StatelessWidget {
  const DemoPage({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return PageScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 20,
        children: [
          Text('Live Demo', style: textTheme.displaySmall).h1,
          const Para(
            'Open DevTools → Elements to see the semantic HTML tree '
            'in #esen-seo-content.',
          ),
          const DocSection(
            title: 'Shorthand Tags',
            children: [
              Para('These are all shorthand getters:'),
              Bullets([
                '.h1 through .h6',
                '.p for paragraphs',
                '.li for list items',
                '.section .article .nav',
              ]),
            ],
          ),
          const DocSection(
            title: 'Schema.org JSON-LD',
            children: [
              Para(
                'This page has FAQ and BreadcrumbList schemas — check '
                'the page source.',
              ),
            ],
          ),
          SeoNavMenu(
            items: [for (final item in demoNavItems) _demoNavItem(item)],
            label: 'Demo navigation',
            interactionId: 'demo-nav',
            onTap: (item) => Navigator.pushNamed(context, item.href!),
          ),
          SeoCarousel(
            height: 180,
            interactionId: 'demo-carousel',
            interactionLabel: 'Rendering carousel',
            slides: [
              for (final slide in demoCarouselSlides)
                SeoCarouselSlide(
                  label: slide.label,
                  content: Align(
                    alignment: Alignment.topLeft,
                    child: Text(slide.content),
                  ),
                  nodes: demoCarouselSlideNodes(slide),
                ),
            ],
          ),
          SeoTabs(
            interactionId: 'demo-tabs',
            interactionLabel: 'Rendering targets',
            tabs: [
              for (final tab in demoTabs)
                SeoTab(
                  label: tab.label,
                  content: Text(tab.content),
                  nodes: demoTabPanelNodes(tab),
                ),
            ],
          ),
        ],
      ).main,
    );
  }
}

SeoNavItem _demoNavItem(DemoNavData item) => SeoNavItem(
      item.label,
      url: item.url,
      children: [for (final child in item.children) _demoNavItem(child)],
    );
