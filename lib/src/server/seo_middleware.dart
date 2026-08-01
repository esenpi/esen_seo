import 'dart:async';

import 'package:shelf/shelf.dart';

import '../meta/seo_meta.dart';
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
}) {
  assert(
    routes != null || resolve != null,
    'seoBotMiddleware needs `routes` and/or `resolve`.',
  );
  return (Handler inner) {
    // Sitemap, robots.txt und llms.txt sind pro Konfiguration statisch —
    // einmal bauen, danach aus dem Cache ausliefern.
    String? sitemapCache;
    String? robotsCache;
    String? llmsCache;
    Future<String>? llmsFullCache;
    return (Request request) async {
      final path = normalizeSeoPath(request.url.path);

      // Infrastruktur-Dateien — für alle Clients, nicht nur Bots.
      if (siteBase != null) {
        if (serveSitemap && routes != null && path == '/sitemap.xml') {
          sitemapCache ??= seoSitemapXml(
            routes: routes,
            siteBase: siteBase,
            additionalPaths: additionalSitemapPaths,
          );
          return Response.ok(
            sitemapCache,
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
          llmsCache ??= seoLlmsTxt(
            routes: routes,
            siteBase: siteBase,
            additionalPaths: additionalSitemapPaths,
          );
          return Response.ok(
            llmsCache,
            headers: {'content-type': 'text/plain; charset=utf-8'},
          );
        }
        if (serveLlmsTxt && routes != null && path == '/llms-full.txt') {
          // Das Future cachen, nicht den Wert: Zwischen Prüfung und
          // Zuweisung liegt ein await, sonst rendert jede parallele
          // Anfrage die komplette Seite ein weiteres Mal.
          llmsFullCache ??= seoLlmsFullTxt(
            routes: routes,
            siteBase: siteBase,
            additionalPaths: additionalSitemapPaths,
          );
          return Response.ok(
            await llmsFullCache,
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
        return inner(request);
      }

      if (routes != null) {
        final match = matchSeoRoute(routes, path);
        if (match != null) {
          final page = SeoPage.fromNodes(
            meta: match.buildMeta(canonicalBase: siteBase),
            body: await match.buildBody(),
            lang: match.route.lang,
          );
          return _htmlResponse(page);
        }
      }

      if (resolve != null) {
        final page = await resolve(request);
        if (page != null) return _htmlResponse(page);
      }

      // Soft-404 vermeiden: unbekannte seiten-artige Pfade bekommen für
      // Bots einen echten 404 statt der Flutter-App mit Status 200.
      if (routes != null && unknownRoutesAs404 && _looksLikePage(path)) {
        return _htmlResponse(_notFoundPage(), status: 404);
      }

      return inner(request);
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
      },
    );

/// Asset requests (`/main.dart.js`, `/favicon.png`) carry a file
/// extension in their last segment — everything else is a page path.
bool _looksLikePage(String path) => !path.split('/').last.contains('.');

SeoPage _notFoundPage() => SeoPage(
      meta: const SeoMeta(title: '404 — Page not found', robots: 'noindex'),
      bodyHtml: '<h1>404 — Page not found</h1>',
    );
