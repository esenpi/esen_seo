import 'dart:async';

import 'seo_resolution.dart';
import 'seo_route.dart';

/// One concrete URL of the site, resolved exactly once.
///
/// The sitemap, llms.txt and the prerenderer all work from a list of
/// these, so a URL is read a single time no matter how many outputs it
/// feeds — and meta and body in every output describe the same record.
class SeoResolvedPage {
  const SeoResolvedPage({
    required this.path,
    required this.route,
    required this.params,
    required this.resolution,
    this.explicit = false,
  });

  /// The normalized URL path, e.g. `/products/roadbike`.
  final String path;

  /// The route that produced this page; `null` when an `additionalPaths`
  /// entry matched no route in the table.
  final SeoRoute? route;

  /// The captured `:param` values.
  final Map<String, String> params;

  /// What this URL resolved to.
  final SeoResolution resolution;

  /// Whether this path came from `additionalPaths` (or a caller's
  /// explicit list) rather than from a route or its enumerator.
  final bool explicit;

  /// The resolved document, or `null` when this URL is a redirect.
  SeoDocument? get document =>
      resolution is SeoDocument ? resolution as SeoDocument : null;

  /// The document language, falling back to the route, then `en`.
  String get lang => document?.lang ?? route?.lang ?? 'en';

  /// The last-modified date — a per-record value beats the route's
  /// static one.
  DateTime? get lastModified => document?.lastModified ?? route?.lastModified;

  /// Whether this URL may appear in sitemap.xml and llms.txt.
  ///
  /// A record wins over the route table: an unpublished or 410'd page
  /// leaves the index even when the route says `includeInSitemap: true`.
  /// A path passed **explicitly** is not filtered by the route's static
  /// flag — that preserves the existing behaviour where an explicit
  /// `additionalPaths` entry overrides an opted-out pattern route.
  bool get isIndexable {
    final doc = document;
    if (doc == null || doc.statusCode != 200) return false;
    if (doc.includeInSitemap == false) return false;
    if (!explicit && !(route?.includeInSitemap ?? true)) return false;
    return true;
  }
}

/// Enumerates every concrete URL the table stands for and resolves each
/// one **once**, asynchronously.
///
/// Sources, deduped by normalized path, in this order:
///   1. every route without `:param` segments,
///   2. each route's [SeoRoute.enumeratePaths] output (matched back
///      against the whole table, exactly like [additionalPaths]),
///   3. [additionalPaths] (marked [SeoResolvedPage.explicit]).
///
/// Routes with `includeInSitemap: false` **are** included here — the
/// generators filter, this pass does not — because the prerenderer
/// writes their HTML.
///
/// [onError] is the per-page failure policy. `null` (the default)
/// rethrows: a build that silently ships empty pages is worse than a
/// build that fails. The middleware passes a logger instead, because a
/// served sitemap that vanishes when one row is missing is worse than
/// one missing entry.
///
/// [detail] is passed to every resolver — [SeoDetail.head] for the
/// sitemap and short llms.txt (they need only metadata), [SeoDetail.full]
/// for the prerenderer and llms-full.txt.
///
/// [debugCheckMetaStability] resolves head **and** full for every path
/// and throws when the two produce different metadata — the one defence
/// against a resolver that quietly returns less for `head`. It costs a
/// second read per URL; use it in a test, never in a build.
Future<List<SeoResolvedPage>> resolveSeoPages({
  required List<SeoRoute> routes,
  String? canonicalBase,
  List<String> additionalPaths = const [],
  SeoDetail detail = SeoDetail.full,
  bool enumerateRoutePaths = true,
  int concurrency = 8,
  void Function(String path, Object error, StackTrace stack)? onError,
  void Function(String path, String warning)? onWarning,
  bool debugCheckMetaStability = false,
}) async {
  final targets = await _collectTargets(
    routes: routes,
    additionalPaths: additionalPaths,
    enumerateRoutePaths: enumerateRoutePaths,
    onError: onError,
  );

  final pages = List<SeoResolvedPage?>.filled(targets.length, null);
  var next = 0;

  Future<void> worker() async {
    while (true) {
      final index = next++;
      if (index >= targets.length) return;
      final target = targets[index];
      try {
        pages[index] = await _resolveTarget(
          target,
          canonicalBase: canonicalBase,
          detail: detail,
          onWarning: onWarning,
          debugCheckMetaStability: debugCheckMetaStability,
        );
      } catch (error, stack) {
        if (onError == null) rethrow;
        onError(target.path, error, stack);
      }
    }
  }

  final lanes = concurrency < 1 ? 1 : concurrency;
  await Future.wait([for (var i = 0; i < lanes; i++) worker()]);
  return [
    for (final page in pages)
      if (page != null) page
  ];
}

/// The synchronous engine behind the sync generators
/// ([seoSitemapXml], [seoLlmsTxt]).
///
/// Throws [StateError] when the table contains a [SeoRoute.dynamic], or
/// when a [SeoRoute.enumeratePaths] returns a `Future` — neither can be
/// resolved without awaiting.
List<SeoResolvedPage> resolveSeoPagesSync({
  required List<SeoRoute> routes,
  String? canonicalBase,
  List<String> additionalPaths = const [],
  SeoDetail detail = SeoDetail.head,
  bool enumerateRoutePaths = true,
}) {
  // Refuse up front, not per URL: a dynamic route cannot be resolved
  // without awaiting, and a sync sitemap that silently omits its pages is
  // the invisible SEO regression this package exists to prevent. Even a
  // `:param` dynamic route with no concrete instances yet means pages are
  // coming — fail loudly so the caller switches to the async pass.
  for (final route in routes) {
    if (route.isDynamic) {
      throw StateError(
        'A synchronous generator cannot resolve a SeoRoute.dynamic '
        '("${route.path}"). Resolve the table first: pass '
        'pages: await resolveSeoPages(routes: …, canonicalBase: …). '
        'seoBotMiddleware and prerenderSite do this for you.',
      );
    }
  }

  final collected = _collectTargets(
    routes: routes,
    additionalPaths: additionalPaths,
    enumerateRoutePaths: enumerateRoutePaths,
  );
  if (collected is! List<_Target>) {
    throw StateError(
      'A synchronous generator cannot await a SeoRoute.enumeratePaths that '
      'returns a Future. Resolve the table first: pass '
      'pages: await resolveSeoPages(routes: …, canonicalBase: …). '
      'seoBotMiddleware and prerenderSite do this for you.',
    );
  }

  return [
    for (final target in collected)
      _resolveTargetSync(
        target,
        canonicalBase: canonicalBase,
        detail: detail,
      ),
  ];
}

/// The shared front door of the synchronous generators
/// ([seoSitemapXml], [seoLlmsTxt]): resolve [routes], or validate and
/// return a pre-resolved [pages] snapshot.
///
/// Exactly one of [routes] and [pages] must be given; [additionalPaths]
/// may not accompany [pages], since they were already folded into the
/// pass that produced them.
List<SeoResolvedPage> pagesForGenerator({
  required String canonicalBase,
  List<SeoRoute>? routes,
  List<SeoResolvedPage>? pages,
  List<String> additionalPaths = const [],
  SeoDetail detail = SeoDetail.head,
}) {
  if ((routes == null) == (pages == null)) {
    throw ArgumentError('Pass exactly one of `routes:` or `pages:`.');
  }
  if (pages != null) {
    if (additionalPaths.isNotEmpty) {
      throw ArgumentError(
        '`additionalPaths` cannot be combined with `pages:` — fold them into '
        'resolveSeoPages(additionalPaths: …) instead.',
      );
    }
    return pages;
  }
  return resolveSeoPagesSync(
    routes: routes!,
    canonicalBase: canonicalBase,
    additionalPaths: additionalPaths,
    detail: detail,
  );
}

// One URL to resolve, paired with the route that owns it.
class _Target {
  _Target(this.path, this.match, this.explicit);
  final String path;
  final SeoRouteMatch? match;
  final bool explicit;
}

// Builds the deduped target list in a deterministic order: routes,
// then each route's enumerator (in table order), then additionalPaths.
//
// Returns the list directly when every enumerator answered
// synchronously — the sync generators require that — and a Future
// otherwise. The order must NOT depend on which enumerator completes
// first: `explicit` decides whether a route's `includeInSitemap` is
// honoured, so a URL changing hands between an enumerator and
// additionalPaths would silently move a page in or out of the sitemap.
FutureOr<List<_Target>> _collectTargets({
  required List<SeoRoute> routes,
  required List<String> additionalPaths,
  required bool enumerateRoutePaths,
  void Function(String path, Object error, StackTrace stack)? onError,
}) {
  // Gather the enumerator results in table order first, so awaiting can
  // never reshuffle them.
  final enumerated = <FutureOr<List<String>>>[];
  if (enumerateRoutePaths) {
    for (final route in routes) {
      final enumerate = route.enumeratePaths;
      if (enumerate == null) continue;
      try {
        final result = enumerate();
        // A database enumerator fails asynchronously, which is exactly
        // the case a plain try/catch around the CALL does not see: the
        // error would surface out of Future.wait below, past onError,
        // and take the whole pass with it.
        enumerated.add(result is List<String>
            ? result
            : () async {
                try {
                  return await result;
                } catch (error, stack) {
                  if (onError == null) rethrow;
                  onError(route.path, error, stack);
                  return <String>[];
                }
              }());
      } catch (error, stack) {
        if (onError == null) rethrow;
        onError(route.path, error, stack);
      }
    }
  }

  List<_Target> build(List<List<String>> enumeratedPaths) {
    final seen = <String>{};
    final targets = <_Target>[];
    void addPath(String rawPath, {required bool explicit}) {
      final path = normalizeSeoPath(rawPath);
      if (!seen.add(path)) return;
      targets.add(_Target(path, matchSeoRoute(routes, path), explicit));
    }

    for (final route in routes) {
      if (!route.hasParams) addPath(route.path, explicit: false);
    }
    for (final paths in enumeratedPaths) {
      for (final path in paths) {
        addPath(path, explicit: false);
      }
    }
    for (final path in additionalPaths) {
      addPath(path, explicit: true);
    }
    return targets;
  }

  if (enumerated.every((e) => e is List<String>)) {
    return build([for (final e in enumerated) e as List<String>]);
  }
  // Future.wait preserves the input order, so the result is the table
  // order regardless of completion order.
  return Future.wait(enumerated.map((e) async => e)).then(build);
}

Future<SeoResolvedPage> _resolveTarget(
  _Target target, {
  required String? canonicalBase,
  required SeoDetail detail,
  required void Function(String, String)? onWarning,
  required bool debugCheckMetaStability,
}) async {
  final match = target.match;
  final resolution = match == null
      // An explicitly listed path that matches no route has no metadata
      // to offer, but the caller asked for it — it stays in the sitemap
      // and llms.txt with the path as its title, as it always has.
      ? const SeoDocument()
      : await match.resolve(
          detail: detail,
          canonicalBase: canonicalBase,
          onWarning: onWarning,
        );

  if (debugCheckMetaStability && match != null) {
    final other = await match.resolve(
      detail: detail == SeoDetail.head ? SeoDetail.full : SeoDetail.head,
      canonicalBase: canonicalBase,
      onWarning: onWarning,
    );
    _assertMetaStable(target.path, resolution, other);
  }

  return SeoResolvedPage(
    path: target.path,
    route: match?.route,
    params: match?.params ?? const {},
    resolution: resolution,
    explicit: target.explicit,
  );
}

SeoResolvedPage _resolveTargetSync(
  _Target target, {
  required String? canonicalBase,
  required SeoDetail detail,
}) {
  final match = target.match;
  if (match == null) {
    return SeoResolvedPage(
      path: target.path,
      route: null,
      params: const {},
      // See _resolveTarget: an unmatched explicit path stays listed.
      resolution: const SeoDocument(),
      explicit: target.explicit,
    );
  }
  final resolution =
      match.resolveSync(detail: detail, canonicalBase: canonicalBase);
  if (resolution == null) {
    throw StateError(
      'seoSitemapXml(routes:)/seoLlmsTxt(routes:) cannot resolve a '
      'SeoRoute.dynamic ("${match.route.path}"). Resolve the table first: '
      'pass pages: await resolveSeoPages(routes: …, canonicalBase: …). '
      'seoBotMiddleware and prerenderSite do this for you.',
    );
  }
  return SeoResolvedPage(
    path: target.path,
    route: match.route,
    params: match.params,
    resolution: resolution,
    explicit: target.explicit,
  );
}

/// Everything about a resolution that must NOT depend on the detail
/// asked for. The body is the one thing a `head` request may skip;
/// change any of these between head and full and the sitemap, the
/// prerendered file and the SSR response start describing different
/// pages.
String _stableFingerprint(SeoResolution r) => switch (r) {
      SeoRedirect(:final location, :final statusCode) =>
        'redirect $statusCode $location',
      SeoDocument(
        :final meta,
        :final statusCode,
        :final lang,
        :final lastModified,
        :final includeInSitemap
      ) =>
        'document $statusCode lang=$lang lastmod=${lastModified?.toIso8601String()} '
            'sitemap=$includeInSitemap ${meta.toHtml()}',
    };

void _assertMetaStable(
  String path,
  SeoResolution a,
  SeoResolution b,
) {
  final headA = _stableFingerprint(a);
  final headB = _stableFingerprint(b);
  if (headA != headB) {
    throw StateError(
      'Resolver for "$path" answered head and full differently. '
      'A head resolution may carry less BODY, never a different status, '
      'redirect target, lang, lastModified, includeInSitemap or meta — '
      'otherwise sitemap.xml and llms.txt disagree with the rendered page.\n'
      '  head/full A: $headA\n'
      '  head/full B: $headB',
    );
  }
}
