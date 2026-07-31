import 'dart:async';

import '../meta/seo_meta.dart';
import '../renderer/seo_node.dart';

/// Builds the [SeoMeta] for a matched route.
///
/// [params] contains the values of `:param` segments, e.g. for the
/// route `/blog/:slug` and the URL `/blog/hallo` it is `{slug: hallo}`.
typedef SeoMetaBuilder = SeoMeta Function(Map<String, String> params);

/// Builds the semantic HTML body for a matched route — used by the SSR
/// server. May be asynchronous (e.g. to load content from a database).
typedef SeoBodyBuilder = FutureOr<List<SeoNode>> Function(
  Map<String, String> params,
);

/// One entry in the SEO route table — the single source of truth for a
/// page's URL, metadata and (server-side) body.
///
/// Define the table once in a pure-Dart file without Flutter imports;
/// then both worlds read it:
///
/// - the Flutter app applies the metadata automatically on navigation
///   through a `SeoRouteObserver`,
/// - the shelf server serves bots the full HTML document via
///   `seoBotMiddleware(routes: ...)` — including sitemap.xml and real
///   404 responses for unknown paths.
///
/// ```dart
/// final seoRoutes = [
///   SeoRoute(
///     path: '/',
///     meta: (_) => SeoMeta(title: 'Home'),
///     body: (_) => [SeoNode(tag: 'h1', text: 'Willkommen')],
///   ),
///   SeoRoute(
///     path: '/blog/:slug',
///     meta: (params) => SeoMeta(title: 'Blog — ${params['slug']}'),
///   ),
/// ];
/// ```
class SeoRoute {
  SeoRoute({
    required String path,
    required this.meta,
    this.body,
    this.lang = 'en',
    this.includeInSitemap = true,
    this.lastModified,
  }) : path = normalizeSeoPath(path);

  /// The URL path pattern, e.g. `/` or `/blog/:slug`.
  /// Segments starting with `:` capture the value as a parameter.
  final String path;

  /// Builds the page metadata for this route.
  final SeoMetaBuilder meta;

  /// Builds the semantic HTML body for the SSR server. Optional — the
  /// client-side observer only uses [meta].
  final SeoBodyBuilder? body;

  /// The `lang` attribute of the server-rendered document, e.g. `de`.
  final String lang;

  /// Whether this route appears in the generated sitemap.xml.
  /// Routes with `:param` segments are always skipped (their concrete
  /// URLs cannot be enumerated from the pattern).
  final bool includeInSitemap;

  /// When the page content was last changed — rendered as `<lastmod>`
  /// in the generated sitemap.xml (search engines use it to prioritize
  /// recrawls).
  final DateTime? lastModified;

  /// Die Pattern-Segmente, einmal beim Anlegen der Route berechnet.
  late final List<String> _segments = path.split('/');

  /// Whether the pattern contains `:param` segments.
  late final bool hasParams = _segments.any((s) => s.startsWith(':'));

  /// Matches [requestPath] against the pattern. Returns the captured
  /// parameters (possibly empty) or `null` when the path does not match.
  Map<String, String>? match(String requestPath) =>
      _matchNormalized(normalizeSeoPath(requestPath));

  Map<String, String>? _matchNormalized(String normalized) {
    final pattern = _segments;
    final actual = normalized.split('/');
    if (pattern.length != actual.length) return null;

    final params = <String, String>{};
    for (var i = 0; i < pattern.length; i++) {
      final segment = pattern[i];
      if (segment.startsWith(':')) {
        if (actual[i].isEmpty) return null;
        params[segment.substring(1)] = actual[i];
      } else if (segment != actual[i]) {
        return null;
      }
    }
    return params;
  }
}

/// A successful lookup in the route table.
class SeoRouteMatch {
  SeoRouteMatch(
      {required this.route, required this.params, required this.path});

  /// The matched route definition.
  final SeoRoute route;

  /// Captured `:param` values.
  final Map<String, String> params;

  /// The normalized request path that matched, e.g. `/blog/hallo`.
  final String path;

  /// Builds the metadata; when the route sets no [SeoMeta.canonicalUrl]
  /// and [canonicalBase] is given, the canonical URL is derived
  /// automatically from base + matched path.
  SeoMeta buildMeta({String? canonicalBase}) {
    final meta = route.meta(params);
    if (meta.canonicalUrl != null || canonicalBase == null) return meta;
    final base = _stripTrailingSlash(canonicalBase);
    return meta.copyWith(canonicalUrl: path == '/' ? '$base/' : '$base$path');
  }

  /// Builds the server-side body; empty when the route has no builder.
  FutureOr<List<SeoNode>> buildBody() =>
      route.body?.call(params) ?? <SeoNode>[];
}

/// Finds the first route in [routes] matching [path], or `null`.
SeoRouteMatch? matchSeoRoute(List<SeoRoute> routes, String path) {
  final normalized = normalizeSeoPath(path);
  for (final route in routes) {
    final params = route._matchNormalized(normalized);
    if (params != null) {
      return SeoRouteMatch(route: route, params: params, path: normalized);
    }
  }
  return null;
}

/// Normalizes a path: leading slash, no trailing slash, `''` → `/`.
String normalizeSeoPath(String path) {
  var p = path.trim();
  if (p.isEmpty) return '/';
  if (!p.startsWith('/')) p = '/$p';
  while (p.length > 1 && p.endsWith('/')) {
    p = p.substring(0, p.length - 1);
  }
  return p;
}

String _stripTrailingSlash(String url) =>
    url.endsWith('/') ? url.substring(0, url.length - 1) : url;
