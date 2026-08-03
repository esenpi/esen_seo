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
///   the original scheme can be read from `x-forwarded-proto` by setting
///   [trustProxy]. Never enable that for requests arriving directly from
///   the internet: forwarding headers are caller-controlled there.
/// - [stripTrailingSlashes]: `/demo/` → `/demo` (the root `/` stays).
/// - [redirects]: exact path mappings, e.g. after a relaunch. Values
///   may be paths (`/neu`) or absolute URLs (`https://…`).
Middleware seoRedirectMiddleware({
  String? canonicalHost,
  bool forceHttps = false,
  bool trustProxy = false,
  bool stripTrailingSlashes = true,
  Map<String, String> redirects = const {},
}) {
  final normalizedRedirects = {
    for (final entry in redirects.entries)
      normalizeSeoPath(entry.key): _validatedRedirectTarget(entry.value),
  };
  return (Handler inner) {
    return (Request request) {
      final uri = request.requestedUri;

      final mapped = normalizedRedirects[normalizeSeoPath(uri.path)];
      if (mapped != null && mapped.hasScheme) {
        return Response.movedPermanently(mapped.toString());
      }

      final forwarded = trustProxy
          ? request.headers['x-forwarded-proto']?.trim().toLowerCase()
          : null;
      var scheme = (forwarded == 'http' || forwarded == 'https')
          ? forwarded!
          : uri.scheme;
      var host = uri.host;
      var path = mapped?.path ?? uri.path;
      final query = mapped?.hasQuery ?? false
          ? mapped!.query
          : (uri.hasQuery ? uri.query : null);
      final fragment = mapped?.hasFragment ?? false ? mapped!.fragment : null;
      var changed = mapped != null;
      var authorityChanged = false;

      if (forceHttps && scheme != 'https') {
        scheme = 'https';
        changed = true;
        authorityChanged = true;
      }
      if (canonicalHost != null && host != canonicalHost) {
        host = canonicalHost;
        changed = true;
        authorityChanged = true;
      }
      if (stripTrailingSlashes && path.length > 1 && path.endsWith('/')) {
        path = normalizeSeoPath(path);
        changed = true;
      }
      if (!changed) return inner(request);

      // A path-only redirect needs no authority. Keeping it relative avoids
      // reflecting a request-controlled Host header into Location.
      if (!authorityChanged) {
        return Response.movedPermanently(
          Uri(
            path: path,
            query: query,
            fragment: fragment,
          ).toString(),
        );
      }

      final isDefaultPort = uri.port == 80 || uri.port == 443;
      final location = Uri(
        scheme: scheme,
        host: host,
        port: isDefaultPort ? null : uri.port,
        path: path,
        query: query,
        fragment: fragment,
      );
      return Response.movedPermanently(location.toString());
    };
  };
}

Uri _validatedRedirectTarget(String rawTarget) {
  final target = Uri.tryParse(rawTarget);
  if (target == null) {
    throw ArgumentError.value(rawTarget, 'redirects', 'is not a valid URI');
  }
  if (target.hasScheme) {
    final scheme = target.scheme.toLowerCase();
    if ((scheme == 'http' || scheme == 'https') && target.host.isNotEmpty) {
      return target;
    }
    throw ArgumentError.value(
      rawTarget,
      'redirects',
      'absolute redirect targets need an http(s) scheme and host',
    );
  }
  if (target.hasAuthority || !target.path.startsWith('/')) {
    throw ArgumentError.value(
      rawTarget,
      'redirects',
      'relative redirect targets must be absolute paths starting with "/"',
    );
  }
  return target;
}
