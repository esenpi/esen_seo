# esen_seo

Real semantic HTML for Flutter Web — no Puppeteer, no headless Chrome,
no hidden-HTML tricks. Pure Dart.

Flutter Web paints everything onto a canvas, so crawlers see an empty
page. esen_seo mirrors your widget tree as clean semantic HTML right in
the DOM, manages meta tags, OpenGraph and Schema.org JSON-LD, and ships
a shelf-based SSR server that hands bots the HTML straight in the page
source.

```dart
// One change per widget, full SEO:
Text('Welcome').h1                       // → <h1>Welcome</h1>
Text('We build Flutter apps.').p         // → <p>We build Flutter apps.</p>
Image.network(url).seo(alt: 'Our team')  // → <img src="..." alt="Our team"/>
```

## Features

- **`.seo()` extensions** for `Text`, `Image`, `Column`, `Row` and
  `GestureDetector` — your widgets stay untouched, on every platform.
- **Typed tags with IDE autocomplete**: `SeoTextTag.h1`,
  `SeoContainerTag.section`, … — typos become compile errors. The most
  common tags have shorthands: `.h1`–`.h6`, `.p`, `.li`, `.ul`,
  `.section`, `.article`, `.nav`, `.tr`, …
- **Smart defaults**: pages without any `.seo()` calls still render —
  the first text becomes `<h1>`, following texts `<p>`, images `<img>`
  with their `semanticLabel` as alt text. The page never breaks: blocked
  or invalid tags (`script`, `style`, …) fall back to safe elements.
- **Meta tags, OpenGraph, Twitter Cards**: one `EsenSeo.setMeta()` call
  per page, with sensible fallbacks (`og:title` ← `title`, …).
- **Schema.org JSON-LD** for rich results: typed builders for `Article`,
  `Product`, `Organization`, `WebSite`, `BreadcrumbList` and `FAQPage`,
  plus a generic escape hatch for every other type.
- **Bot-aware SSR server**: a shelf middleware detects crawlers by
  User-Agent and serves them a real HTML document — pure Dart, runs
  with `dart run`, no browser involved.
- **URL routing as a single source of truth**: define your routes once
  in a pure-Dart table — the app applies meta tags automatically on
  navigation, the server renders the same pages for bots and generates
  `sitemap.xml`, `robots.txt`, canonical URLs and real HTTP 404s from
  the same table.
- **Static prerendering**: bake the route table into the web build as
  static HTML files — full SEO on Firebase Hosting, GitHub Pages or any
  CDN, no server needed.

## Quick start

```dart
import 'package:esen_seo/esen_seo.dart';

void main() {
  EsenSeo.init();
  EsenSeo.setMeta(SeoMeta(
    title: 'Yahya Esen — Flutter Developer in Munich',
    description: 'Flutter apps for iOS, Android and the web — with real SEO.',
    canonicalUrl: 'https://esen.software/',
    openGraph: const OpenGraphMeta(image: 'https://esen.software/og.png'),
    schemas: [
      SeoSchema.organization(name: 'Esen Software', url: 'https://esen.software'),
    ],
  ));
  runApp(const MyApp());
}
```

```dart
Column(
  children: [
    Text('Flutter apps that rank on Google').h1,
    Text('Yahya Esen — freelance Flutter developer from Munich.').p,
    Column(
      children: [
        Text('Web apps with real SEO').li,
        Text('Mobile apps from the same codebase').li,
      ],
    ).ul,
    GestureDetector(
      onTap: () => context.go('/contact'),
      child: Text('Contact us'),
    ).seo(href: '/contact'),
  ],
).section
```

On web, the semantic mirror is injected as `#esen-seo-content` next to
the Flutter canvas (invisible, `aria-hidden`, zero size); on mobile and
desktop every `.seo()` call is a no-op that returns the original widget.

## Tags

Any standard HTML tag works. The typed constants cover the common ones
and autocomplete in the IDE; everything else goes through the constructor:

```dart
Text('Quote').seo(SeoTextTag.blockquote);
Text('12 July').seo(SeoTextTag.time);
Column(children: [...]).seo(SeoContainerTag.article);
Text('Exotic').seo(SeoTextTag('bdo'));          // custom / exotic tags
```

Tags that could execute code or break the document (`script`, `style`,
`iframe`, head-only tags, invalid names) are blocked at runtime and fall
back to `span`/`div` — in `SeoMode.strict` you get a debug warning.

## Attributes

Every `.seo()` call accepts HTML attributes; images and links get the
important ones as typed parameters:

```dart
Text('12 July').seo(SeoTextTag.time, {'datetime': '2026-07-12'});
Column(children: [...]).seo(SeoContainerTag.section, {'id': 'pricing'});
Image.network(url).seo(alt: 'Team', width: 800, height: 400, lazy: true);
GestureDetector(...).seo(href: '/legal', rel: 'nofollow', hreflang: 'de');
```

Image dimensions let crawlers reserve layout space (Core Web Vitals:
CLS) and fall back to the widget's own `width`/`height` when set. An
attribute policy keeps the tree safe: event handlers (`onclick`, …),
`javascript:` URLs and invalid names are dropped — `data-*`, `aria-*`,
`id`, `lang`, `cite`, … pass through.

## Meta tags & JSON-LD per page

Call `setMeta` again on navigation; previously injected tags are
replaced:

```dart
EsenSeo.setMeta(SeoMeta(
  title: 'Real SEO for Flutter Web — Blog',
  description: 'How esen_seo mirrors your widget tree as semantic HTML.',
  canonicalUrl: 'https://esen.software/blog/flutter-seo',
  schemas: [
    SeoSchema.article(
      headline: 'Real SEO for Flutter Web',
      author: 'Yahya Esen',
      datePublished: DateTime.utc(2026, 7, 22),
    ),
    SeoSchema.breadcrumbs([
      (name: 'Home', url: 'https://esen.software/'),
      (name: 'Blog', url: 'https://esen.software/blog'),
    ]),
  ],
));
```

For international pages, declare the language variants — rendered as
`<link rel="alternate" hreflang="…">` tags:

```dart
SeoMeta(
  title: 'Flutter Developer München',
  canonicalUrl: 'https://esen.software/',
  alternates: {
    'de': 'https://esen.software/',
    'en': 'https://esen.software/en/',
    'x-default': 'https://esen.software/',
  },
)
```

## SSR server for bots

Crawlers that do not execute JavaScript (social link previews, many
search and AI bots) never see client-injected HTML. The server half of
esen_seo fixes that — bots get a complete HTML document in the page
source, real users get your Flutter app:

```dart
import 'package:esen_seo/server.dart';   // pure Dart, no Flutter
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_static/shelf_static.dart';

Future<void> main() async {
  final handler = const Pipeline()
      .addMiddleware(seoBotMiddleware(resolve: (request) {
        if (request.url.path == '') {
          return SeoPage(
            meta: SeoMeta(title: 'Yahya Esen — Flutter Developer in Munich'),
            bodyHtml: '<h1>Flutter apps that rank on Google</h1>',
          );
        }
        return null; // unknown route → serve the Flutter app
      }))
      .addHandler(
        createStaticHandler('build/web', defaultDocument: 'index.html'),
      );
  await io.serve(handler, 'localhost', 8080);
}
```

`SeoMeta`, `SeoSchema`, `SeoNode` and `HtmlRenderer` are shared between
the Flutter side and the server, so both render identical HTML. See
[example/bin/server.dart](example/bin/server.dart) for a runnable setup.

## URL routing — one table for app and server

Define your routes once, in a pure-Dart file without Flutter imports:

```dart
// lib/seo_routes.dart — imported by main.dart AND bin/server.dart
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
];
```

**In the app** — meta tags update automatically on every navigation,
no `setMeta` boilerplate per page:

```dart
EsenSeo.init(cleanUrls: true);  // path URLs (/demo) instead of /#/demo

MaterialApp(
  navigatorObservers: [
    SeoRouteObserver(routes: seoRoutes, canonicalBase: siteBase),
  ],
  routes: {...},
);
```

**On the server** — the same table drives the bot responses:

```dart
seoBotMiddleware(routes: seoRoutes, siteBase: siteBase)
```

This automatically gives you:

- server-rendered pages for every route (with path parameters),
- **canonical URLs** derived from `siteBase` + route path,
- **`/sitemap.xml`** and **`/robots.txt`** generated from the table,
- **real HTTP 404s** for unknown page paths — no SPA soft-404 problem.

For URL hygiene, add the redirect middleware in front — duplicate
content under several URLs splits ranking signals:

```dart
seoRedirectMiddleware(
  canonicalHost: 'esen.software',       // www.… → esen.software (301)
  forceHttps: true,                     // honors x-forwarded-proto
  stripTrailingSlashes: true,           // /demo/ → /demo
  redirects: {'/old-page': '/new-page'} // relaunch mappings
)
```

## Static prerendering — SEO without any server

No Dart server on your host? Bake the same route table directly into
the web build:

```dart
// bin/prerender.dart
import 'package:esen_seo/server.dart';
import 'seo_routes.dart';

Future<void> main() async {
  await prerenderSite(routes: seoRoutes, siteBase: siteBase);
}
```

```sh
flutter build web
dart run bin/prerender.dart
# → deploy build/web to Firebase Hosting, GitHub Pages, any CDN
```

Every route becomes a real `<path>/index.html` containing its title,
meta tags, JSON-LD and the semantic HTML body — visible in the page
source for everyone, no bot detection needed. The running app finds the
prerendered container by id and simply takes it over (hydration, no
duplicates). Deep links work on static hosts because the files actually
exist; `sitemap.xml` and `robots.txt` are written too. For `:param`
routes, pass the concrete paths via `additionalPaths`.

Trade-off: prerendered pages are a build-time snapshot — for
frequently changing content use the SSR server above instead.

## Modes

| Mode                | Behaviour                                            |
|---------------------|------------------------------------------------------|
| `SeoMode.safe`      | Default. Renders everything, smart defaults fill gaps. |
| `SeoMode.strict`    | Like safe, plus debug warnings for widgets without `.seo()` and for blocked tags. |

```dart
EsenSeo.init(mode: SeoMode.strict);
```

## How it compares

| Package | Approach | Add-on for your existing app | HTML in page source | No headless Chrome | Runtime SSR for dynamic content |
|---|---|---|---|---|---|
| esen_seo | Widget mirror + pure-Dart SSR **and** prerendering | ✅ | ✅ | ✅ | ✅ |
| sfwf | SSR/prerendering via Puppeteer | ✅ | ✅ | ❌ | ✅ |
| hydraline_flutter | Semantic widgets + build-time SSG | ✅ | ✅ | ✅ | ❌ (build-time only) |
| flenx / Jaspr | Dart web framework — you build the site in its components | ❌ (separate site) | ✅ | ✅ | ✅ |
| seo, flutter_seo, seo_renderer | Client-side HTML mirror, no server part | ✅ | ❌ (JS required) | ✅ | ❌ |
| meta_seo | Head meta tags only, no body HTML | ✅ | ❌ (head only) | ✅ | ❌ |

In short: esen_seo is — to our knowledge — the only add-on for your
**existing Flutter app** that covers **both** paths without a browser
on the server: baked static HTML for CDN hosting *and* a runtime
pure-Dart SSR server for dynamic, database-driven pages — plus typed
JSON-LD builders, hreflang and 301-redirect middleware.

## Performance

The hot paths are allocation-conscious and continuously benchmarked.
Ballpark numbers from an Apple-silicon laptop (Dart VM):

| Hot path | Cost |
|---|---|
| Rendering a ~2,800-node widget mirror to HTML | ~1 ms |
| `BotDetector.isBot` per request (precompiled matcher) | ~0.3 µs |
| Route-table lookup across 21 routes | ~1.5 µs |

Reproduce them yourself: `dart run benchmark/hot_paths.dart`.

## An honest word on Core Web Vitals

esen_seo solves Flutter Web's **crawling and indexing** problem:
crawlers get real semantic HTML, meta tags, structured data and clean
URLs. What it cannot do is make the Flutter engine smaller — Google
also measures **real-user loading performance** (Core Web Vitals via
CrUX), and a Flutter web app ships a multi-megabyte engine. To get the
most out of it: build with `--wasm`, use deferred loading for big
routes, mark below-the-fold images with `lazy: true`, and use the
prerenderer or SSR server so the first response already carries
content. SEO ranking is content × technique × performance — esen_seo
covers the first two and helps with the third.

## Status

Young package under active development. The core pipeline (extensions,
smart defaults, meta/OpenGraph, JSON-LD, bot middleware) is covered by
70+ unit tests. Issues and feedback are welcome on
[GitHub](https://github.com/esenpi/esen_seo).

## License & contributing

esen_seo is licensed under the **[Apache License 2.0](LICENSE)** —
free for any use, commercial or not, with an explicit patent grant.
The software is provided **"AS IS", without warranties or conditions
of any kind and without liability** (sections 7 and 8 of the license).

Contributions are welcome — please read
[CONTRIBUTING.md](CONTRIBUTING.md) first; pull requests are accepted
under our [CLA](CLA.md).
