## 0.3.0

Richer structured data, a smarter sitemap, and first-class support for
AI crawlers and instant indexing.

* New Schema.org builders: `SeoSchema.review`, `SeoSchema.event`,
  `SeoSchema.localBusiness` — and `SeoSchema.product` now takes
  `ratingValue`/`ratingCount`/`reviewCount` for `AggregateRating` stars.
* `SeoMeta.extraMeta`: arbitrary `<meta name="…" content="…">` tags
  (site verification, theme-color, …) without leaving the typed API.
* Sitemap upgrades: `SeoRoute(lastModified: …)` renders a `<lastmod>`
  date, and routes with `SeoMeta.alternates` get
  `<xhtml:link rel="alternate" hreflang="…">` entries per URL —
  `additionalPaths` inherit both from their matching `:param` route.
* `llms.txt` and `llms-full.txt` (https://llmstxt.org) generated from
  the route table via `seoLlmsTxt(...)` / `seoLlmsFullTxt(...)` —
  served automatically by `seoBotMiddleware` and written by
  `prerenderSite`. The full variant inlines each route's server-side
  body as markdown, so AI assistants read the whole site in one
  request.
* `prerenderSite` writes a `404.html` — Firebase Hosting, GitHub Pages
  & Co. serve it with a real 404 status for unknown paths, closing the
  SPA soft-404 gap on static hosting too.
* IndexNow support: `submitIndexNow(...)` pings search engines about
  changed URLs; the required key file `/<key>.txt` is served by
  `seoBotMiddleware(indexNowKey: …)` and written by
  `prerenderSite(indexNowKey: …)`.

## 0.2.0

Router-package support.

* `SeoRouteObserver` now works with go_router, beamer, auto_route and
  any other Router-based package — no extra dependency: routes with
  URL-like names are matched directly, everything else falls back to
  the browser URL (path or hash strategy) after the frame.
* New `locationProvider` parameter on `SeoRouteObserver` to override
  where the current location is read from (tests, custom routers).
* Integration-tested against go_router.

## 0.1.0

Meta tags, JSON-LD, typed tags and the SSR server.

* `EsenSeo.setMeta(SeoMeta(...))`: title, description, keywords, robots,
  canonical URL, OpenGraph and Twitter Cards with smart fallbacks
  (`og:title` ← `title`, …). Injected head tags replace static
  index.html duplicates and survive `MaterialApp`'s title handling.
* Schema.org JSON-LD via `SeoMeta.schemas`: typed builders
  (`SeoSchema.article/organization/website/product/breadcrumbs/faq`)
  plus a generic constructor for any type; XSS-safe `<` escaping.
* Typed tags: `SeoTextTag` / `SeoContainerTag` (extension types over
  `String`) with IDE autocomplete — the tag is now a positional
  parameter: `.seo(SeoTextTag.h1)`. Shorthand getters for the most
  common tags: `.h1`–`.h6`, `.p`, `.li`, `.ul`, `.section`, `.tr`, ….
* Tag policy: every standard HTML tag is allowed; tags that execute code
  or break the document (`script`, `style`, `iframe`, head-only tags,
  invalid names) safely fall back to `span`/`div`.
* URL routing: `SeoRoute` table as single source of truth
  (`package:esen_seo/core.dart`, pure Dart, shared between app and
  server) with `:param` path matching. `SeoRouteObserver` applies meta
  tags automatically on navigation; `seoBotMiddleware(routes: ...)`
  renders the same pages for bots and serves generated `sitemap.xml`,
  `robots.txt`, derived canonical URLs and real HTTP 404s for unknown
  paths. `EsenSeo.init(cleanUrls: true)` enables path URLs.
* hreflang / i18n: `SeoMeta.alternates` renders
  `<link rel="alternate" hreflang="…">` tags for language variants.
* Redirects: `seoRedirectMiddleware` — canonical host (www → apex),
  https enforcement (proxy-aware), trailing-slash normalization and
  exact 301 mappings for relaunches.
* HTML attributes: every `.seo()` accepts an attribute map
  (`Text(...).seo(SeoTextTag.time, {'datetime': ...})`), images get
  `width`/`height`/`lazy` (falling back to the widget's dimensions),
  links get `rel`/`hreflang`. An attribute policy drops event handlers,
  `javascript:` URLs and invalid names.
* Static prerendering: `prerenderSite()` bakes the route table into the
  web build as per-route `index.html` files (meta + JSON-LD in the
  head, semantic body in the hidden container, hydration-safe) plus
  `sitemap.xml`/`robots.txt` — full SEO on static hosting without a
  Dart server.
* SSR server (`package:esen_seo/server.dart`, pure Dart): `BotDetector`
  (search engines, social previews, AI crawlers), `SeoPage` document
  rendering and `seoBotMiddleware` for shelf — bots get semantic HTML in
  the page source, users get the Flutter app.
* Complete HTML5 void-element list; web build fix for
  `package:web` interop tear-offs.
* Minimum SDK raised to Dart 3.4 / Flutter 3.22 (extension types).
* License: Apache-2.0.

## 0.0.1

Initial release — core SEO pipeline.

* `.seo()` extensions for `Text`, `Image`, `Column`, `Row` and
  `GestureDetector` (rendered as `<h1>`/`<p>`, `<img>`, `<div>`,
  flex `<div>` and `<a href>`).
* Semantic HTML is mirrored into the DOM via `package:web` — no Puppeteer,
  no headless Chrome, pure Dart.
* Smart defaults: pages without `.seo()` tags still render — the first text
  becomes `<h1>`, following texts `<p>`, images `<img>`.
* `SeoMode.safe` (default) and `SeoMode.strict` (warnings for widgets
  without `.seo()`).
* Widgets stay untouched on non-web platforms.
