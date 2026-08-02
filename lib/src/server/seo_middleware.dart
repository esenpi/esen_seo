import 'dart:async';

import 'package:shelf/shelf.dart';

import '../meta/seo_meta.dart';
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
  return (Handler inner) {
    // A fully static table cannot change, so its infrastructure files are
    // built once and served from cache forever — byte-identical to
    // before the resolver existed. A dynamic table resolves fresh on
    // each request; TTL caching for it lands in 0.7.
    String? sitemapCache;
    String? robotsCache;
    String? llmsCache;
    Future<String>? llmsFullCache;

    // Until then, at least never resolve the same file twice at once: a
    // crawler opening /sitemap.xml twenty times in parallel would
    // otherwise start twenty full passes over the database. Concurrent
    // callers share the one in-flight pass; the slot frees as soon as it
    // completes, so this collapses a stampede without caching anything.
    final inFlight = <String, Future<String>>{};
    Future<String> once(String key, Future<String> Function() build) =>
        inFlight[key] ??= Future(() async {
          try {
            return await build();
          } finally {
            inFlight.remove(key);
          }
        });

    void report(String p, Object e, StackTrace s) =>
        onResolveError?.call(p, e, s);

    return (Request request) async {
      final path = normalizeSeoPath(request.url.path);

      // Infrastruktur-Dateien — für alle Clients, nicht nur Bots.
      if (siteBase != null) {
        if (serveSitemap && routes != null && path == '/sitemap.xml') {
          final xml = needsAsyncResolution
              ? await once(
                  '/sitemap.xml',
                  () async => seoSitemapXml(
                    siteBase: siteBase,
                    pages: await resolveSeoPages(
                      routes: routes,
                      canonicalBase: siteBase,
                      additionalPaths: additionalSitemapPaths,
                      detail: SeoDetail.head,
                      onError: report,
                    ),
                  ),
                )
              : (sitemapCache ??= seoSitemapXml(
                  routes: routes,
                  siteBase: siteBase,
                  additionalPaths: additionalSitemapPaths,
                ));
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
          final txt = needsAsyncResolution
              ? await once(
                  '/llms.txt',
                  () async => seoLlmsTxt(
                    siteBase: siteBase,
                    pages: await resolveSeoPages(
                      routes: routes,
                      canonicalBase: siteBase,
                      additionalPaths: additionalSitemapPaths,
                      detail: SeoDetail.head,
                      onError: report,
                    ),
                  ),
                )
              : (llmsCache ??= seoLlmsTxt(
                  routes: routes,
                  siteBase: siteBase,
                  additionalPaths: additionalSitemapPaths,
                ));
          return Response.ok(
            txt,
            headers: {'content-type': 'text/plain; charset=utf-8'},
          );
        }
        if (serveLlmsTxt && routes != null && path == '/llms-full.txt') {
          // A dynamic table resolves fresh; a static one caches the
          // Future (not the value) so concurrent first requests render
          // the whole site only once.
          final Future<String> txt;
          if (needsAsyncResolution) {
            txt = once(
              '/llms-full.txt',
              () async => seoLlmsFullTxt(
                siteBase: siteBase,
                pages: await resolveSeoPages(
                  routes: routes,
                  canonicalBase: siteBase,
                  additionalPaths: additionalSitemapPaths,
                  detail: SeoDetail.full,
                  onError: report,
                ),
              ),
            );
          } else {
            txt = llmsFullCache ??= seoLlmsFullTxt(
              routes: routes,
              siteBase: siteBase,
              additionalPaths: additionalSitemapPaths,
            );
          }
          return Response.ok(
            await txt,
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

      if (!detector.isBot(request.headers['user-agent'])) {
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
              // A redirect is served to bots. Applying it to human
              // visitors as well (the anti-cloaking default) lands with
              // the rest of the HTTP surface in 0.7.
              return Response(
                statusCode,
                headers: {'location': location, ..._varyHeader},
              );
            case SeoDocument(:final statusCode, :final body, :final meta)
                when statusCode >= 400:
              // A real error status with the document's own body, or the
              // built-in 404 page when it carries none.
              return body.isEmpty
                  ? _htmlResponse(_notFoundPage(), status: statusCode)
                  : _htmlResponse(
                      SeoPage.fromNodes(
                        meta: meta,
                        body: body,
                        lang: resolution.lang ?? match.route.lang,
                      ),
                      status: statusCode,
                    );
            case SeoDocument(:final body, :final meta):
              // A 200 with nothing to mirror falls through to the app —
              // an empty SSR page indexes worse than the Flutter shell.
              if (body.isNotEmpty) {
                return _htmlResponse(SeoPage.fromNodes(
                  meta: meta,
                  body: body,
                  lang: resolution.lang ?? match.route.lang,
                ));
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

Response _htmlResponse(SeoPage page, {int status = 200}) => Response(
      status,
      body: page.toHtmlDocument(),
      headers: {
        'content-type': 'text/html; charset=utf-8',
        // Kennzeichnet SSR-Antworten, z.B. zum Debuggen mit curl.
        'x-esen-seo': 'ssr',
        ..._varyHeader,
      },
    );

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

SeoPage _notFoundPage() => SeoPage(
      meta: const SeoMeta(title: '404 — Page not found', robots: 'noindex'),
      bodyHtml: '<h1>404 — Page not found</h1>',
    );
