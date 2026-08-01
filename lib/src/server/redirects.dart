import 'package:shelf/shelf.dart';

import '../routing/seo_route.dart';

/// Shelf middleware for SEO-relevant 301 redirects — duplicate content
/// under several URLs splits ranking signals, one canonical URL per
/// page collects them.
///
/// ```dart
/// final handler = const Pipeline()
///     .addMiddleware(seoRedirectMiddleware(
///       canonicalHost: 'esen.software',        // www.… → esen.software
///       forceHttps: true,                      // http → https
///       redirects: {'/alte-seite': '/neue-seite'},
///     ))
///     .addMiddleware(seoBotMiddleware(...))
///     .addHandler(...);
/// ```
///
/// - [canonicalHost]: every other host (e.g. `www.`-variant) is
///   redirected to this one, path and query preserved.
/// - [forceHttps]: redirects `http` to `https`. Behind a reverse proxy
///   the original scheme is read from the `x-forwarded-proto` header.
/// - [stripTrailingSlashes]: `/demo/` → `/demo` (the root `/` stays).
/// - [redirects]: exact path mappings, e.g. after a relaunch. Values
///   may be paths (`/neu`) or absolute URLs (`https://…`).
Middleware seoRedirectMiddleware({
  String? canonicalHost,
  bool forceHttps = false,
  bool stripTrailingSlashes = true,
  Map<String, String> redirects = const {},
}) {
  final normalizedRedirects = {
    for (final entry in redirects.entries)
      normalizeSeoPath(entry.key): entry.value,
  };
  return (Handler inner) {
    return (Request request) {
      final uri = request.requestedUri;

      final mapped = normalizedRedirects[normalizeSeoPath(uri.path)];
      if (mapped != null && mapped.startsWith('http')) {
        return Response.movedPermanently(mapped);
      }

      // Der Header kommt vom Proxy, ist aber fälschbar — und ein
      // ungültiger Wert landete sonst in Uri(scheme:), was die Anfrage
      // mit einem 500 abbricht.
      final forwarded =
          request.headers['x-forwarded-proto']?.trim().toLowerCase();
      var scheme = (forwarded == 'http' || forwarded == 'https')
          ? forwarded!
          : uri.scheme;
      var host = uri.host;
      var path = mapped ?? uri.path;
      var changed = mapped != null;

      if (forceHttps && scheme != 'https') {
        scheme = 'https';
        changed = true;
      }
      if (canonicalHost != null && host != canonicalHost) {
        host = canonicalHost;
        changed = true;
      }
      if (stripTrailingSlashes && path.length > 1 && path.endsWith('/')) {
        path = normalizeSeoPath(path);
        changed = true;
      }
      if (!changed) return inner(request);

      final isDefaultPort = uri.port == 80 || uri.port == 443;
      final location = Uri(
        scheme: scheme,
        host: host,
        port: isDefaultPort ? null : uri.port,
        path: path,
        query: uri.hasQuery ? uri.query : null,
      );
      return Response.movedPermanently(location.toString());
    };
  };
}
