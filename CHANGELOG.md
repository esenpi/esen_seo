## Unreleased

* Added `SeoThemeToggle`, a controlled Flutter light/dark control with a
  separately selected `SeoDomFirstFeature.themeToggle` presentation. The
  generated web adapter restores a closed `light`/`dark` preference before
  first paint,
  follows the system when no preference exists, persists changes best-effort
  and keeps malformed markers inert. Theme CSS opts into explicit palette
  selectors with `enableManualTheme: true`; existing stylesheet and document
  bytes remain unchanged by default. `compactOnSmallScreens` switches both
  Flutter and DOM-first controls to an accessible icon-only presentation at
  widths up to 600 pixels.
* Added `SeoCollection`, a complete searchable, single-category-filterable,
  sortable and paginated content collection. Flutter and the separately
  opt-in `SeoDomFirstFeature.collection` runtime share one prepared pure Dart
  transition; the DOM-first adapter validates the complete bounded structure
  before creating controls or changing visibility. Every item and native link
  remains in the source without JavaScript. Invalid, ambiguous, oversized or
  single-item collections stay complete static HTML, and sort keys are limited
  to integers represented exactly on both the Dart VM and JavaScript.
* `SeoCollection(synchronizeUrl: true)` and `buildSeoCollectionNodes` can now
  opt a DOM-first collection into shareable, history-aware query state. Search
  replaces the current history entry; category, sort and page actions create
  entries; Back and Forward restore the same pure collection state. Parameters
  are namespaced by validated interaction id, preserve unrelated URL data and
  are canonicalized without introducing client-side routing.
* Added an opt-in cross-platform motion pilot for `SeoBarChart`.
  `SeoMotionPreset.gentle` drives Flutter and CSS from the same pure timing
  model, with a capped entrance stagger and decorative pointer/press emphasis.
  `SeoDomFirstFeature.motion` adds the fixed stylesheet without JavaScript;
  reduced-motion preferences render the final static state immediately. The
  default preset remains `none`, preserving previous widget behaviour and HTML
  bytes, and the renderer's tag, attribute and inline-style policies are
  unchanged.
* Added an opt-in DOM-first delivery slice for routes derived entirely from
  the pure component layer. `SeoRouteDelivery.domFirst` makes the semantic
  document the permanent page for humans and crawlers, through both shelf and
  static prerendering, without loading a Flutter web artifact. Resolver
  redirects and error documents are final on these routes regardless of
  `SeoRedirectScope`; Flutter-delivered routes retain their previous bytes and
  behaviour.
* `SeoDomFirstFeature.tabs` compiles the package's pure Dart tabs transition
  into a route-scoped browser runtime behind a separate opt-in. Flutter
  `SeoTabs` now delegates selection to the same transition. The DOM control
  validates its complete structure before mutation, creates fixed ARIA
  controls through one apply boundary, supports pointer and Arrow/Home/End
  navigation, and leaves the complete document readable without JavaScript.
  Application-authored transitions, effects, forms and client routing are not
  part of this first slice.
* Added a separate `domFirstStylesheet` input to static prerendering, matching
  the middleware API. Mixed sites can theme permanent HTML routes without
  changing the stylesheet bytes of Flutter-delivered routes.
* Added `SeoStepper`, a state-hidden-content bridge with lazy native Flutter
  bodies and every step present as an ordered semantic HTML list. A valid
  `interactionId` progressively adds validated step buttons, previous/next
  controls, live position, roving focus and Arrow/Home/End keyboard navigation;
  malformed and single-step structures remain complete static content.
* Added `SeoRichText`, a declarative inline model shared by native Flutter
  `TextSpan`s and semantic HTML. Strong importance, emphasis, inline code,
  safe links and line breaks retain their meaning instead of being flattened
  through `toPlainText()`; unsafe and nested link targets degrade to text.
* Added `SeoCarousel`, a bridge for virtualized `PageView.builder` content.
  Flutter keeps a lazy native page view while the semantic source contains
  every slide as a headed section. A valid `interactionId` progressively adds
  validated previous/next controls, live position, LTR/RTL keyboard navigation
  and complete no-script fallback; autoplay is deliberately excluded.
* `SeoNavMenu(interactionId: ...)` now supports the same opt-in progressive
  enhancement as tabs. The complete nested link tree stays in the source;
  validated branches gain native disclosure buttons with `aria-expanded`,
  `aria-controls` and Escape-to-close focus return. Linked parent entries keep
  a separate navigation link, while unlinked labels become the toggle only
  after enhancement.
* `SeoTabs(interactionId: ...)` can now opt a visible semantic page into
  package-owned progressive enhancement. All panels remain in the source;
  vanilla JavaScript adds validated ARIA tab controls, click handling, roving
  focus and Arrow/Home/End keyboard navigation. Invisible `inert` mirrors and
  duplicate DOM ids are refused.
* `prerenderSite(enableInteractions: true)` delivers the runtime only for
  `SeoRenderMode.visibleShell`; `SeoPage.visibleFromNodes` provides the same
  progressive HTML/CSS/JavaScript document without a Flutter bootstrap. Both
  support an optional CSP nonce on generated style and script tags. Existing
  rendering stays byte-compatible when interactions are disabled.
* Semi-transparent `SeoBarChart` and `SeoPieChart` colors now preserve
  their alpha channel in CSS as `#rrggbbaa`. Opaque colors keep their
  existing `#rrggbb` output. Component and theme CSS now share the same
  pure ARGB serializer.

## 0.9.0

The theme bridge: the visible shell in your app's design.

### `seoStylesheetFromTheme`

* Generates the shell stylesheet **from your `ThemeData`** — the full
  Material 3 color roles as CSS custom properties (`--esen-color-*`),
  the type scale (`--esen-type-*`), and the font family with a
  system-font fallback chain. The heading chain follows the Material
  scale (`h1` ← `headlineLarge`, which lands at exactly the default
  stylesheet's 2 rem); the dark theme rides along as a
  `prefers-color-scheme` block carrying only the tokens that differ.
* `ThemeData` exists only where Flutter runs; `prerenderSite` runs
  without Flutter. The bridge crosses that gap the same way the route
  table does: `checkOrUpdateSeoThemeCss` (in
  `package:esen_seo/testing.dart`) writes a committed
  `lib/seo_theme.g.dart` with one `const String` — app and prerender
  script import it, and every ordinary `flutter test` run verifies it
  against the live theme. Theme changed without regenerating? The
  build goes red with the exact command to run. Regeneration is only
  ever explicit (`--dart-define=esenSeoUpdate=true`) — deliberately no
  environment-variable switch, which an ambient CI variable could
  flip into silent write-mode. The generated CSS is a function of the
  Flutter version — pin dev and CI to the same Flutter, and regenerate
  after SDK upgrades; the guard's message tells toolchain skew apart
  from a real theme change. The guard is exported conditionally, so
  `testing.dart` still compiles under `flutter test --platform chrome`
  for parity users — on the web only *calling* the guard throws. The
  comparison covers the declared variable name, not just the CSS
  literal, and the generated file survives `dart format` untouched.
* Every token value passes an allow list before it becomes CSS —
  colors must be hex, sizes `rem`, font family names
  `[A-Za-z][A-Za-z0-9 -]*` (which drops Apple's dot-prefixed platform
  names and every CSS breakout payload with the same rule). What fails
  validation is dropped; the element rules carry fallbacks, so the
  shell degrades to the default look instead of breaking. The shell
  background is forced opaque — a translucent one would let Flutter's
  empty boot surface shine through.
* Material 2 themes (`useMaterial3: false`) mirror what M2 widgets
  actually paint: the divider comes from `dividerColor`, surfaces from
  `cardColor` — the scheme's M3 fallbacks would be quasi-black lines
  and flat surfaces the app never shows.
* Documented deviations: `h2`/`h3` render a step larger than the
  default stylesheet (Material scale), headings keep the theme's
  weight (Material 3 headings are regular, not bold), `h4`–`h6` are
  styled for the first time, and paragraphs default to `bodyLarge`
  (16 px) rather than Flutter's 14 px `bodyMedium` — `bodyRole:` gives
  1:1 parity. The chosen body role is applied completely: size,
  weight, line height, letter spacing and the font family all come
  from the same role. Elevation, shapes and ink effects are not
  mirrored.
* The layout skeleton is now a single shared source
  (`seo_theme_css.dart`) used by both `seoDefaultStylesheet` and the
  bridge — a grid fix in one stylesheet cannot quietly miss the other.
  As part of the unification the default stylesheet spaces `h4`–`h6`
  like the other headings.
* `prerenderSite` prints one line naming the stylesheet it embeds
  (default / themed / custom / none) — the guard watches the generated
  file, this line watches the last link of the chain: a stylesheet
  that is generated, committed and then never passed.

### The mirror follows SPA navigation, and "not shown" means not shown

* After a `Navigator.push`, the mirror kept serving the **previous**
  page: the refresh fired during the route transition, and nothing
  fired again when it settled. URL, title and canonical said `/demo`;
  the semantic body still said the home page — stale content with
  every signal claiming otherwise. Navigation now re-arms a short
  refresh window at both route-level (`SeoRouteObserver`, which also
  covers apps running purely on smart defaults with no `.seo()`
  markers at all) and marker-level (every `SeoWidget` listens to its
  own route's animation). Stated plainly, in the quick start and on
  `EsenSeo.init`/`SeoRouteObserver` both: **the observer is the
  navigation hook**. Nothing in Flutter tells the package about a
  push, so a pure smart-defaults app without the observer keeps
  serving the previous page's mirror — exactly as its title and
  canonical already behaved. That contract is pinned by a test. The window refreshes across the next few
  frames rather than betting on one — the Navigator applies the
  visibility flip in an Overlay rebuild whose exact frame is an
  implementation detail, `ModalRoute.animation` is a proxy that fires
  a spurious `completed` during the offstage warm-up of a fresh route,
  and the unchanged-HTML dedup makes the extra walks write-free.
* Underneath sat an older gap: the Navigator never puts inactive
  routes in `Offstage` — the Overlay keeps them mounted and merely
  skips them in paint. The walk skipped only `Offstage`, so **previous
  pages leaked into the mirror alongside the current one**. The walk
  now descends the way the framework itself defines "onstage"
  (`debugVisitOnstageChildren` — plain logic, the same thing the
  widget inspector relies on), which also stops inactive
  `IndexedStack` children from leaking. Deliberate exception: viewports
  and lazy lists filter by *visual* visibility there, and scrolled-away
  content is still page content — scroll machinery keeps the full
  traversal, pinned by a regression test.
* `Visibility(visible: false, maintainSize: true)` hides its child
  behind `Opacity(0)` — invisible but onstage, so no traversal can
  know. The widget itself is checked now, and so is its sliver twin
  `SliverVisibility` — the box widget alone was not the class. And
  explicitly NOT checked:
  `TickerMode(enabled: false)` — Flutter defines it as "pause the
  tickers", nothing more; perfectly visible content sits inside it,
  so treating it as an offstage signal would empty the mirror for
  exactly that content.

### Breaking

* **Flutter minimum is now `>=3.27.0`** (was `>=3.22.0`). The color
  conversion uses the float channel accessors introduced in 3.27 —
  `.value` is deprecated there, and `toARGB32()` does not exist yet.

## 0.8.0

An SEO audit — the package can now tell you whether your site is
actually correct, not just render it.

### `auditSeoRoutes`

* Reads the **route table**, not built HTML. The package already owns
  every URL, title and node, so a broken internal link is just an
  `href` that `matchSeoRoute` cannot match. No crawler, no HTML parser
  dependency, and it runs before `flutter build web` has done anything.
* Runs in a plain `test()`, so it needs no new CI job:
  `assertSeoHealthy(await auditSeoRoutes(routes: …, siteBase: …))`.
* Catches the class of mistake the renderer cannot refuse, because each
  one is a legal use of the API — all verified against the real code:
  a `noindex` page still listed in `sitemap.xml`; a concrete route
  shadowed by a `:param` pattern declared before it, so the page never
  runs while the sitemap keeps advertising the URL; a `canonicalUrl`
  the URL policy refuses, which leaves the page with **no** canonical
  and suppresses the derived one as well; and a schema value JSON
  cannot encode, which otherwise throws when the page renders.
* Plus duplicate titles and descriptions, missing or multiple `<h1>`,
  images with no `alt`, links with no destination or no anchor text,
  and hreflang clusters that are not reciprocal or omit the page
  itself — which Google discards silently.
* `SeoSeverity` is the contract: `error` is measurably wrong,
  `warning` is very likely wrong but legitimate sites exist,
  `info` never fails a build. Suppress any check by id via
  `SeoAuditPolicy(ignore: {…})`.
* A resolver that throws becomes a finding instead of aborting the run
  — but the report is marked `partial` and cross-page checks are then
  **skipped** rather than guessed, since "this title is unique" is
  unprovable with a page missing.

### Parity — `package:esen_seo/testing.dart`

* `auditSeoParity` compares the route table against the widget tree a
  visitor actually sees. The engine alone can only confirm the table
  agrees with itself; this is the check the whole approach rests on,
  since serving crawlers a separately built body is defensible only
  while the two say the same thing. The realistic failure is mundane —
  a headline renamed in the widget, the route body forgotten — and
  nothing else in the package can notice it.
* Split along the constraint: comparison is pure Dart
  (`compareSeoTrees`), so the logic is testable without pumping
  anything; only capturing the app's tree needs Flutter. The
  `WidgetTester` stays in your test behind a `pump` callback, so the
  package never depends on `flutter_test`.
* Text that reaches crawlers but not the app is an **error** — that is
  cloaking, however accidental. A differing `<h1>` is an error. A
  heading only the app shows is a warning, since an app legitimately
  shows more. Links are off by default: navigation lives in the Flutter
  shell, so the route body will never carry it.
* Coverage is reported honestly: checking no page at all is an error —
  a green run that proved nothing — while pages the sample deliberately
  skipped are named as info, since sampling is the caller's call.

### Fixed — errors reported on correct sites

An error-severity false positive is the worst defect an auditor can
have — it teaches a team to switch the check off. Each of these is
fixed, with a regression test built from the shape that triggered it:

* `SeoAuditPolicy(ignore: …)` was wired into 3 of 30 checks and into
  none of the error-severity ones, so the findings a team would most
  want to silence could not be. Suppression is applied centrally now.
* `link.broken` judged targets by which URLs happened to be
  *enumerated*, so a deep link into a `/docs/:page` route without
  `enumeratePaths` was an error — while the engine calls that same
  route a warning saying "its URLs work for visitors". It asks
  `matchSeoRoute` now, and treats `/whitepaper.pdf` as the asset it is.
* Host comparison was a string prefix, so `https://x.dev.evil.com`
  counted as the same site. It parses the URI.
* `canonical.unknown-path` did not strip query or fragment, so a search
  page canonicalising to itself with `?q=…` was a "404".
* hreflang reciprocity was judged against *indexable* pages, so a
  language variant deliberately kept out of the sitemap made its
  symmetric partner "not reciprocal" — asserting something untrue.
* Parity compared the *first* `<h1>` on each side, which an app shell
  or a Navigator route left mounted after a push made fail; and it
  treated punctuation as content, so an added exclamation mark broke
  the build.
* A canonical pointing at a 410, a redirect or a noindex page is now
  reported — the flagship case of the whole audit, and it was not
  implemented. `robots: 'none'` counts as noindex. A pathological
  node tree reports instead of raising `StackOverflowError`.

### Fixed — checks that reported nothing, or the wrong thing

* **`assertSeoHealthy`** — the test this package *recommended*,
  `expect(report.describe(), isNot(contains('[error]')))`, never
  failed: `describe()` marks an error with `x`. A helper that owns the
  comparison cannot drift from the format it compares against, so the
  helper exists now and the docs point at it. It throws with the whole
  report in the message.
* **Relative links were skipped entirely.** Only `/`-rooted hrefs were
  examined, so `about` and `../agb` could point anywhere at all. They
  are resolved against the page they appear on, the way a browser does,
  and the finding quotes both the attribute and the URL it means.
* **A `javascript:` href or image `src` is reported.** The renderer
  strips it, which is correct — and leaves the crawler an `<a>` that
  leads nowhere, with nothing anywhere saying why.
* **Parity missed the sharpest case:** an app that renders the server's
  headline as a `<p>`. All the words are present, so the text check saw
  nothing missing, and the app has no `<h1>`, so a guard that only ran
  when one existed skipped silently. It is an error now.
* **`paths: []` was a green parity run** that proved nothing. Checking
  no page at all is a failure; sampling some is the caller's call.
* **Pattern-versus-pattern shadowing.** `/blog/:slug` followed by
  `/blog/:id` leaves the second route wholly dead, and neither the
  duplicate-path check (the strings differ) nor the concrete-path check
  saw it.
* **hreflang** now asks `matchSeoRoute` like the link check does, so an
  alternate pointing into an un-enumerated `:param` route is no longer
  called unserved; reciprocity is only asserted for pages actually
  resolved. A relative hreflang URL is reported — the renderer emits it
  happily and Google then ignores it, which is the worst combination.
* **Schema requirements brought up to date.** `Article` no longer needs
  `headline` per Google's own documentation, so that is a warning, not
  a build failure. `Review` needs `author` and `itemReviewed` beside
  the rating; `Event` needs a `location` and `LocalBusiness` an
  `address` — both of which the factories omit when the caller passes
  nothing. A `Product` with only a name gets no snippet at all: Google
  needs `offers`, `review` or `aggregateRating` to have something to
  show.

### The audit checks the markup that actually ships

* **The audit now checks the renderer's view of the tree, not the raw
  one.** The render decision (`HtmlRenderer.effectiveBodyTag`) is
  exposed and the audit walks it: an `<img>` carrying text really
  renders as a `<span>`, an `<a>` inside an `<a>` really loses its
  link, and attribute names are lower-cased before they are written —
  so a perfectly rendered `{'SRC': …, 'ALT': …}` no longer produces
  two errors about attributes the output demonstrably carries.
* **Parity compares complete token sequences, not a bag of words or
  independent word pairs.** A passage whose words or repeated pairs
  appeared in separate places passed as delivered even though the
  passage itself never was. The app's words are concatenated in tree
  order first, so a sentence split across adjacent spans still matches;
  scattered fragments do not.
* **A same-host URL on another port or scheme is another origin.**
  `https://x.dev:8443/…` and `http://x.dev/…` no longer count as
  internal against `siteBase: https://x.dev`. Uri's default ports settle
  the port case — and a scheme-relative `//x.dev/agb` is now checked
  instead of skipped, while `HTTPS://` counts as absolute.
* **Pattern-versus-pattern shadowing generalised.** `/:section/:slug`
  declared before `/blog/:slug` swallows it exactly as completely as an
  identically shaped pattern, and the same-shape check could not see
  it.
* **A truncated walk is a finding** (`body.truncated`), on both the
  engine and the parity side — silence read as "checked and clean"
  about content nobody looked at. The parity text walk shares the same
  depth ceiling instead of recursing without one.
* **Schema requirements corrected against Google's documentation.**
  `Organization` has no required properties at all — the error failed
  valid markup; the name is a recommendation now. `WebSite` needs `url`
  as well as `name`. And the checks read *inside* the properties: a
  `Product` offer without a `price`, or an `aggregateRating` without a
  `ratingCount`/`reviewCount`, satisfies every presence check and still
  yields nothing.

### Deployment shapes, encodings and generator fidelity

* **Subpath deployments work now.** With `siteBase:
  'https://user.github.io/repo'` — the GitHub Pages shape the README
  itself advertises — the audit mapped the package's own derived
  canonical to `/repo/about`, a path no route serves, and failed EVERY
  page. The base's path prefix now maps URLs back into route space,
  and a same-host URL outside the prefix is another site.
* **Encoded and decoded spellings are one page.** `Uri.path` keeps
  percent-escapes, so a route declared `/über` failed its own derived
  canonical (`/%C3%BCber`). Paths are decoded segment by segment before
  comparison, so an encoded slash stays within its route parameter.
  The middleware and route observer also map a deployment's base-path
  prefix back into route space.
* **Parity severity is graded.** An SSR passage whose words are all
  present but not adjacent — a Row of Columns interleaves label and
  value in tree order — is a warning, not build-failing cloaking; only
  words that are genuinely gone stay an error. U+FFFC (the flattened
  form of an inline `WidgetSpan`) no longer severs a passage. A tree
  beyond the renderer's depth limit is a structural error, and parity
  stops before making content claims about the part it could not walk.
* **The renderer's view, applied everywhere it was still missing.**
  JSON-LD payloads no longer contribute phantom headings and text to
  the audit (the renderer never renders a script's children);
  `rawText` counts as the visible content it is; the URL policy is
  checked against the RAW attribute value, exactly as the renderer
  checks it — a trailing newline made the renderer drop an `href`
  while the audit, checking the trimmed value, saw nothing; and an
  image anywhere inside a link counts as its anchor text when it has a
  non-empty `alt`, not only when it is a direct child.
* **llms-full.txt now describes the page that ships.** The markdown
  renderer read the raw tree: `'H2'` lost its heading, an `img`
  carrying text advertised an image URL the renderer refuses — and
  dropped the caption it keeps. It walks `HtmlRenderer`'s effective
  view now, with the same depth ceiling as the audit.
* **sitemap.xml applies the URL policy to hreflang alternates.** It
  was the one output path around the choke point — a `javascript:`
  alternate from CMS data shipped verbatim in the served XML while the
  head correctly refused it.
* **`HtmlRenderer` refuses trees deeper than 500 levels** with an
  error that names the likely cause (a self-referential resolver tree)
  instead of a `StackOverflowError` mid-request that names nothing.
* **New checks, corrected checks.** `canonical.chain` (A→B→C — Google
  distrusts chains); `hreflang.invalid-code` (`en_US` is the single
  most common authoring mistake, and Google ignores it silently);
  `hreflang.duplicate-target` (de and en on the same URL — the
  copy-paste slip that orphans a language while the cluster stays
  formally valid). `canonical.non-indexable` judges by the robots
  signal, not sitemap membership — canonicalising onto a page
  deliberately kept out of sitemap.xml is legitimate. Duplicate titles
  match case- and whitespace-insensitively. hreflang codes are checked
  against the actual language, script and region registries instead of
  only their shape. A regular `Product` Offer needs a usable price;
  missing currency is a warning for product snippets, while an
  `AggregateOffer` requires `lowPrice` and `priceCurrency`. An
  `aggregateRating` in a one-element list is checked like one passed
  directly.
* **Fewer wrong findings elsewhere.** An `additionalPaths` placeholder
  (documented: content served outside the table) is no longer nagged
  for a title it cannot have; a duplicate route pattern is one finding,
  not duplicate-path plus shadowed; a pattern with an empty segment is
  not "shadowed" by a `:param` that provably never matches it; a fully
  walked tree of exactly maxDepth+1 levels no longer claims its own
  findings were incomplete.

### Server hardening

Four of these change published behavior — read the breaking notes
before upgrading.

* **Breaking: `seoRedirectMiddleware(forceHttps:)` no longer reads
  `x-forwarded-proto` by default.** The header is caller-controlled on
  any server reachable directly, so trusting it unconditionally let a
  request pick its own redirect scheme. Behind a reverse proxy —
  where the backend sees plain http — set `trustProxy: true` when
  upgrading, or `forceHttps` will loop: the proxy keeps fetching over
  http and every fetch redirects.
* **Breaking: entries in `seoRedirectMiddleware(redirects:)` are
  validated at construction.** A target that is neither an http(s) URL
  with a host nor an absolute path throws an `ArgumentError`
  immediately, instead of being emitted into a `Location` header at
  request time. Path-only redirects now send a relative `Location`, so
  a request-controlled `Host` header is never reflected — and mapped
  redirects preserve the query string.
* **Breaking: `no-referrer-when-downgrade` is no longer an accepted
  `referrerpolicy`.** It hands the full URL — path and query — to
  third-party hosts on same-scheme navigation, which is exactly what
  the allow list exists to prevent; it should never have been on it.
  `SeoMeta.extraMeta` entries named `referrer` pass through the same
  policy now, closing the one remaining way to emit an unsafe global
  referrer rule.
* **Breaking: `matchSeoRoute` percent-decodes path segments.** A route
  declared `/über` is now reachable as `/%C3%BCber`, and a `:param`
  resolver receives the decoded value (`café`, or `a/b` for an encoded
  slash) instead of the raw escape sequence. Decoding happens per
  segment, so `%2F` cannot create a route boundary.
* A dot in the last path segment no longer marks a URL as a static
  asset. `/page.html` is a page and `/releases/v1.2` is a slug; the
  middleware serves bots SSR for both now, and the audit checks links
  into them. Known page extensions and version-shaped segments decide,
  one shared rule (`looksLikeSeoPagePath`) for both consumers.
* The hreflang code check validates against a snapshot of the IANA
  registry instead of a shape regex — per Google's documentation only
  ISO 639-1 languages and ISO 3166-1 Alpha-2 regions are supported,
  and Google's own example of an unsupported code, `es-419`, now
  fails the audit exactly as it fails in Search.
* Parity requires the SSR passage as one contiguous token sequence in
  the app's text, closing the overlapping-pairs gap (`buy now free`
  passing against `buy now … now free`). The base-path mapping from
  the audit round now also applies to `seoBotMiddleware` and
  `SeoRouteObserver`, hash-router fragments (`#/docs`) are told apart
  from in-page anchors (`/docs#install`), and `prerenderSite` refuses
  templates missing `<html>`/`</head>`/`<body>` and route pairs that
  collide on case-insensitive file systems.

### Also

* CI runs the example app's own test suite, which audits a real grown
  route table with the released API. It existed but ran nowhere.
* `tool/check_pure_dart.dart` replaces CI's hand-written file list with
  an import-graph walk. Three holes in it are closed
  and proven closed by planting each: a `package:esen_seo/…`
  self-import, a Flutter import inside a conditional-import branch, and
  a run from the wrong directory reporting a cheerful pass over a graph
  that was not there. The hand-written list had fallen behind — two
  files exported by `core.dart` were never in it — and could not see a
  Flutter import reached indirectly at all. 49 files are covered where
  12 were named.

## 0.7.0

The runtime HTTP surface for dynamic routes — the half of 0.6.0's
resolver that was deliberately held back.

### `seoBotMiddleware`

* **Resolver redirects reach humans too.** A `SeoRedirect` from a
  resolver was served only to bots in 0.6.0; now it answers human
  visitors as well by default (`applyResolverRedirects:
  SeoRedirectScope.all`), because a 301 shown only to Googlebot is
  cloaking. `.botsOnly` keeps the old behaviour, `.off` ignores resolver
  redirects (pair it with `seoRedirectMiddleware`). Error statuses
  (404/410) stay bot-only regardless — a human keeps the Flutter app,
  not an SSR stub — and a resolver failure on the human path never
  becomes a 5xx.
* **`SeoDocument.headers` are emitted**, filtered at a single chokepoint.
  The names are an **allow list** — caching validators
  (`cache-control`, `expires`, `etag`, `last-modified`, `age`),
  `x-robots-tag`, `link` and `content-language`. Nothing else: not
  `set-cookie` (session fixation on a page that has no session), not
  `content-encoding` (claiming gzip over an uncompressed body), not
  CORS/CSP/HSTS (site-wide posture must not be decided per page by
  content), and not the protocol headers the package and the adapter
  own. Names must be valid HTTP tokens and values printable US-ASCII —
  stricter than "no CR/LF" deliberately: a non-ASCII value cannot split
  a response, but `shelf_io` refuses to encode it and the page never
  arrives at all. Page content must not be able to take a page down.
  `vary` is **merged** with `User-Agent`, never replaced. All of it is
  covered by tests over a real socket, not just in-memory `Response`
  objects — the failure mode here is a hung request, which an in-memory
  test cannot see.
* **Infrastructure files are cached with a TTL**, classified per detail
  level. `sitemap.xml` and `llms.txt` read only head metadata, so they
  cache forever when no route is dynamic and none enumerates paths.
  `llms-full.txt` also renders bodies — and a *classic* route's `body`
  builder may be async and database-backed, so "classic" does not mean
  "immutable" — so it caches forever only when no route has a body
  builder at all. Otherwise 15 minutes, overridable via
  `infrastructureCacheTtl:`. One shared future per file
  also collapses a stampede — twenty concurrent crawler hits trigger one
  pass, not twenty. A build that throws is evicted at once; a build that
  *degraded* (a row failed and was dropped) is served once but not
  cached, so a transient database blip cannot freeze a partial sitemap
  in place for the whole TTL.

### Not yet

`SeoDocument.headers` is honoured by the middleware only; the
prerenderer still ignores it, since a static file has no response
headers. `SeoPage.bodyHtml` (verbatim HTML past the policy) still has no
representation in `SeoDocument` — `resolve:` on the middleware remains
the escape hatch for hand-written HTML.

## 0.6.0

Database-backed routes: one read produces a page's metadata **and** its
body, so the two can never describe different records.

### `SeoRoute.dynamic`

* `SeoRoute.dynamic(path:, resolve:)` resolves one concrete URL to a
  `SeoResolution` — a `SeoDocument` (meta + body + status + lastModified)
  or a `SeoRedirect`. For `/products/:slug` backed by a database, title,
  description, schemas, body and last-modified come from a single record
  instead of two reads that could disagree.
* `SeoDocument.notFound()` / `.gone()` express a real 404 / 410 from a
  resolver; `SeoRedirect` expresses a 301/302. The redirect target runs
  through a single chokepoint (`finishSeoResolution`) that is *stricter*
  than the link policy: `http`/`https` or a relative path only, a real
  redirect status only, and never an empty or fragment-only target
  (both of which redirect to themselves). So a resolver can never emit
  a `javascript:` `Location`, a `mailto:` one, or split a response — a
  bad target becomes a 404.
* `SeoRoute(enumeratePaths:)` lists the concrete URLs a `:param` route
  stands for, so the sitemap, llms.txt and the prerenderer can cover a
  database of pages without hand-listing every slug.
* `resolveSeoPages(...)` resolves the whole table once (bounded
  concurrency, per-page error policy); the prerenderer, the middleware
  and both llms generators share that single pass, so a URL is read once
  no matter how many outputs it feeds.
* The classic `SeoRoute(meta:, body:)` is **unchanged** and now sugar
  over a resolver — one internal content path. Existing route tables,
  the example app, the SSR server and `prerenderSite` need no edits.

### Fixed by the same change

* `llms-full.txt` read a page's metadata and its body separately (two
  reads of one record in one file); they now come from a single
  resolution, so the title and body in the output always match.
* A resolver-issued redirect or a non-200 is dropped from sitemap.xml
  and llms.txt and skipped by the prerenderer (reported via `onSkipped`)
  — a static host can't emit a 301 or a 410 body with a 200 status.
* A per-record `lastModified` now drives `<lastmod>`, and a record can
  pull an unpublished page out of the sitemap even when the route opts
  in.

### Breaking

* `SeoRoute.meta` is now `SeoMetaBuilder?` (was non-nullable) and
  deprecated — it is `null` for `SeoRoute.dynamic`. **Constructing** a
  route is unchanged; only reading the field off a route breaks. Use
  `matchSeoRoute(...).resolveSync()?.metaOrNull`.
* `SeoRouteMatch.buildMeta()` / `buildBody()` are deprecated (removed in
  1.0); `buildMeta()` throws for a dynamic route. `seoSitemapXml`,
  `seoLlmsTxt` and `seoLlmsFullTxt` now take **either** `routes:` or a
  pre-resolved `pages:`; the sync two throw a `StateError` naming the fix
  when a `routes:` table contains a dynamic route rather than silently
  emitting an incomplete sitemap. Return types are unchanged. Both
  `seoBotMiddleware` and `prerenderSite` resolve internally, so this is
  unreachable from ordinary use.

### Not yet — coming in 0.7.0

Resolver redirects apply to bots today; extending them to human visitors
(the anti-cloaking default), emitting `SeoDocument.headers`, and TTL
caching of a dynamic table's infrastructure files are the runtime HTTP
surface, kept separate from this release.

## 0.5.1

Three findings from an audit that finished after 0.5.0 went out. Two are
defects in the visible shell; one is a claim in 0.5.0's own documentation
that does not hold.

* **The invisible mirror could paint.** `width:0;height:0` empties a
  box's content area, but padding, borders and shadows are drawn outside
  it — and `seoDefaultStylesheet` supplies them, since its
  `#esen-seo-content` rule sets `padding:2rem 1.25rem;background:#fff`.
  The result was a white ~40×64 px rectangle in the top-left corner:
  permanently in `seoOnly` whenever a stylesheet was passed, and on
  **every** visible shell after the handoff, which restores that same
  inline style while the stylesheet stays in the head. The container's
  geometry is now pinned inline — padding, border, outline, shadow and
  the max/min box — so no author rule can give it a surface.
* **`visibleShell` requires `EsenSeo.init()`**, and said so nowhere. The
  handoff runs on the first mirror refresh, which only `init()` or a
  mounting `.seo()` widget schedules. An app doing neither kept the
  shell over a Flutter app that had long since painted. There is
  deliberately still no timeout: a shell that stays put is correct when
  the engine never arrives, and the package cannot tell that case from a
  forgotten call. Now documented as a requirement in the README, on
  `SeoRenderMode.visibleShell` and on `prerenderSite`.
* **A corrected claim.** 0.5.0 justified the CSS property allow list
  with "an element in the mirror cannot be lifted out of the flow to
  cover the page". The first half is right — nothing can escape the
  container's clip. The second is not: inside the visible shell a later
  sibling with `margin-top:-100vh` covers an earlier one, leaving the
  real headline visible while its clicks go elsewhere, and
  `box-shadow:0 0 0 100vmax` repaints the viewport from a 1 px box.
  Neither is patchable — `margin` and `box-shadow` are what documents
  are made of. The allow list keeps content inside the container; it
  does not police what that content does to itself. The README and the
  policy's own comment now say that instead.

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
* `style` is an allow list of **properties** — text, box, colour,
  flexbox and grid — and positioning is not among them. Patching
  `position` value by value kept losing: `fixed`, then `sticky`, then
  `-webkit-sticky`, then `var(--x)` indirection, and finally
  `position:relative;top:-100vh;height:200vh;z-index:2147483647`, which
  covers the page from an allowed value. In `visibleShell` that
  container is a full-viewport clickable overlay in front of the booting
  app, so the whole class had to go rather than each instance. CSS
  comments and escapes no longer hide a property name either.
* Media may not `autoplay`, and `referrerpolicy` may not be set to a
  value that hands the full URL to a third-party host.
* The README now states where this guarantee **ends**. The policy makes
  content non-executable; it does not make it honest. In
  `visibleShell` an empty `<a>` sized `width:100vw;height:100vh` paints
  nothing and still takes the click — two properties every document
  needs — and a `class` value reaches whatever your own stylesheet
  declares for that name, `position` included. No property list closes
  that; vetting untrusted content before showing it is the
  application's call. In the default `seoOnly` mode it cannot arise:
  the mirror is clipped to zero size, `pointer-events:none` and
  `inert`, and neither property can be set from inside.
* The mirror stays a well-formed tree: a nested `<a>` becomes a `span`
  (the parser would otherwise empty the surrounding link), and void
  elements or empty tags carrying content keep it instead of dropping
  it silently.
* An image `alt` text was the one text path into `llms-full.txt` that
  skipped the single-line collapse, so a blank line broke out of the
  `![…]` label and wrote its own headings into the file AI assistants
  read as the structure of the page.
* Content may no longer name the hooks the injector steers by — the id
  `esen-seo-content` and the `data-esen-seo` markers. Nothing was
  exploitable, but the reason was document order rather than a rule.
* `autofocus`, `contenteditable`, `accesskey` and `tabindex` join
  `autoplay` on the refused list: the mirror is there to be read. And
  the visible shell becomes `inert` when its fade *starts*, not when it
  ends — the mouse was already held off for those 150 ms, the keyboard
  was not.
* One XML-forbidden character in a route path no longer makes the whole
  `sitemap.xml` unparseable, and slugs containing `?` or `#` are
  refused rather than written to a file no URL can reach. A route path
  may also not be a *prefix* of a generated file, since `/robots.txt/x`
  would create a directory where `robots.txt` has to go — and not
  contain a segment named `index.html`, which is the file every page is
  written to, so `/a` and `/a/index.html/b` would fight over the same
  name and the build would die on whichever came second. The IndexNow
  key reserves its file name the same way, and is validated before the
  first page is written rather than after the last — an invalid key used
  to abort the run half-way, leaving new pages beside an old sitemap.
  An empty path segment is refused too: `/a//b` wrote its file as `a/b`
  while the sitemap advertised `/a//b`, so a real `/a/b` route replaced
  it without a word.
* Bot responses (and the app responses beside them) carry
  `Vary: User-Agent`. Without it a CDN caches whichever variant it saw
  first and serves the bot HTML to visitors, or the empty Flutter shell
  to Google. An existing `Vary` from the wrapped handler is merged, not
  overwritten — otherwise the fix would cost the app its
  `Accept-Encoding` variant.
* A route with no `body` builder no longer answers bots with an empty
  200 page — an empty page indexes worse than the app itself. It falls
  through to the app, not into the 404 branch: the route exists, it just
  has nothing to mirror, and a 404 would be far worse than either.
* `Google-InspectionTool`, `GoogleOther` and `StoreBot-Google` are
  recognized, so URL Inspection and the Rich Results Test see the
  server-rendered version.
* `SeoPage.fromNodes` is the documented way to build a page; the
  `bodyHtml` constructor is the deliberate exception and says so.

### Fixed

* `SeoNavMenu` now shows every declared level on screen. The mirror was
  already arbitrarily deep, so grandchildren existed in the HTML but
  could not be reached in the app; the open set is keyed by label path,
  so same-named entries at different depths stay independent.
* `SeoBlock` skips building its HTML on platforms without a mirror. A
  `SeoListView` was translating every entry on every build on mobile,
  and throwing the result away.
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
