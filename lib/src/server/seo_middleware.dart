import 'dart:async';

import 'package:shelf/shelf.dart';

import '../meta/seo_meta.dart';
import '../renderer/seo_node.dart';
import '../routing/seo_resolution.dart';
import '../routing/seo_resolved_page.dart';
import '../routing/seo_route.dart';
import 'bot_detector.dart';
import 'llms_txt.dart';
import 'seo_page.dart';
import 'sitemap.dart';

/// Maps an incoming request to the [SeoPage] a bot should receive,
/// or `null` to fall through to the regular Flutter app.
typedef SeoPageResolver = FutureOr<SeoPage?> Function(Request request);

/// Who a resolver-issued [SeoRedirect] is honoured for.
///
/// The default [all] serves the 301 to human visitors as well as
/// crawlers, because a redirect shown only to Googlebot is cloaking —
/// bots and users must reach the same destination. It costs one extra
/// head resolution per human page view on a dynamic table; a fully
/// static table never takes the branch, since a static resolution can
/// never be a redirect.
///
/// Note this governs only *redirects*. Error statuses (404, 410) stay
/// bot-only regardless — a human hitting a missing page keeps the
/// Flutter app rather than an SSR stub, and the app's own router owns
/// what they see.
enum SeoRedirectScope {
  /// Redirect both humans and bots (the anti-cloaking default).
  all,

  /// Redirect only crawlers; humans fall through to the app and its
  /// router handles navigation.
  botsOnly,

  /// Ignore resolver redirects entirely — pair this with
  /// `seoRedirectMiddleware` if you drive 301s from a map instead.
  off,
}

/// The default for `seoBotMiddleware(infrastructureCacheTtl:)`: derive
/// each infrastructure file's cache lifetime from what it actually
/// reads, rather than from one flag for the whole table.
///
/// - `sitemap.xml` and `llms.txt` need only head metadata, so they are
///   cached for the process lifetime unless a route is dynamic or
///   enumerates its paths.
/// - `llms-full.txt` also renders bodies, and a **classic** route's
///   `body` builder may be async and database-backed — "classic" does
///   not mean "immutable". It is cached for the process lifetime only
///   when no route has a body builder at all.
///
/// Anything not eligible for a forever-cache gets 15 minutes, so a
/// long-running server never advertises a sitemap frozen at boot. Pass
/// an explicit [Duration] to override both, or `null` to cache forever
/// regardless.
const Duration seoAutoInfrastructureCacheTtl = Duration(microseconds: -1);

/// Shelf middleware that serves semantic HTML to bots and passes real
/// users through to the wrapped handler (usually the Flutter web build).
///
/// The recommended setup is the shared route table — one definition for
/// app and server:
///
/// ```dart
/// final handler = const Pipeline()
///     .addMiddleware(seoBotMiddleware(
///       routes: seoRoutes,                    // aus lib/seo_routes.dart
///       siteBase: 'https://esen.software',
///     ))
///     .addHandler(createStaticHandler('build/web', defaultDocument: 'index.html'));
/// ```
///
/// With [routes] set, the middleware additionally:
///
/// - derives canonical URLs from [siteBase] for routes without one,
/// - serves `/sitemap.xml`, `/robots.txt`, `/llms.txt` and
///   `/llms-full.txt` (to every client, not just bots) generated from
///   the table,
/// - answers unknown page paths with a real **HTTP 404** for bots
///   instead of the Flutter app — avoiding the classic SPA soft-404
///   problem. Paths whose last segment contains a dot (assets like
///   `main.dart.js`) always fall through to the wrapped handler.
///
/// With [indexNowKey] set, the IndexNow key file `/<key>.txt` is served
/// too, so `submitIndexNow` pings verify without extra hosting setup.
///
/// For special cases beyond the table, [resolve] is consulted when no
/// route matches.
Middleware seoBotMiddleware({
  List<SeoRoute>? routes,
  SeoPageResolver? resolve,
  String? siteBase,
  bool serveSitemap = true,
  bool serveRobotsTxt = true,
  bool serveLlmsTxt = true,
  String? indexNowKey,
  List<String> additionalSitemapPaths = const [],
  bool unknownRoutesAs404 = true,
  BotDetector detector = const BotDetector(),
  SeoRedirectScope applyResolverRedirects = SeoRedirectScope.all,
  Duration? infrastructureCacheTtl = seoAutoInfrastructureCacheTtl,

  /// Called when a route resolver fails.
  ///
  /// **Set this if you use dynamic routes.** The infrastructure
  /// endpoints deliberately survive a failing page — a sitemap missing
  /// one URL beats a sitemap that 500s — which means without this
  /// callback that page disappears from `/sitemap.xml` and `/llms.txt`
  /// with nothing to show for it. On the page path itself the error is
  /// reported and then rethrown, so the crawler gets a 5xx and comes
  /// back rather than indexing an empty shell.
  void Function(String path, Object error, StackTrace stack)? onResolveError,
}) {
  assert(
    routes != null || resolve != null,
    'seoBotMiddleware needs `routes` and/or `resolve`.',
  );
  // Not just `isDynamic`: a CLASSIC route may carry an async
  // `enumeratePaths` too, and the synchronous pass cannot await it
  // either. Deciding on "is dynamic" alone made /sitemap.xml throw for a
  // perfectly legal table.
  final needsAsyncResolution =
      routes?.any((r) => r.isDynamic || r.enumeratePaths != null) ?? false;
  // Narrower than the above on purpose: only a `SeoRoute.dynamic` can
  // ever resolve to a redirect. A classic route with an async
  // `enumeratePaths` needs the async pass for the sitemap but can never
  // produce one, so it must not pay for a head resolve on every human
  // page view.
  final hasDynamicRoute = routes?.any((r) => r.isDynamic) ?? false;
  // "Classic" does not mean "immutable": a classic route's `body`
  // builder may be async and read a database. Its output only reaches
  // llms-full.txt (the sitemap and llms.txt need head detail, which
  // never touches the body), but freezing THAT for the process lifetime
  // would serve content captured at boot forever. It also has to take
  // the async path so a failing body goes through the degrade-and-report
  // policy instead of failing the whole endpoint.
  final fullDetailMayDoIo = needsAsyncResolution ||
      // ignore: deprecated_member_use_from_same_package
      (routes?.any((r) => r.body != null) ?? false);
  // Resolve the sentinel once, and separately per detail level: the
  // sitemap and llms.txt only ever read head metadata, while
  // llms-full.txt also renders bodies — so a table that is "static" for
  // the first two can still be database-backed for the third.
  const auto = seoAutoInfrastructureCacheTtl;
  const autoTtl = Duration(minutes: 15);
  final Duration? headTtl = infrastructureCacheTtl == auto
      ? (needsAsyncResolution ? autoTtl : null)
      : infrastructureCacheTtl;
  final Duration? fullTtl = infrastructureCacheTtl == auto
      ? (fullDetailMayDoIo ? autoTtl : null)
      : infrastructureCacheTtl;
  return (Handler inner) {
    String? robotsCache; // pure siteBase, never changes — no TTL needed

    void report(String p, Object e, StackTrace s) =>
        onResolveError?.call(p, e, s);

    // One cached Future per infrastructure file. A single shared Future
    // per key does double duty: it caches the result until [infraTtl]
    // expires (null = forever), and it collapses a stampede — twenty
    // concurrent crawlers hitting /sitemap.xml trigger one pass, not
    // twenty.
    //
    // Two things are deliberately NOT cached for the full TTL:
    //  * a build that throws is evicted at once, so the next request
    //    retries instead of replaying the error;
    //  * a build that DEGRADED — some rows failed and were dropped —
    //    is served this once but evicted too, so a transient database
    //    blip does not freeze an incomplete sitemap in place for
    //    15 minutes after the database has recovered.
    final cache = <String, Future<String>>{};
    final timers = <String, Timer>{};

    // Evict only if the slot still holds THIS generation. A build that
    // outlives its own TTL would otherwise delete the newer entry a
    // later request had already installed, quietly disabling the cache.
    void evict(String key, Future<String> generation) {
      if (!identical(cache[key], generation)) return;
      cache.remove(key);
      timers.remove(key)?.cancel();
    }

    Future<String> cached(
      String key,
      Duration? ttl,
      Future<String> Function(void Function() markDegraded) build,
    ) {
      final hit = cache[key];
      if (hit != null) return hit;
      var degraded = false;
      late final Future<String> future;
      future = () async {
        try {
          final result = await build(() => degraded = true);
          if (degraded) evict(key, future);
          return result;
        } catch (_) {
          evict(key, future);
          rethrow;
        }
      }();
      cache[key] = future;
      if (ttl != null) {
        timers[key] = Timer(ttl, () => evict(key, future));
      }
      return future;
    }

    return (Request request) async {
      final path = normalizeSeoPath(request.url.path);

      // Infrastruktur-Dateien — für alle Clients, nicht nur Bots.
      if (siteBase != null) {
        if (serveSitemap && routes != null && path == '/sitemap.xml') {
          final xml = await cached(
            '/sitemap.xml',
            headTtl,
            (markDegraded) async => needsAsyncResolution
                ? seoSitemapXml(
                    siteBase: siteBase,
                    pages: await resolveSeoPages(
                      routes: routes,
                      canonicalBase: siteBase,
                      additionalPaths: additionalSitemapPaths,
                      detail: SeoDetail.head,
                      onError: (p, e, st) {
                        markDegraded();
                        report(p, e, st);
                      },
                    ),
                  )
                : seoSitemapXml(
                    routes: routes,
                    siteBase: siteBase,
                    additionalPaths: additionalSitemapPaths,
                  ),
          );
          return Response.ok(
            xml,
            headers: {'content-type': 'application/xml; charset=utf-8'},
          );
        }
        if (serveRobotsTxt && path == '/robots.txt') {
          robotsCache ??=
              seoRobotsTxt(siteBase: siteBase, includeSitemap: serveSitemap);
          return Response.ok(
            robotsCache,
            headers: {'content-type': 'text/plain; charset=utf-8'},
          );
        }
        if (serveLlmsTxt && routes != null && path == '/llms.txt') {
          final txt = await cached(
            '/llms.txt',
            headTtl,
            (markDegraded) async => needsAsyncResolution
                ? seoLlmsTxt(
                    siteBase: siteBase,
                    pages: await resolveSeoPages(
                      routes: routes,
                      canonicalBase: siteBase,
                      additionalPaths: additionalSitemapPaths,
                      detail: SeoDetail.head,
                      onError: (p, e, st) {
                        markDegraded();
                        report(p, e, st);
                      },
                    ),
                  )
                : seoLlmsTxt(
                    routes: routes,
                    siteBase: siteBase,
                    additionalPaths: additionalSitemapPaths,
                  ),
          );
          return Response.ok(
            txt,
            headers: {'content-type': 'text/plain; charset=utf-8'},
          );
        }
        if (serveLlmsTxt && routes != null && path == '/llms-full.txt') {
          final txt = await cached(
            '/llms-full.txt',
            fullTtl,
            (markDegraded) async => fullDetailMayDoIo
                ? seoLlmsFullTxt(
                    siteBase: siteBase,
                    pages: await resolveSeoPages(
                      routes: routes,
                      canonicalBase: siteBase,
                      additionalPaths: additionalSitemapPaths,
                      detail: SeoDetail.full,
                      onError: (p, e, st) {
                        markDegraded();
                        report(p, e, st);
                      },
                    ),
                  )
                : seoLlmsFullTxt(
                    routes: routes,
                    siteBase: siteBase,
                    additionalPaths: additionalSitemapPaths,
                  ),
          );
          return Response.ok(
            txt,
            headers: {'content-type': 'text/plain; charset=utf-8'},
          );
        }
      }
      if (indexNowKey != null && path == '/$indexNowKey.txt') {
        return Response.ok(
          indexNowKey,
          headers: {'content-type': 'text/plain; charset=utf-8'},
        );
      }

      final isBot = detector.isBot(request.headers['user-agent']);

      // A resolver redirect applies to humans too by default — a 301
      // shown only to Googlebot is cloaking, so bots and users must
      // reach the same destination. Only a dynamic table can produce a
      // redirect (a static resolution never is one), and only when the
      // scope allows it. A resolver failure here must never 5xx a human:
      // it is reported and falls through to the app, which still renders.
      // No `_looksLikePage` filter here, deliberately: the bot branch
      // has none either, and gating only this side made a redirect for a
      // dotted path (`/old-page.html` → clean URL, the commonest
      // relaunch mapping there is) reach crawlers but not humans — the
      // exact cloaking this mode exists to prevent. `matchSeoRoute` is
      // already the right filter: an asset request matches no route and
      // costs nothing.
      if (!isBot &&
          hasDynamicRoute &&
          routes != null &&
          applyResolverRedirects == SeoRedirectScope.all) {
        final match = matchSeoRoute(routes, path);
        // Per route, not per table: in a mixed table the classic routes
        // must not pay a meta build on every human page view just
        // because a dynamic route exists somewhere else. Only a dynamic
        // route can resolve to a redirect.
        if (match != null && match.route.isDynamic) {
          try {
            final res = await match.resolve(
              detail: SeoDetail.head,
              canonicalBase: siteBase,
              onWarning: (p, w) => report(p, StateError(w), StackTrace.current),
            );
            if (res is SeoRedirect) {
              return Response(
                res.statusCode,
                headers: {'location': res.location, ..._varyHeader},
              );
            }
          } catch (error, stack) {
            report(path, error, stack);
          }
        }
      }

      if (!isBot) {
        return _appResponse(inner, request);
      }

      var routeExists = false;
      if (routes != null) {
        final match = matchSeoRoute(routes, path);
        if (match != null) {
          routeExists = true;
          final SeoResolution resolution;
          try {
            resolution = await match.resolve(
              canonicalBase: siteBase,
              onWarning: (p, w) => report(p, StateError(w), StackTrace.current),
            );
          } catch (error, stack) {
            // The page path used to be the one place a resolver failure
            // bypassed onResolveError entirely. Report it, then let it
            // through: a 5xx tells a crawler to come back, while serving
            // the empty Flutter shell with a 200 invites it to index
            // nothing at all.
            report(path, error, stack);
            rethrow;
          }
          switch (resolution) {
            case SeoRedirect(:final location, :final statusCode):
              // Under `off` the redirect is ignored and the request
              // falls through to the app (pair with seoRedirectMiddleware
              // to drive 301s from a map instead). Otherwise the bot gets
              // it; the human branch above already handled `all`.
              if (applyResolverRedirects == SeoRedirectScope.off) break;
              return Response(
                statusCode,
                headers: {'location': location, ..._varyHeader},
              );
            case SeoDocument(:final statusCode, :final body, :final meta)
                when statusCode >= 400:
              // A real error status with the document's own body, or the
              // built-in error markup when it carries none — but always
              // with the resolver's own metadata. `SeoDocument.notFound`
              // takes a `meta:` argument, so silently swapping in a
              // generic page would throw away a title and description
              // the caller deliberately supplied.
              return _htmlResponse(
                SeoPage.fromNodes(
                  meta: meta.title == null
                      ? meta.copyWith(title: _statusTitle(statusCode))
                      : meta,
                  body: body.isEmpty ? _statusBody(statusCode) : body,
                  lang: resolution.lang ?? match.route.lang,
                ),
                status: statusCode,
                extraHeaders: _safeHeaders(resolution.headers),
              );
            case SeoDocument(:final body, :final meta):
              // A 200 with nothing to mirror falls through to the app —
              // an empty SSR page indexes worse than the Flutter shell.
              if (body.isNotEmpty) {
                return _htmlResponse(
                  SeoPage.fromNodes(
                    meta: meta,
                    body: body,
                    lang: resolution.lang ?? match.route.lang,
                  ),
                  extraHeaders: _safeHeaders(resolution.headers),
                );
              }
          }
        }
      }

      if (resolve != null) {
        final page = await resolve(request);
        if (page != null) return _htmlResponse(page);
      }

      // Soft-404 vermeiden: unbekannte seiten-artige Pfade bekommen für
      // Bots einen echten 404 statt der Flutter-App mit Status 200.
      // Eine Route, die es GIBT, gehört niemals hierher — sie hat nur
      // keinen Body, und dann ist die App die richtige Antwort.
      if (routes != null &&
          !routeExists &&
          unknownRoutesAs404 &&
          _looksLikePage(path)) {
        return _htmlResponse(_notFoundPage(), status: 404);
      }

      return _appResponse(inner, request);
    };
  };
}

Response _htmlResponse(
  SeoPage page, {
  int status = 200,
  Map<String, String>? extraHeaders,
}) =>
    Response(
      status,
      body: page.toHtmlDocument(),
      headers: {
        'content-type': 'text/html; charset=utf-8',
        // Kennzeichnet SSR-Antworten, z.B. zum Debuggen mit curl.
        'x-esen-seo': 'ssr',
        // extraHeaders (from _safeHeaders) already carries a merged
        // `vary` including User-Agent; without it, the plain vary applies.
        ...(extraHeaders ?? _varyHeader),
      },
    );

/// Filters resolver-supplied HTTP headers down to what is safe to emit.
///
/// The policy lives here, at the one point every SSR response crosses,
/// not at the caller — the same principle as the tag and attribute
/// policy in the renderer. A `SeoDocument.headers` value comes
/// (eventually) from a CMS, so it is a fresh path from untrusted data
/// into the response.
///
///  * The names are an **allow list**, not a block list. This package
///    has learned that lesson five times over — URL schemes, HTML tags,
///    CSS properties — and it held here too: a block list of the
///    obvious protocol headers still let `set-cookie` through (session
///    fixation) and `content-encoding` (claiming gzip over an
///    uncompressed body, corrupting the page). CORS, CSP and HSTS would
///    have been the next omissions. What a crawler-facing mirror
///    legitimately needs is a short, closed set: caching validators,
///    `x-robots-tag`, `link` and `content-language`.
///  * A name or value containing any control character is dropped
///    whole. CR and LF are the response-splitting vector, but the guard
///    rejects every control char (`< 0x20` or `0x7F`) — the same rigor
///    the renderer applies to URLs, so safety never depends on how a
///    particular shelf adapter treats a stray NUL, vertical tab or
///    U+2028.
///  * `vary` is **merged** with `User-Agent`, never replaced — the CDN
///    correctness of this middleware rests on `vary: User-Agent`, and a
///    resolver that also varies on `Accept-Language` must add to it, not
///    overwrite it.
Map<String, String> _safeHeaders(Map<String, String> headers) {
  final safe = <String, String>{};
  final vary = <String>{'User-Agent'};
  headers.forEach((rawName, value) {
    final name = rawName.trim().toLowerCase();
    if (!_validHeaderName.hasMatch(name) ||
        !_validHeaderValue.hasMatch(value)) {
      return;
    }
    if (name.isEmpty) return;
    if (name != 'vary' && !_allowedResolverHeaders.contains(name)) return;
    if (name == 'vary') {
      for (final part in value.split(',')) {
        final trimmed = part.trim();
        if (trimmed.isNotEmpty) vary.add(trimmed);
      }
      return;
    }
    safe[name] = value;
  });
  safe['vary'] = vary.join(', ');
  return safe;
}

/// The response headers a resolver may set, beyond `vary` (which is
/// merged rather than replaced).
///
/// Everything a crawler-facing page legitimately needs and nothing
/// else. Notably absent, each for a reason: `content-type`,
/// `content-length`, `transfer-encoding` and `connection` belong to the
/// package and the adapter; `location` is expressible only as a
/// [SeoRedirect], which is validated; `set-cookie` has no business on a
/// mirror and would be session fixation; `content-encoding` would claim
/// an encoding the body does not have; `access-control-*`,
/// `content-security-policy` and `strict-transport-security` are
/// site-wide security posture and must not be decided per page by
/// content.
const Set<String> _allowedResolverHeaders = {
  // Caching and validators.
  'cache-control',
  'expires',
  'etag',
  'last-modified',
  'age',
  // SEO-relevant.
  'x-robots-tag',
  'link',
  'content-language',
};

/// A valid HTTP field name (RFC 9110 token). Rejects spaces, colons,
/// separators and anything non-ASCII.
final RegExp _validHeaderName = RegExp(r"^[!#$%&'*+\-.^_`|~0-9a-z]+$");

/// A valid HTTP field value: printable US-ASCII plus horizontal tab.
///
/// Deliberately stricter than "no CR/LF". Header text is transmitted as
/// bytes, so a non-ASCII rune has no defined encoding here — an earlier
/// version allowed U+2028 on the grounds that it cannot split a
/// response, which was true and beside the point: over a real socket
/// `shelf_io` rejects it and the request hangs instead of answering.
/// A CMS-supplied header must never be able to take a page down, so the
/// value is held to what HTTP can actually carry.
final RegExp _validHeaderValue = RegExp(r'^[\x20-\x7E\t]*$');

/// What this middleware answers depends on the User-Agent. Without
/// saying so, a CDN caches whichever variant it saw first and serves it
/// to everyone — the bot HTML to real visitors, or the empty Flutter
/// shell to Google. Both branches must carry it, not just the SSR one.
const Map<String, String> _varyHeader = {'vary': 'User-Agent'};

/// The app response, marked as User-Agent dependent.
///
/// The header is merged, not replaced: an inner handler may already
/// vary on `Origin` or `Accept-Encoding`, and dropping those would make
/// a CDN serve the wrong compression or the wrong origin's response.
Future<Response> _appResponse(Handler inner, Request request) async {
  final response = await inner(request);
  final existing = response.headersAll['vary'] ?? const <String>[];
  final values = <String>{
    for (final entry in existing)
      for (final part in entry.split(',')) part.trim(),
  }..removeWhere((v) => v.isEmpty);
  if (values.contains('*')) return response;
  values.add('User-Agent');
  return response.change(headers: {
    ...response.headersAll,
    'vary': values.join(', '),
  });
}

/// Asset requests (`/main.dart.js`, `/favicon.png`) carry a file
/// extension in their last segment — everything else is a page path.
bool _looksLikePage(String path) => !path.split('/').last.contains('.');

/// A title for an error page whose resolver supplied none.
String _statusTitle(int status) => switch (status) {
      404 => '404 — Page not found',
      410 => '410 — Gone',
      _ => '$status — Error',
    };

/// The fallback body for an error page whose resolver supplied none.
List<SeoNode> _statusBody(int status) =>
    [SeoNode(tag: 'h1', text: _statusTitle(status))];

SeoPage _notFoundPage() => SeoPage(
      meta: const SeoMeta(title: '404 — Page not found', robots: 'noindex'),
      bodyHtml: '<h1>404 — Page not found</h1>',
    );
