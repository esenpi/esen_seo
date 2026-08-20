// The `meta` and `body` fields are deprecated for external callers, but
// this file must still store and read them to keep the convenience
// constructor and the deprecated buildMeta/buildBody working.
// ignore_for_file: deprecated_member_use_from_same_package

import 'dart:async';

import '../meta/seo_meta.dart';
import '../renderer/seo_node.dart';
import 'seo_application_runtime.dart';
import 'seo_resolution.dart';
import 'seo_route_delivery.dart';

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

/// Produces the [SeoResolution] for one concrete URL — metadata and
/// body from a single read. The content source of a [SeoRoute.dynamic].
typedef SeoResolver = FutureOr<SeoResolution> Function(SeoRequest request);

/// Lists every concrete URL a `:param` route stands for, so the sitemap,
/// llms.txt and the prerenderer can enumerate a pattern route. For
/// `/products/:slug` it returns the actual product paths.
typedef SeoPathEnumerator = FutureOr<List<String>> Function();

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
  /// The convenience form: metadata from a synchronous builder, body
  /// from an optional (possibly async) builder.
  ///
  /// The signature is unchanged from before the resolver existed, except
  /// for the optional [enumeratePaths]. Internally the two builders are
  /// wrapped into a [resolve] so there is only ever one content source —
  /// see [SeoRoute.dynamic] for the form that reads both from one place.
  SeoRoute({
    required String path,
    required SeoMetaBuilder this.meta,
    this.body,
    this.enumeratePaths,
    this.lang = 'en',
    this.includeInSitemap = true,
    this.lastModified,
    this.delivery = SeoRouteDelivery.flutter,
    Set<SeoDomFirstFeature> domFirstFeatures = const {},
    SeoDomFirstApplicationRuntime? applicationRuntime,
  })  : path = _validatedSeoRoutePath(path),
        isDynamic = false,
        resolve = _staticResolver(meta, body),
        domFirstFeatures = _validatedDomFirstFeatures(
          delivery,
          domFirstFeatures,
        ),
        applicationRuntime = _validatedApplicationRuntime(
          delivery,
          domFirstFeatures,
          applicationRuntime,
        );

  /// The database form: one [resolve] read produces metadata **and**
  /// body for a concrete URL, so the two can never describe different
  /// records.
  ///
  /// ```dart
  /// SeoRoute.dynamic(
  ///   path: '/products/:slug',
  ///   enumeratePaths: () async =>
  ///       (await db.publishedSlugs()).map((s) => '/products/$s').toList(),
  ///   resolve: (r) async {
  ///     final p = await db.product(r.param('slug'));
  ///     if (p == null) return const SeoDocument.notFound();
  ///     return SeoDocument(
  ///       meta: SeoMeta(title: p.name, description: p.teaser),
  ///       body: r.detail == SeoDetail.head ? const [] : p.toSeoNodes(),
  ///       lastModified: p.updatedAt,
  ///     );
  ///   },
  /// );
  /// ```
  SeoRoute.dynamic({
    required String path,
    required this.resolve,
    this.enumeratePaths,
    this.lang = 'en',
    this.includeInSitemap = true,
    this.lastModified,
    this.delivery = SeoRouteDelivery.flutter,
    Set<SeoDomFirstFeature> domFirstFeatures = const {},
    SeoDomFirstApplicationRuntime? applicationRuntime,
  })  : path = _validatedSeoRoutePath(path),
        meta = null,
        body = null,
        isDynamic = true,
        domFirstFeatures = _validatedDomFirstFeatures(
          delivery,
          domFirstFeatures,
        ),
        applicationRuntime = _validatedApplicationRuntime(
          delivery,
          domFirstFeatures,
          applicationRuntime,
        );

  /// The URL path pattern, e.g. `/` or `/blog/:slug`.
  /// Segments starting with `:` capture the value as a parameter.
  final String path;

  /// The single content source for this route. For [SeoRoute.new] it is
  /// synthesized from [meta] and [body]; for [SeoRoute.dynamic] it is
  /// supplied directly.
  final SeoResolver resolve;

  /// Whether this route was created with [SeoRoute.dynamic]. Consumers
  /// never branch on it for content — [resolve] is uniform — but the
  /// synchronous generators use it to refuse a table they cannot resolve
  /// without awaiting.
  final bool isDynamic;

  /// Which presentation owns this route for human web requests.
  ///
  /// The default preserves the existing Flutter delivery byte for byte.
  final SeoRouteDelivery delivery;

  /// Package-owned browser behaviour enabled for a DOM-first route.
  ///
  /// Features are rejected on Flutter-delivered routes instead of being
  /// silently ignored, so a misplaced opt-in cannot appear to work.
  final Set<SeoDomFirstFeature> domFirstFeatures;

  /// Application-authored pure logic compiled for this DOM-first route.
  ///
  /// Only the typed identity is stored here. Server delivery must resolve and
  /// verify its separate build artifact before writing any JavaScript.
  final SeoDomFirstApplicationRuntime? applicationRuntime;

  /// Whether the semantic document permanently owns the web route.
  bool get isDomFirst => delivery == SeoRouteDelivery.domFirst;

  /// Lists the concrete URLs of a `:param` route for enumeration
  /// (sitemap, llms.txt, prerender). Optional; without it a `:param`
  /// route contributes no concrete URLs on its own.
  final SeoPathEnumerator? enumeratePaths;

  /// Builds the page metadata for this route.
  ///
  /// Non-null only for the convenience [SeoRoute.new]; `null` for
  /// [SeoRoute.dynamic], which has no separate meta closure.
  @Deprecated('Convenience form only; null for SeoRoute.dynamic. '
      'Use matchSeoRoute(...).resolveSync()?.metaOrNull. Removed in 1.0.')
  final SeoMetaBuilder? meta;

  /// Builds the semantic HTML body for the SSR server. Optional — the
  /// client-side observer only uses metadata.
  ///
  /// Non-null only for the convenience [SeoRoute.new]; `null` for
  /// [SeoRoute.dynamic].
  @Deprecated('Convenience form only; null for SeoRoute.dynamic. '
      'Use resolve(SeoRequest(detail: SeoDetail.full)). Removed in 1.0.')
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
    final actual = _decodedPathSegments(normalized);
    if (pattern.length != actual.length) return null;

    final params = <String, String>{};
    for (var i = 0; i < pattern.length; i++) {
      final segment = pattern[i];
      if (segment.startsWith(':')) {
        if (actual[i].isEmpty) return null;
        params[segment.substring(1)] = actual[i];
      } else if (_decodePathSegment(segment) != actual[i]) {
        return null;
      }
    }
    return params;
  }
}

Set<SeoDomFirstFeature> _validatedDomFirstFeatures(
  SeoRouteDelivery delivery,
  Set<SeoDomFirstFeature> features,
) {
  if (delivery != SeoRouteDelivery.domFirst && features.isNotEmpty) {
    throw ArgumentError.value(
      features,
      'domFirstFeatures',
      'require delivery: SeoRouteDelivery.domFirst',
    );
  }
  return Set<SeoDomFirstFeature>.unmodifiable(features);
}

SeoDomFirstApplicationRuntime? _validatedApplicationRuntime(
  SeoRouteDelivery delivery,
  Set<SeoDomFirstFeature> features,
  SeoDomFirstApplicationRuntime? runtime,
) {
  if (runtime == null) return null;
  if (delivery != SeoRouteDelivery.domFirst) {
    throw ArgumentError.value(
      runtime,
      'applicationRuntime',
      'requires delivery: SeoRouteDelivery.domFirst',
    );
  }
  if (!isValidSeoApplicationRuntimeId(runtime.id)) {
    throw ArgumentError.value(
      runtime.id,
      'applicationRuntime',
      'must start with a lowercase letter and contain at most 64 lowercase '
          'letters, digits, underscores or dashes',
    );
  }
  if (runtime is SeoDomFirstTabsApplicationRuntime &&
      features.contains(SeoDomFirstFeature.tabs)) {
    throw ArgumentError.value(
      runtime,
      'applicationRuntime',
      'cannot be combined with the package-owned tabs runtime',
    );
  }
  if (runtime is SeoDomFirstCarouselApplicationRuntime &&
      features.contains(SeoDomFirstFeature.carousel)) {
    throw ArgumentError.value(
      runtime,
      'applicationRuntime',
      'cannot be combined with the package-owned carousel runtime',
    );
  }
  if (runtime is SeoDomFirstCollectionApplicationRuntime &&
      features.contains(SeoDomFirstFeature.collection)) {
    throw ArgumentError.value(
      runtime,
      'applicationRuntime',
      'cannot be combined with the package-owned collection runtime',
    );
  }
  if ((runtime is SeoDomFirstStepperApplicationRuntime ||
          runtime is SeoDomFirstStepperEffectsApplicationRuntime) &&
      features.contains(SeoDomFirstFeature.stepper)) {
    throw ArgumentError.value(
      runtime,
      'applicationRuntime',
      'cannot be combined with the package-owned stepper runtime',
    );
  }
  return runtime;
}

/// Wraps the convenience [SeoRoute]'s two builders into a single
/// resolver, so the whole package has exactly one content source.
///
/// The `head` branch is **synchronous even when [body] is async** — it
/// never touches the body builder. That single property keeps
/// `seoSitemapXml`, `seoLlmsTxt` and the Flutter observer synchronous
/// for every route table written before the resolver existed.
SeoResolver _staticResolver(SeoMetaBuilder meta, SeoBodyBuilder? body) =>
    (SeoRequest request) {
      final resolvedMeta = meta(request.params);
      if (body == null || request.detail == SeoDetail.head) {
        return SeoDocument(meta: resolvedMeta);
      }
      final built = body(request.params);
      if (built is List<SeoNode>) {
        return SeoDocument(meta: resolvedMeta, body: built);
      }
      return built
          .then((nodes) => SeoDocument(meta: resolvedMeta, body: nodes));
    };

/// A successful lookup in the route table.
///
/// A match is a **per-request** object. It memoizes the resolver's
/// output so one URL is read once, which means holding a match across
/// requests would serve stale content — never do that.
class SeoRouteMatch {
  SeoRouteMatch(
      {required this.route, required this.params, required this.path});

  /// The matched route definition.
  final SeoRoute route;

  /// Captured `:param` values.
  final Map<String, String> params;

  /// The normalized request path that matched, e.g. `/blog/hallo`.
  final String path;

  // The raw resolver output, memoized per detail. `head` and `full` are
  // kept apart on purpose: a resolver may legitimately skip the body for
  // `head`, so a `full` request must never be served a `head` result.
  // The cheap, pure finishing step runs on every call, so the actual
  // canonicalBase always applies even though the read is cached.
  FutureOr<SeoResolution>? _headRaw;
  FutureOr<SeoResolution>? _fullRaw;

  /// Resolves this URL to a [SeoDocument] or [SeoRedirect].
  ///
  /// Returns the value directly (no microtask) when the route resolves
  /// synchronously — which every convenience route does for
  /// [SeoDetail.head]; `await` works either way. The result is always
  /// run through [finishSeoResolution] (canonical derivation, redirect
  /// URL policy).
  FutureOr<SeoResolution> resolve({
    SeoDetail detail = SeoDetail.full,
    String? canonicalBase,
    String? siteBase,
    void Function(String path, String warning)? onWarning,
  }) {
    var raw = detail == SeoDetail.head ? _headRaw : _fullRaw;
    if (raw == null) {
      raw = route.resolve(SeoRequest(
        path: path,
        params: params,
        detail: detail,
        siteBase: siteBase ?? canonicalBase,
      ));
      if (detail == SeoDetail.head) {
        _headRaw = raw;
      } else {
        _fullRaw = raw;
      }
    }
    SeoResolution finish(SeoResolution r) => finishSeoResolution(
          r,
          path: path,
          canonicalBase: canonicalBase,
          onWarning: onWarning,
        );
    return raw is SeoResolution ? finish(raw) : raw.then(finish);
  }

  /// The resolution when it is available without awaiting, else `null`.
  ///
  /// A convenience route always answers [SeoDetail.head] here. A
  /// [SeoRoute.dynamic] answers only if its resolver happens to be
  /// synchronous — [SeoResolver] is a `FutureOr`, so that is allowed,
  /// and the database-backed case this constructor exists for is not.
  /// Callers that must not block on I/O should therefore treat `null`
  /// as the normal answer for a dynamic route rather than the
  /// exception.
  SeoResolution? resolveSync({
    SeoDetail detail = SeoDetail.head,
    String? canonicalBase,
  }) {
    final r = resolve(detail: detail, canonicalBase: canonicalBase);
    return r is SeoResolution ? r : null;
  }

  /// Builds the metadata; when the route sets no [SeoMeta.canonicalUrl]
  /// and [canonicalBase] is given, the canonical URL is derived
  /// automatically from base + matched path.
  @Deprecated('Use resolveSync()/resolve(). Throws for SeoRoute.dynamic. '
      'Removed in 1.0.')
  SeoMeta buildMeta({String? canonicalBase}) {
    if (route.isDynamic) {
      throw StateError(
        'buildMeta() cannot resolve a SeoRoute.dynamic ("${route.path}") '
        'synchronously. Use resolve(detail: SeoDetail.head).',
      );
    }
    final resolved =
        resolveSync(detail: SeoDetail.head, canonicalBase: canonicalBase);
    // A convenience route always resolves synchronously to a document.
    return (resolved as SeoDocument).meta;
  }

  /// Builds the server-side body; empty when the route has no builder or
  /// resolves to a redirect.
  @Deprecated('Use resolve(detail: SeoDetail.full). Removed in 1.0.')
  FutureOr<List<SeoNode>> buildBody() {
    final r = resolve(detail: SeoDetail.full);
    return r is SeoResolution ? _bodyOf(r) : r.then(_bodyOf);
  }

  static List<SeoNode> _bodyOf(SeoResolution r) =>
      r is SeoDocument ? r.body : const <SeoNode>[];
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

/// Validates the part of a route declaration that is a pattern rather than a
/// request URL. Query strings and fragments never reach `Request.url.path`,
/// and duplicate parameter names would silently overwrite the earlier value.
String _validatedSeoRoutePath(String rawPath) {
  final path = normalizeSeoPath(rawPath);
  if (path == '/') return path;
  if (path.contains('?') || path.contains('#')) {
    throw ArgumentError.value(
      rawPath,
      'path',
      'must contain only a URL path, without query string or fragment',
    );
  }

  final names = <String>{};
  final segments = path.split('/');
  for (var i = 1; i < segments.length; i++) {
    final segment = segments[i];
    if (segment.isEmpty) {
      throw ArgumentError.value(
        rawPath,
        'path',
        'must not contain an empty path segment',
      );
    }
    if (!segment.startsWith(':')) continue;
    final name = segment.substring(1);
    if (name.isEmpty) {
      throw ArgumentError.value(
        rawPath,
        'path',
        'parameter segments need a name after ":"',
      );
    }
    if (!names.add(name)) {
      throw ArgumentError.value(
        rawPath,
        'path',
        'parameter name "$name" is declared more than once',
      );
    }
  }
  return path;
}

/// URI paths keep percent-escapes; route declarations generally use Unicode.
/// Decode after splitting so `%2F` remains part of one segment rather than
/// becoming a new route boundary. Captured params therefore contain the value
/// a resolver expects (`café`, or `a/b` for an encoded slash).
List<String> _decodedPathSegments(String path) => [
      for (final segment in path.split('/')) _decodePathSegment(segment),
    ];

String _decodePathSegment(String segment) {
  try {
    return Uri.decodeComponent(segment);
  } on FormatException {
    return segment;
  } on ArgumentError {
    return segment;
  }
}
