# esen_seo

Real semantic HTML for Flutter Web — no Puppeteer, no headless Chrome,
no second copy of your content. Pure Dart.

A Flutter web app is not a document. However it renders — CanvasKit,
WebAssembly or the DOM — what reaches the page is a widget tree, not
headings, paragraphs and links, so a crawler finds no structure to read.
esen_seo mirrors that widget tree as clean semantic HTML right in the
DOM, manages meta tags, OpenGraph and Schema.org JSON-LD, and ships a
shelf-based SSR server that hands bots the HTML straight in the page
source.

```dart
// One change per widget, full SEO:
Text('Welcome').h1                       // → <h1>Welcome</h1>
Text('We build Flutter apps.').p         // → <p>We build Flutter apps.</p>
Image.network(url).seo(alt: 'Our team')  // → <img src="..." alt="Our team"/>
```

This is an add-on for the app you already have, not a framework to
rebuild it in. It works in three steps: most widgets are mirrored
automatically, a `.seo()` call adds the meaning Flutter does not know,
and a handful of library widgets bridge the cases the mirror cannot
see at all — a closed dropdown, a virtualized list, an inactive tab, a
painted chart.

On iOS, Android and desktop nothing changes: every call is a no-op and
your widgets render exactly as before. The library widgets build plain
Flutter widgets there too — nothing is translated into native views.
The HTML only exists on the web.

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
- **Custom translations**: `.seoNodes()` lets any widget declare its own
  HTML, and the SEO widget library translates painted content — a
  `SeoBarChart` mirrors as CSS bars plus a real `<table>` of its data.
- **Meta tags, OpenGraph, Twitter Cards**: one `EsenSeo.setMeta()` call
  per page, with sensible fallbacks (`og:title` ← `title`, …).
- **Schema.org JSON-LD** for rich results: typed builders for `Article`,
  `Product` (incl. `AggregateRating`), `Review`, `Event`,
  `LocalBusiness`, `Organization`, `WebSite`, `BreadcrumbList` and
  `FAQPage`, plus a generic escape hatch for every other type.
- **Bot-aware SSR server**: a shelf middleware detects crawlers by
  User-Agent and serves them a real HTML document — pure Dart, runs
  with `dart run`, no browser involved.
- **URL routing as a single source of truth**: define your routes once
  in a pure-Dart table — the app applies meta tags automatically on
  navigation, the server renders the same pages for bots and generates
  `sitemap.xml` (with `lastmod` and hreflang alternates), `robots.txt`,
  canonical URLs and real HTTP 404s from the same table.
- **Static prerendering**: bake the route table into the web build as
  static HTML files — full SEO on Firebase Hosting, GitHub Pages or any
  CDN, no server needed.
- **Visible shell (optional)**: let the prerendered HTML *be* the first
  frame — styled, readable content before the Flutter engine has
  loaded, with Flutter taking the screen over on its first frame.
- **AI crawlers & instant indexing**: `llms.txt` and `llms-full.txt`
  generated from the route table, and IndexNow pings so search engines
  pick up changes in minutes instead of days.

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

Yes, that mirror is hidden by default — but it is not the old trick of
keeping a second, hand-maintained copy of the page in the markup. It is
generated from the same widget tree the user sees, bots and visitors get
the same content, and with the visible shell below it stops being hidden
at all. One thing it is explicitly *not*: an accessibility feature.
`aria-hidden` keeps screen readers out of it on purpose, because Flutter
publishes its own semantics tree and two of them would be read twice.
Accessibility stays a matter of Flutter's `Semantics` widgets.

## Tags

The semantic HTML elements work — structure, headings, text, lists,
tables and media. The typed constants cover the common ones and
autocomplete in the IDE; the rest go through the constructor:

```dart
Text('Quote').seo(SeoTextTag.blockquote);
Text('12 July').seo(SeoTextTag.time);
Column(children: [...]).seo(SeoContainerTag.article);
Text('Exotic').seo(SeoTextTag('bdo'));          // less common tags
```

Tags are an allow list, so anything that could execute code, swallow the
document or collect input (`script`, `style`, `iframe`, `form`,
`plaintext`, `svg`, head-only tags, custom elements, invalid names) is
refused at render time and falls
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
CLS) and fall back to the widget's own `width`/`height` when set.

An attribute policy keeps the tree safe: event handlers (`onclick`, …)
and invalid names are dropped, while `data-*`, `aria-*`, `id`, `lang`,
`cite`, … pass through. URL attributes are held to an **allow list** —
relative URLs plus `http`, `https`, `mailto`, `tel`, `sms` and `ftp`.
Anything else is refused, so `javascript:` and friends cannot get
through even in a disguise nobody has thought of yet. That matters as
soon as link targets come from your users rather than from you.

## Custom widgets & charts — translate the data, not the pixels

Widgets that paint their content (charts, gauges, `CustomPaint`) are a
black box to the mirror: pixels carry no semantics. What *is*
translatable is the data they paint from. `.seoNodes()` lets any widget
declare its own HTML — the declared nodes replace the widget's subtree
in the mirror, and the usual tag/attribute policy applies:

```dart
MyRatingStars(score: 4.5).seoNodes([
  SeoNode(tag: 'p', text: 'Rated 4.5 out of 5 stars'),
]);
```

The SEO widget library builds on this. Every library widget renders as
normal Flutter widgets on every platform — and on the web its data
appears in the mirror as readable HTML:

```dart
SeoBarChart(
  title: 'Revenue per year',
  data: [
    SeoBarChartEntry('2024', 12),
    SeoBarChartEntry('2025', 31),
    SeoBarChartEntry('2026', 54),
  ],
)
// → <figure><figcaption>Revenue per year</figcaption>
//     …CSS bars…
//     <table><caption>…</caption>
//       <tr><th>2024</th><td>12</td></tr>…</table></figure>
```

- **`SeoBarChart`** — CSS bars plus a `<table>` of the values.
- **`SeoPieChart`** — a pure-CSS pie (`conic-gradient`, no images, no
  JS) plus a `<table>` with labels, values and shares.
- **`SeoRating`** — stars plus the exact score as plain text
  (`★★★★☆ 4.5/5`); pair with `SeoSchema.product`/`SeoSchema.review`
  for rating stars in search results.
- **`SeoDataTable`** — specs, prices, comparisons as a real `<table>`
  with `<caption>`, `<thead>` and `<tbody>`.
- **`SeoFaq`** — an accordion whose answers are in the page source even
  while collapsed (`<details>`/`<summary>`, expandable without any JS).
- **`SeoBreadcrumbs`** — a trail as `<nav><ol><li>` with real links.
- **`SeoFigure`** — image plus caption as `<figure>`/`<figcaption>`,
  with the dimensions that keep the layout from jumping.
- **`SeoTestimonial`** — a customer quote as `<blockquote>` with its
  attribution beside it, the way the HTML spec asks for.

Three of them close a different kind of hole: content Flutter never
builds cannot be mirrored, because the mirror walks the widget tree.

- **`SeoNavMenu`** — a dropdown's entries live in an overlay and do not
  exist while the menu is closed. This one keeps the whole tree as
  data, so every internal link is in the source: `<nav><ul><li><a>`,
  nested as deep as you declare it.
- **`SeoListView`** — the widest silent hole in Flutter Web:
  `ListView.builder` builds only what is on screen, so a 200-entry blog
  index mirrors maybe eight. Flutter still renders lazily here; the
  mirror gets all 200.
- **`SeoTabs`** — a `TabBarView` builds only the selected panel, so on
  a product page two thirds of the content are invisible. All panels
  are mirrored, each behind its own heading.

`SeoFaq` and `SeoBreadcrumbs` also hand you the matching structured
data, so the on-page content and the rich result come from one source:

```dart
SeoMeta(schemas: [
  SeoFaq.schemaFor(entries),
  if (SeoBreadcrumbs.schemaFor(trail, base: siteBase) case final crumbs?)
    crumbs,
])
```

On non-web platforms all of them are no-ops that render the plain
Flutter widget.

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

Anything beyond the built-in fields goes into `extraMeta` — plain
`<meta name="…" content="…">` tags:

```dart
SeoMeta(
  extraMeta: {
    'google-site-verification': 'AbC123…',
    'theme-color': '#0a0f1e',
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
          return SeoPage.fromNodes(
            meta: SeoMeta(title: 'Yahya Esen — Flutter Developer in Munich'),
            body: [SeoNode(tag: 'h1', text: 'Flutter apps that rank on Google')],
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
the Flutter side and the server, so both render identical HTML. Build
pages from `SeoNode`s as above — they pass the tag and attribute policy.
The `SeoPage(bodyHtml: …)` constructor writes its string into the
document verbatim and exists for HTML you wrote yourself; never assemble
it from content you do not control. See
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

Using **go_router**? Same observer, no extra package:

```dart
GoRouter(
  observers: [
    SeoRouteObserver(routes: seoRoutes, canonicalBase: siteBase),
  ],
  routes: [...],
);
```

The observer matches URL-like route names directly and otherwise
follows the **browser URL** — so it works with go_router, beamer,
auto_route or any other Router-based package. (For go_router
`ShellRoute`s, add the observer to the shell's `observers` as well.)

**On the server** — the same table drives the bot responses:

```dart
seoBotMiddleware(routes: seoRoutes, siteBase: siteBase)
```

This automatically gives you:

- server-rendered pages for every route (with path parameters),
- **canonical URLs** derived from `siteBase` + route path,
- **`/sitemap.xml`**, **`/robots.txt`**, **`/llms.txt`** and
  **`/llms-full.txt`** generated from the table,
- **real HTTP 404s** for unknown page paths — no SPA soft-404 problem.

The sitemap carries everything a route declares: set
`SeoRoute(lastModified: …)` and search engines see a `<lastmod>` date;
routes whose `SeoMeta.alternates` list language variants get
`<xhtml:link rel="alternate" hreflang="…">` entries — Google's
recommended way to announce translations at scale.

### Database-backed pages — one read, one page

A `/products/:slug` page usually pulls its title, description, schema
*and* body from a single record. Building the metadata and the body
separately means two reads that can disagree — the page a user sees
drifting from the entry in your sitemap. `SeoRoute.dynamic` resolves
both from one read:

```dart
SeoRoute.dynamic(
  path: '/products/:slug',
  // Lists the concrete URLs for the sitemap, llms.txt and prerender.
  enumeratePaths: () async =>
      (await db.publishedSlugs()).map((s) => '/products/$s').toList(),
  resolve: (request) async {
    final product = await db.product(request.param('slug'));
    if (product == null) return SeoDocument.notFound();       // real 404
    if (product.movedTo != null) {
      return SeoRedirect('/products/${product.movedTo}');     // real 301
    }
    return SeoDocument(
      meta: SeoMeta(title: product.name, description: product.teaser),
      // The head request (sitemap/llms) needs no body — skip it to keep
      // enumeration cheap; never trim the meta.
      body: request.detail == SeoDetail.head
          ? const []
          : product.toSeoNodes(),
      lastModified: product.updatedAt,          // per-record <lastmod>
      includeInSitemap: product.isPublished,    // pull drafts from the index
    );
  },
)
```

`seoBotMiddleware` and `prerenderSite` resolve the table for you — the
classic `SeoRoute(meta:, body:)` form is unchanged and mixes freely with
dynamic routes in the same table. A `SeoRedirect` target is held to
*stricter* rules than a link: only `http`, `https` or a relative path,
only real redirect statuses (301, 302, 303, 307, 308), and never an
empty or fragment-only target. `mailto:` and `tel:` are fine in a link
and nonsense in a `Location`; an empty or `#fragment` target just
redirects to itself. Anything refused becomes a 404 rather than an
unsafe header.

A resolver redirect is served to **human visitors as well as bots** —
sending Googlebot to the new URL while a user stays on the old one is
cloaking. Error statuses are the deliberate exception: a 404 or 410
answers crawlers, while a human keeps the Flutter app and its own
router decides what to show. Both are configurable:

```dart
seoBotMiddleware(
  routes: seoRoutes,
  siteBase: siteBase,
  applyResolverRedirects: SeoRedirectScope.all,   // default; .botsOnly, .off
  infrastructureCacheTtl: Duration(minutes: 15),  // default for dynamic tables
  onResolveError: (path, error, stack) => log.warning('$path: $error'),
)
```

`sitemap.xml`, `llms.txt` and `llms-full.txt` are cached — forever for a
static table, 15 minutes for a dynamic one — and concurrent requests
share a single pass instead of each starting their own. **Set
`onResolveError` when you use dynamic routes:** a failing page is
dropped from the sitemap rather than taking the whole file down with it,
and without the callback that happens silently.

A resolver may also return response headers via `SeoDocument.headers`.
The names are an **allow list** — `cache-control`, `expires`, `etag`,
`last-modified`, `age`, `x-robots-tag`, `link` and `content-language`,
plus `vary`, which is merged with `User-Agent` rather than replacing
it. Everything else is dropped, as is any name that is not a valid
HTTP token and any value outside printable ASCII. That is deliberately narrow: a page's content should not be
able to set a cookie, claim a content encoding, or decide your CORS and
CSP posture. For headers beyond that list, put your own shelf
middleware in the pipeline.

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

## Audit — prove the site is correct before you ship it

Most SEO mistakes are not broken code. They are a page marked `noindex`
that is still in the sitemap, a link to a route somebody renamed, a
translation cluster that points one way. The renderer cannot refuse any
of those — each one is a perfectly legal use of the API — so there is a
separate check for them:

```dart
// test/seo_audit_test.dart — runs in the CI you already have
test('the site has no SEO errors', () async {
  final report = await auditSeoRoutes(routes: seoRoutes, siteBase: siteBase);
  expect(report.passes(), isTrue, reason: '\n${report.describe()}');
});
```

It reads the **route table**, not built HTML: the package already knows
every URL, title and node, so a broken internal link is simply an
`href` that `matchSeoRoute` cannot match. No crawler, no HTML parser,
and it runs before `flutter build web` has done any work.

```
esen_seo audit: 6 pages, 3 error(s), 2 warning(s), 1 info.

/blog/archive:
  x route.shadowed  unreachable: an earlier pattern already matches it,
                    so this route never runs (shadowed by /blog/:slug)
/geheim:
  x robots.noindex-in-sitemap  marked noindex but still listed in
                    sitemap.xml — two contradictory signals
/kontakt:
  x link.broken     links to a path that no route serves (/agb)
```

Among the things it catches, each verified against the real code: a
`canonicalUrl` the URL policy refuses — which leaves the page with *no*
canonical **and** suppresses the automatic one, so it ends up worse off
than if you had set nothing; a schema value JSON cannot encode, which
otherwise throws when the page renders rather than when you write it;
and hreflang clusters that are not reciprocal, which Google discards
without telling anyone.

Severity is the contract: `error` is something measurably wrong,
`warning` is very likely wrong but a real site can look like that
(paginated pages share titles), and `info` never fails a build. A
resolver that throws becomes a finding rather than aborting the run —
but the report is then marked `partial` and the cross-page checks are
**skipped**, because "this title is unique" cannot be proven with a
page missing.

```dart
auditSeoRoutes(
  routes: seoRoutes,
  siteBase: siteBase,
  policy: const SeoAuditPolicy(ignore: {SeoCheck.titleLength}),
);
```

Prefer running it from a script instead of a test? Same shape as the
prerenderer — a few lines in `bin/seo_audit.dart` that import your own
route table, then `exit(report.passes() ? 0 : 1)`.

### Parity — do bots and visitors see the same page?

Everything above reads the route table, so on its own it can only
confirm that the table agrees with itself. The check that matters most
compares it against the widget tree a visitor actually sees:

```dart
import 'package:esen_seo/testing.dart';

testWidgets('bots and users see the same pages', (tester) async {
  final report = await auditSeoParity(
    routes: seoRoutes,
    siteBase: siteBase,
    paths: const ['/', '/docs'],
    pump: (path) async {
      await tester.pumpWidget(MyApp(initialRoute: path));
      await tester.pumpAndSettle();
    },
  );
  expect(report.passes(), isTrue, reason: '\n${report.describe()}');
});
```

The failure it exists for is mundane: somebody renames a headline in
the widget and forgets the route body. From then on crawlers and
visitors read different pages — and nothing else in the package can
notice, because the two trees come from different code.

Text that reaches crawlers but never appears in the app is an
**error**; that is cloaking, whatever the intent. A differing `<h1>` is
an error too. A heading only the app shows is a warning, since an app
legitimately shows more than a crawler needs. Links are off by default:
navigation usually lives in the Flutter shell, so the route body will
never carry it. And pages your sample did not cover are named in the
report, so a sample that quietly shrank to one route cannot pass for
coverage.

`testing.dart` is a separate import on purpose — it is test-time
scaffolding and has no business in a release build.

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
exist; `sitemap.xml`, `robots.txt`, `llms.txt`, `llms-full.txt` and a
`404.html` (served with a real 404 status by Firebase Hosting, GitHub
Pages & Co. — no SPA soft-404) are written too. For `:param` routes,
pass the concrete paths via `additionalPaths`.

## Visible shell — the prerendered page as the first frame

By default the semantic HTML is an invisible mirror next to the Flutter
canvas: crawlers read it, users never see it. With
`SeoRenderMode.visibleShell` the same HTML becomes the **first frame**
instead — a real, styled page the user can read while the Flutter engine
is still downloading:

```dart
await prerenderSite(
  routes: seoRoutes,
  siteBase: siteBase,
  renderMode: SeoRenderMode.visibleShell,
  stylesheet: seoDefaultStylesheet,   // oder dein eigenes CSS
);
```

The prerendered container marks itself, so the two sides cannot drift
apart — but **your app must call `EsenSeo.init()`**, which is what
schedules the first mirror refresh and with it the handoff. Miss that
one call and the shell stays on top of your running app forever. There
is deliberately no timeout behind it: a shell that stays put is the
right answer when the engine never arrives, and from the outside the
package cannot tell that case from a forgotten `init()`.

Once it runs, the moment Flutter has rendered its first frame the shell
fades out over 150 ms and drops back to being the invisible mirror.
While it is up the shell covers the viewport, so the Flutter engine's
empty surface stays hidden during boot — the user sees content, then
the finished app, and never the loading in between. If the engine never
loads (slow network, JS error), the user simply keeps a readable page.

Styling is yours to control. `class` and `style` pass through `.seo()`
like any other attribute, so the shell can carry your own CSS:

```dart
Text('Willkommen').seo(SeoTextTag.h1, {'class': 'hero-title'});
Column(children: [...]).seo(SeoContainerTag.section, {'class': 'card'});
```

The CSS is inlined into the `<head>` of every prerendered file — an
external stylesheet would cost a round trip and give away exactly the
head start the shell is for. `seoDefaultStylesheet` is a ~1 KB
classless baseline scoped to the container; pass your own CSS to match
your app's look. Give it an opaque `background` — otherwise Flutter's
still-empty surface shows through while it boots.

**Honest limits:** this is a handoff, not React-style hydration —
Flutter renders to canvas, so it can never adopt the DOM. The shell
will resemble your app, not match it pixel for pixel (we know the
semantic tree, not the widget geometry). Before the engine is up, real
`<a href>` links work but buttons and forms do not. And the mode only
applies to prerendered pages — `flutter run` has no prerendered HTML to
show, and `EsenSeo.init()` must run in the app so the handoff happens.

## AI crawlers & instant indexing

[llms.txt](https://llmstxt.org) is a markdown manifest of your site for
AI assistants. Be clear-eyed about it: it is a young proposal, adoption
is uneven, and Google has said it does not use it for Search — treat it
as a bet, not a traffic channel. What makes it worth having anyway is
that it costs you nothing: esen_seo generates it from the route table
you already maintain (served by the middleware, written by
`prerenderSite`, or standalone):

```dart
seoLlmsTxt(routes: seoRoutes, siteBase: siteBase)
// # Esen Software
// > Flutter apps with real SEO.
//
// ## Pages
//
// - [Home](https://esen.software/): Flutter apps with real SEO.
// - [Docs](https://esen.software/docs): How esen_seo works.
```

`llms-full.txt` goes one step further: the complete page content —
your routes' server-side bodies converted to markdown — in one file,
so an AI assistant reads the whole site in a single request
(`seoLlmsFullTxt(...)`, served and written automatically as well).

And instead of waiting for the next crawl, push changed pages actively
via [IndexNow](https://www.indexnow.org) (Bing, Seznam, Naver, Yandex —
Google still crawls via sitemap):

```dart
// after a deploy or content update:
await submitIndexNow(
  siteBase: siteBase,
  key: 'a1b2c3d4e5f6a7b8',            // self-chosen, 8–128 hex chars
  paths: ['/', '/blog/neuer-post'],
);
```

The protocol requires the key to be readable at
`https://your-site/<key>.txt` — `seoBotMiddleware(indexNowKey: …)`
serves it and `prerenderSite(indexNowKey: …)` writes it, so there is no
extra hosting setup.

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

Young package under active development, covered by 471 unit and widget
tests — the pipeline (extensions, smart defaults, meta/OpenGraph,
JSON-LD, routing, bot middleware, prerendering), the widget library, and
a set of tests that feed hostile input through every path to HTML.

### What the renderer guarantees, and what it does not

Everything the package emits passes a tag and attribute policy in the
renderer itself, so a page assembled from untrusted content (a CMS, say)
cannot turn into executable markup on any of the three paths — the
Flutter mirror, the SSR middleware or the prerenderer. No `<script>`, no
event handler, no `javascript:` URL, no positioning or stacking that
would lift an element out of the mirror. That holds no matter where the
`SeoNode` came from.

It does **not** mean untrusted content is visually harmless. In
`SeoRenderMode.visibleShell` the prerendered HTML is the page the user
sees while Flutter boots, and content shown to a user can mislead them.
A property allow list cannot prevent that, and a longer one would not
help: an empty `<a>` sized `width:100vw;height:100vh` paints nothing and
still takes the click, using two properties every document needs. A
later sibling with `margin-top:-100vh` lies over an earlier one, so the
real headline stays visible while its clicks go somewhere else. Plain
visible text linking somewhere unexpected works just as well and needs
no CSS at all.

Read the first paragraph precisely, then: the policy keeps content
*inside* the mirror's container. It does not police what that content
does to itself once it is there.

Note also what the property list governs: **inline styles only.** A
`class` value names a rule in *your* stylesheet, so if that stylesheet
has a rule with `position: fixed`, untrusted content can reach it by
name and the inline allow list never sees it. `seoDefaultStylesheet` is
classless and offers nothing to target, but your own CSS may.

So the boundary is: **the package makes content non-executable; it does
not make it honest.** In the default `seoOnly` mode this is moot — the
mirror is clipped to zero size, `pointer-events:none` and `inert`, so
nothing inside it can be seen or clicked either way. If you enable the
visible shell *and* your route bodies come from a source you do not
control, review that content the way you would review any user-generated
content before displaying it. That is an application decision; the
renderer cannot make it for you.

Issues and feedback are welcome on
[GitHub](https://github.com/esenpi/esen_seo).

## License & contributing

esen_seo is licensed under the **[Apache License 2.0](LICENSE)** —
free for any use, commercial or not, with an explicit patent grant.
The software is provided **"AS IS", without warranties or conditions
of any kind and without liability** (sections 7 and 8 of the license).

Contributions are welcome — please read
[CONTRIBUTING.md](CONTRIBUTING.md) first; pull requests are accepted
under our [CLA](CLA.md).
