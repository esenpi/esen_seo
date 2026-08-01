## 0.5.0

Security hardening, eleven library widgets, and one contract behind them.

### Security — please update

Three audit rounds under a "the content comes from a CMS" threat model
found that the tag and attribute policy ran **only on the Flutter path**.
`SeoPage`, `seoBotMiddleware` and `prerenderSite` reached HTML without
it, so a `SeoNode` assembled from untrusted data could put a live
`<script>` or an `onerror=` handler into prerendered pages served to
every visitor. The same node was harmless inside the app — safety
depended on which path the data took.

* The policy now lives in `HtmlRenderer`, which **every** path ends in.
  Tag names and attribute names are validated (both were written
  verbatim before, so a quote in an attribute name broke out of the
  attribute list), a refused element loses its attributes along with its
  identity, and `SeoMeta` renders through an explicit head mode.
* Tags are an **allow list** of content elements. A block list kept
  losing: `<plaintext>`, `<xmp>` and `<noembed>` swallow the rest of the
  document, `<form>` invites credential harvesting, SVG's `<animate>`
  rewrites a link into a script URL. **Breaking:** custom elements and
  tags outside the list now fall back to `span`/`div`.
* URL attributes are an allow list of schemes (`http`, `https`,
  `mailto`, `tel`, `sms`, `ftp`, plus relative URLs) and refuse control
  characters — a tab inside `java<TAB>script:` passed the old prefix
  check and browsers reassembled it. `srcset` and `ping` are checked
  candidate by candidate; `ping`, `background`, `longdesc` and friends
  count as URLs now.
* `SeoNode.rawText` is escaped as content everywhere except a JSON-LD
  payload, where every `<` becomes its JSON escape.
* `style` values may only use `static`, `relative` and the CSS-wide
  keywords for `position`. `absolute` is refused too: in the invisible
  mirror it really is clipped to nothing, but in `visibleShell` the same
  container is a full-viewport clickable overlay, so one positioned link
  would cover the page before Flutter boots. CSS comments, escapes,
  `-webkit-sticky` and `var()` indirection no longer hide a value.
* Media may not `autoplay`, and `referrerpolicy` may not be set to a
  value that hands the full URL to a third-party host.
* The mirror stays a well-formed tree: a nested `<a>` becomes a `span`
  (the parser would otherwise empty the surrounding link), and void
  elements or empty tags carrying content keep it instead of dropping
  it silently.
* One XML-forbidden character in a route path no longer makes the whole
  `sitemap.xml` unparseable, and slugs containing `?` or `#` are
  refused rather than written to a file no URL can reach.
* Prerendering refuses route paths that would escape the build
  directory or overwrite `robots.txt`, `sitemap.xml` and the other
  generated files; the IndexNow key must be a plain file name.
* A forged `x-forwarded-proto` no longer decides the redirect scheme or
  crashes the request; the invisible mirror is `inert`, so its links are
  out of the keyboard tab order; `/llms-full.txt` caches its future, so
  parallel first requests render the site once.

### Widget library

Widgets for content the mirror cannot see, because Flutter never builds
it or paints it instead:

* `SeoNavMenu` — the whole menu tree, including closed submenus.
* `SeoListView` — every entry of a lazily built list, not the visible
  handful.
* `SeoTabs` — all panels, each behind its own heading.
* `SeoFaq` — answers in the source while collapsed, plus
  `SeoFaq.schemaFor` for the FAQ rich result.
* `SeoBarChart`, `SeoPieChart` — painted charts as CSS plus a data
  table.
* `SeoBreadcrumbs` (with `schemaFor`), `SeoDataTable`, `SeoRating`,
  `SeoFigure`, `SeoTestimonial`.
* `.seoNodes()` lets any widget declare its own HTML translation, and
  `SeoBlock`/`SeoBlockState` is the contract the library follows: one
  data model, a Flutter presentation and an HTML one.
* `SeoSchema.breadcrumbs` accepts a URL-less final entry, which is what
  search engines expect for the current page.

## 0.4.0

The prerendered page becomes the first frame.

* New `SeoRenderMode.visibleShell` for
  `prerenderSite(renderMode: …)`: the prerendered semantic HTML is no
  longer only an invisible mirror but a visible, styled page — readable
  before the Flutter engine has even started loading. The shell covers
  the engine's boot phase, fades out (150 ms) once the first frame is
  rendered, and then falls back to being the invisible crawler mirror.
  If the engine never loads, users simply keep a readable page. The
  default mode is unchanged.
* CSS delivery for the shell: `prerenderSite(stylesheet: …)` inlines
  critical CSS into the `<head>` of every prerendered file (with safe
  `</style>` escaping), and `seoDefaultStylesheet` ships a ~1 KB
  classless baseline with dark-mode support. `class` and `style` pass
  through `.seo()` attributes as styling hooks.
* `prerenderSite` now refuses to run on an already prerendered
  `index.html` instead of silently duplicating the canonical link,
  JSON-LD blocks and content container on a second run.
* Fixes: duplicate sitemap.xml/llms.txt entries when `additionalPaths`
  overlap routes; `submitIndexNow` gained a `timeout` (default 10 s)
  and rejects a `siteBase` without scheme instead of submitting an
  empty host; markdown special characters in titles, link labels and
  image alt texts no longer break llms.txt links; the first DOM
  injection also runs for apps that mirror no widgets (required for
  the shell handoff).

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
