import '../meta/seo_meta.dart';
import '../renderer/seo_node.dart';
import '../renderer/tag_policy.dart';

/// How much of a page the caller needs.
///
/// A **hint**, never a contract: returning a full document for a [head]
/// request is always valid, so correctness never depends on the
/// resolver honouring it. The invariant runs the other way — a [head]
/// resolution may return less *body*, never less *meta*. head and full
/// must describe the same record, or sitemap.xml and llms.txt would
/// silently disagree with the rendered page. See
/// `resolveSeoPages(debugCheckMetaStability: true)`.
///
/// The point of [head] is cost: a 10 000-URL sitemap needs each page's
/// title, description and alternates, not its body. A resolver that
/// skips the body for [head] turns 10 000 full renders into 10 000
/// cheap reads.
enum SeoDetail { head, full }

/// What a resolver is asked for.
///
/// Pure Dart on purpose — no shelf `Request`, no Flutter. `core.dart`
/// is shared by the app and the server, so the request that reaches a
/// resolver must be expressible in both worlds; the middleware adapts
/// its own request into this.
///
/// Deliberately carries no request headers and no "stage" flag.
/// Content that differs per caller is two independently maintained
/// sources of truth, which is the exact thing this API exists to
/// remove.
class SeoRequest {
  const SeoRequest({
    required this.path,
    this.params = const {},
    this.detail = SeoDetail.full,
    this.siteBase,
  });

  /// The normalized request path, e.g. `/products/roadbike`.
  final String path;

  /// The captured `:param` values, e.g. `{slug: roadbike}`.
  final Map<String, String> params;

  /// How much of the page the caller needs — see [SeoDetail].
  final SeoDetail detail;

  /// The site's base URL, for building absolute URLs in schemas.
  final String? siteBase;

  /// `request['slug']` — a nullable parameter lookup.
  String? operator [](String name) => params[name];

  /// `request.param('slug')` — like `[]` but throws a named error when
  /// the parameter is absent, instead of a bare null-check failure at
  /// some later use site. Reach for this in a resolver where a missing
  /// parameter means the route pattern and the resolver disagree.
  String param(String name) {
    final value = params[name];
    if (value == null) {
      throw StateError(
        'SeoRequest has no parameter "$name" for path "$path" — the route '
        'pattern and the resolver disagree about the URL shape.',
      );
    }
    return value;
  }
}

/// What a route resolves to for one concrete URL: either a page
/// ([SeoDocument]) or a redirect ([SeoRedirect]).
///
/// Sealed on purpose — every consumer switches over it exhaustively,
/// and the compiler flags any path that forgets one. Adding a third
/// kind is therefore a breaking change by design; the shape is meant to
/// be settled before 1.0.
sealed class SeoResolution {
  const SeoResolution();

  /// The metadata of a [SeoDocument]; `null` for a [SeoRedirect].
  SeoMeta? get metaOrNull;

  /// The HTTP status this resolution stands for.
  int get statusCode;
}

/// One page, produced by one read: metadata **and** body together, so
/// they can never describe different records.
///
/// A `statusCode` is either `200` or `>= 400`. A 3xx is not a document —
/// it is a [SeoRedirect], which carries the target a document has no
/// field for.
final class SeoDocument extends SeoResolution {
  const SeoDocument({
    this.meta = const SeoMeta(),
    this.body = const <SeoNode>[],
    this.statusCode = 200,
    this.lang,
    this.lastModified,
    this.includeInSitemap,
    this.headers = const {},
  }) : assert(
          statusCode == 200 || statusCode >= 400,
          'A 3xx redirect belongs in SeoRedirect, not SeoDocument.',
        );

  /// A 404 page. Forced to `noindex` unless the caller set `robots`
  /// itself — a missing page that invites indexing is a bug.
  factory SeoDocument.notFound({
    SeoMeta meta = const SeoMeta(),
    List<SeoNode> body = const [],
  }) =>
      SeoDocument(
        meta: meta.copyWith(robots: meta.robots ?? 'noindex'),
        body: body,
        statusCode: 404,
        includeInSitemap: false,
      );

  /// A 410 Gone page — the content existed and will not return. Like
  /// [SeoDocument.notFound] but a stronger signal to drop the URL.
  factory SeoDocument.gone({
    SeoMeta meta = const SeoMeta(),
    List<SeoNode> body = const [],
  }) =>
      SeoDocument(
        meta: meta.copyWith(robots: meta.robots ?? 'noindex'),
        body: body,
        statusCode: 410,
        includeInSitemap: false,
      );

  /// The page metadata — `<title>`, description, OpenGraph, schemas, …
  final SeoMeta meta;

  /// The semantic HTML body as [SeoNode]s.
  final List<SeoNode> body;

  @override
  final int statusCode;

  /// The document language; `null` falls back to `SeoRoute.lang`.
  final String? lang;

  /// When this record last changed — a per-record `<lastmod>` that beats
  /// the route's static [lastModified]. `null` falls back to the route.
  final DateTime? lastModified;

  /// Whether this URL belongs in sitemap.xml / llms.txt; `null` falls
  /// back to `SeoRoute.includeInSitemap`. A record can pull an
  /// unpublished page out of the index even when the route opts in.
  final bool? includeInSitemap;

  /// Extra HTTP response headers, SSR only.
  ///
  /// **Reserved in 0.6.0** — the field is part of the sealed shape so it
  /// need not be added later (which would break exhaustive switches),
  /// but the middleware does not emit these yet. Header delivery, with
  /// its own policy at the chokepoint, lands in 0.7.0. The prerenderer
  /// ignores this field entirely, since a static file has no response
  /// headers.
  final Map<String, String> headers;

  @override
  SeoMeta? get metaOrNull => meta;

  /// Whether this is a normal, indexable `200`.
  bool get isOk => statusCode == 200;

  SeoDocument copyWith({
    SeoMeta? meta,
    List<SeoNode>? body,
    int? statusCode,
    String? lang,
    DateTime? lastModified,
    bool? includeInSitemap,
    Map<String, String>? headers,
  }) =>
      SeoDocument(
        meta: meta ?? this.meta,
        body: body ?? this.body,
        statusCode: statusCode ?? this.statusCode,
        lang: lang ?? this.lang,
        lastModified: lastModified ?? this.lastModified,
        includeInSitemap: includeInSitemap ?? this.includeInSitemap,
        headers: headers ?? this.headers,
      );
}

/// A redirect from one URL to another — the target a [SeoDocument] has
/// no field for.
final class SeoRedirect extends SeoResolution {
  const SeoRedirect(this.location, {this.statusCode = 301})
      : assert(
          statusCode >= 300 && statusCode < 400,
          'A redirect status is 3xx.',
        );

  /// Where to send the request. Held to the same URL policy as an
  /// `href` — see [finishSeoResolution].
  final String location;

  @override
  final int statusCode;

  @override
  SeoMeta? get metaOrNull => null;
}

/// **The chokepoint.** Every path from a resolver to any output — SSR,
/// prerender, sitemap.xml, llms.txt — runs its resolution through here,
/// exactly as every tag and attribute runs through the renderer's
/// policy. A resolver is a new road from (eventually CMS) data into
/// HTTP output, and the mistake this package already made once was to
/// put a policy in one output path while another bypassed it.
///
/// Two things happen:
///
///  * A [SeoRedirect] whose [SeoRedirect.location] fails
///    `isAllowedSeoAttribute('href', …)` — a `javascript:` target, say —
///    or contains a CR/LF (HTTP response splitting) becomes a
///    [SeoDocument.notFound] and is reported through [onWarning]. The
///    site never emits an unsafe `Location`, and never throws over it.
///  * `rel=canonical` is derived from [canonicalBase] + [path] **only**
///    for a `200` [SeoDocument] that set no `canonicalUrl` of its own.
///    A 404 that declares a canonical to itself is a bug the old
///    `buildMeta` committed because it could not see a status code.
SeoResolution finishSeoResolution(
  SeoResolution resolution, {
  required String path,
  String? canonicalBase,
  void Function(String path, String warning)? onWarning,
}) {
  switch (resolution) {
    case SeoRedirect(:final location, :final statusCode):
      final problem = _redirectProblem(location, statusCode);
      if (problem != null) {
        onWarning?.call(
          path,
          'refused a redirect to "$location" ($statusCode): $problem — '
          'served a 404 instead',
        );
        return SeoDocument.notFound();
      }
      return resolution;
    case SeoDocument(:final meta, :final statusCode):
      // `assert` does not run in production, so the status is validated
      // for real here, at the one point every output path crosses.
      if (statusCode != 200 && (statusCode < 400 || statusCode > 599)) {
        onWarning?.call(
          path,
          'refused an out-of-range status ($statusCode) — served a 404 '
          'instead',
        );
        return SeoDocument.notFound();
      }
      if (statusCode != 200 ||
          meta.canonicalUrl != null ||
          canonicalBase == null) {
        return resolution;
      }
      final base = _stripTrailingSlash(canonicalBase);
      return resolution.copyWith(
        meta: meta.copyWith(
          canonicalUrl: path == '/' ? '$base/' : '$base$path',
        ),
      );
  }
}

/// HTTP redirect statuses. `304 Not Modified` is not one of them — it
/// carries no `Location` and means something else entirely.
const Set<int> _redirectStatuses = {301, 302, 303, 307, 308};

/// Why [location] must not become a `Location` header, or `null` when it
/// is fine.
///
/// Stricter than the link policy on purpose. `mailto:`, `tel:` and
/// `ftp:` are legitimate link targets and nonsense as redirects; an
/// empty target or a bare `#fragment` resolves back to the current URL
/// and makes a redirect loop the browser gives up on.
String? _redirectProblem(String location, int statusCode) {
  if (!_redirectStatuses.contains(statusCode)) {
    return 'not an HTTP redirect status';
  }
  final target = location.trim();
  if (target.isEmpty) return 'empty target';
  if (target.startsWith('#')) return 'fragment-only target loops';
  if (target.codeUnits.any((c) => c < 0x20 || c == 0x7F)) {
    return 'control characters would split the response';
  }
  if (!isAllowedSeoAttribute('href', target)) return 'unsafe URL';
  final scheme = RegExp(r'^([a-zA-Z][a-zA-Z0-9+.-]*):').firstMatch(target);
  if (scheme != null) {
    final name = scheme.group(1)!.toLowerCase();
    if (name != 'http' && name != 'https') {
      return 'scheme "$name" cannot be a redirect target';
    }
  }
  return null;
}

String _stripTrailingSlash(String url) =>
    url.endsWith('/') ? url.substring(0, url.length - 1) : url;
