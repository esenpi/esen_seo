import '../meta/seo_meta.dart';
import '../renderer/tag_policy.dart';
import '../routing/seo_resolution.dart';
import '../routing/seo_resolved_page.dart';
import '../routing/seo_route.dart';
import 'node_walk.dart';
import 'seo_audit_policy.dart';
import 'seo_audit_report.dart';
import 'seo_finding.dart';

/// Audits a route table for the mistakes the package cannot prevent.
///
/// Everything here is derived from the **model** — the route table and
/// the nodes it resolves to — never from built HTML. That is deliberate:
/// the package owns the table, so it can answer these questions before
/// `flutter build web` has even run, without an HTML parser and without
/// a crawler. A broken internal link is simply an `href` that
/// [matchSeoRoute] cannot match.
///
/// ```dart
/// final report = await auditSeoRoutes(
///   routes: seoRoutes,
///   siteBase: siteBase,
/// );
/// if (!report.passes()) {
///   stderr.write(report.describe());
///   exit(1);
/// }
/// ```
Future<SeoAuditReport> auditSeoRoutes({
  required List<SeoRoute> routes,
  required String siteBase,
  List<String> additionalPaths = const [],
  SeoAuditPolicy policy = const SeoAuditPolicy(),
}) async {
  final failures = <String, Object>{};
  final pages = await resolveSeoPages(
    routes: routes,
    canonicalBase: siteBase,
    additionalPaths: additionalPaths,
    detail: SeoDetail.full,
    // A resolver that throws must not abort the audit: the whole point
    // is to report everything wrong at once. The failure becomes a
    // finding, and the run is marked partial so cross-page checks do
    // not reason about an incomplete set.
    onError: (path, error, _) => failures[path] = error,
  );

  return auditSeoPages(
    pages: pages,
    routes: routes,
    siteBase: siteBase,
    policy: policy,
    resolverFailures: failures,
  );
}

/// Audits an already-resolved set of pages.
///
/// Use this when you have run [resolveSeoPages] yourself — the
/// prerenderer does, so it can audit the exact snapshot it is about to
/// write rather than resolving the site a second time.
SeoAuditReport auditSeoPages({
  required List<SeoResolvedPage> pages,
  required List<SeoRoute> routes,
  required String siteBase,
  SeoAuditPolicy policy = const SeoAuditPolicy(),
  Map<String, Object> resolverFailures = const {},
}) {
  final findings = <SeoFinding>[];
  final partial = resolverFailures.isNotEmpty;
  final base = _stripSlash(siteBase);

  for (final entry in resolverFailures.entries) {
    findings.add(SeoFinding(
      check: SeoCheck.resolverFailed,
      severity: SeoSeverity.error,
      path: entry.key,
      message: 'the resolver threw, so this page has no content at all',
      detail: entry.value.toString(),
    ));
  }

  findings.addAll(_auditRouteTable(routes, policy));

  final indexable = [
    for (final p in pages)
      if (p.isIndexable) p
  ];
  for (final page in pages) {
    findings.addAll(_auditPage(page, routes, base, policy));
  }

  // Cross-page checks need the complete set to be sound. With a page
  // missing, "this title is unique" and "nothing links here" are both
  // unprovable, so they are skipped rather than reported wrongly.
  if (!partial) {
    findings.addAll(_auditAcrossPages(indexable, pages, base, policy));
  }

  if (indexable.isEmpty && pages.isNotEmpty) {
    findings.add(const SeoFinding(
      check: SeoCheck.sitemapEmpty,
      severity: SeoSeverity.error,
      message: 'no page is indexable — sitemap.xml would ship empty',
    ));
  }

  return SeoAuditReport(
    findings: findings,
    pagesAudited: pages.length,
    partial: partial,
  );
}

// ─────────────────────────── the route table ───────────────────────────

Iterable<SeoFinding> _auditRouteTable(
  List<SeoRoute> routes,
  SeoAuditPolicy policy,
) sync* {
  final seen = <String, int>{};
  for (var i = 0; i < routes.length; i++) {
    final route = routes[i];

    final firstAt = seen[route.path];
    if (firstAt != null) {
      yield SeoFinding(
        check: SeoCheck.routeDuplicatePath,
        severity: SeoSeverity.error,
        path: route.path,
        message: 'declared twice; the later one is dead code',
        detail: 'also at index $firstAt',
      );
    } else {
      seen[route.path] = i;
    }

    // A concrete path declared after a pattern that swallows it never
    // runs. matchSeoRoute takes the FIRST match, so /blog/:slug before
    // /blog/archive means the archive page silently serves the pattern's
    // content — and the sitemap still advertises the URL.
    if (!route.hasParams) {
      for (var j = 0; j < i; j++) {
        final earlier = routes[j];
        if (earlier.hasParams && earlier.match(route.path) != null) {
          yield SeoFinding(
            check: SeoCheck.routeShadowed,
            severity: SeoSeverity.error,
            path: route.path,
            message: 'unreachable: an earlier pattern already matches it, '
                'so this route never runs',
            detail: 'shadowed by ${earlier.path}',
          );
          break;
        }
      }
    }

    if (policy.isEnabled(SeoCheck.routeNotEnumerated) &&
        route.hasParams &&
        route.enumeratePaths == null) {
      yield SeoFinding(
        check: SeoCheck.routeNotEnumerated,
        severity: SeoSeverity.warning,
        path: route.path,
        message: 'a :param route with no enumeratePaths — its URLs work '
            'for visitors but never reach sitemap.xml, llms.txt or the '
            'prerenderer',
      );
    }
  }
}

// ───────────────────────────── one page ─────────────────────────────

Iterable<SeoFinding> _auditPage(
  SeoResolvedPage page,
  List<SeoRoute> routes,
  String base,
  SeoAuditPolicy policy,
) sync* {
  final doc = page.document;
  if (doc == null) return; // a redirect: nothing to audit on the page
  final meta = doc.meta;
  final path = page.path;
  final indexable = page.isIndexable;

  // ── metadata
  final title = meta.title?.trim() ?? '';
  if (indexable && title.isEmpty) {
    yield SeoFinding(
      check: SeoCheck.titleMissing,
      severity: SeoSeverity.error,
      path: path,
      message: 'no <title>: search results have nothing to show',
    );
  } else if (indexable && policy.isEnabled(SeoCheck.titleLength)) {
    final n = title.length;
    if (n < policy.minTitleLength || n > policy.maxTitleLength) {
      yield SeoFinding(
        check: SeoCheck.titleLength,
        severity: SeoSeverity.info,
        path: path,
        message: 'title is $n characters; '
            '${policy.minTitleLength}–${policy.maxTitleLength} shows in '
            'full in search results',
      );
    }
  }

  final description = meta.description?.trim() ?? '';
  if (indexable && description.isEmpty) {
    yield SeoFinding(
      check: SeoCheck.descriptionMissing,
      severity: SeoSeverity.warning,
      path: path,
      message: 'no meta description — search engines invent a snippet, '
          'and the llms.txt line for this page stays empty',
    );
  } else if (indexable &&
      description.isNotEmpty &&
      policy.isEnabled(SeoCheck.descriptionLength)) {
    final n = description.length;
    if (n < policy.minDescriptionLength || n > policy.maxDescriptionLength) {
      yield SeoFinding(
        check: SeoCheck.descriptionLength,
        severity: SeoSeverity.info,
        path: path,
        message: 'description is $n characters; '
            '${policy.minDescriptionLength}–${policy.maxDescriptionLength} '
            'is the usual snippet window',
      );
    }
  }

  // ── indexing signals that contradict each other
  final robots = meta.robots?.toLowerCase() ?? '';
  if (robots.contains('noindex') && indexable) {
    yield SeoFinding(
      check: SeoCheck.robotsNoindexInSitemap,
      severity: SeoSeverity.error,
      path: path,
      message: 'marked noindex but still listed in sitemap.xml — two '
          'contradictory signals; set includeInSitemap: false as well',
    );
  }

  // ── canonical and other URLs the policy has to accept
  yield* _auditUrls(page, meta, routes, base, policy);

  // ── body structure
  final facts = SeoBodyFacts.of(doc.body);
  if (indexable && facts.isEmpty) {
    yield SeoFinding(
      check: SeoCheck.bodyEmpty,
      severity: SeoSeverity.warning,
      path: path,
      message: 'no server-side body: crawlers get metadata only, and the '
          'middleware falls through to the app shell',
    );
  } else if (indexable) {
    final h1s = facts.headings.where((h) => h.level == 1).toList();
    if (h1s.isEmpty) {
      yield SeoFinding(
        check: SeoCheck.headingNoH1,
        severity: SeoSeverity.warning,
        path: path,
        message: 'the page has content but no <h1>',
      );
    } else if (h1s.length > 1) {
      yield SeoFinding(
        check: SeoCheck.headingMultipleH1,
        severity: SeoSeverity.warning,
        path: path,
        message: '${h1s.length} <h1> elements; one page is one topic',
        detail: h1s.map((h) => '"${h.text}"').join(', '),
      );
    }
  }

  // ── images
  for (final image in facts.images) {
    final src = image.attributes['src']?.trim() ?? '';
    if (src.isEmpty) {
      yield SeoFinding(
        check: SeoCheck.imageSrcMissing,
        severity: SeoSeverity.error,
        path: path,
        message: 'an <img> with no src',
      );
    }
    if (!image.attributes.containsKey('alt')) {
      yield SeoFinding(
        check: SeoCheck.imageAltMissing,
        severity: SeoSeverity.error,
        path: path,
        message: 'an <img> with no alt attribute',
        detail: src.isEmpty ? null : src,
      );
    }
  }

  // ── links (the per-page half; targets are checked across pages)
  for (final link in facts.links) {
    final href = link.attributes['href']?.trim();
    if (href == null || href.isEmpty || href == '#') {
      yield SeoFinding(
        check: SeoCheck.linkEmptyHref,
        severity: SeoSeverity.warning,
        path: path,
        message: 'a link with no destination',
        detail: seoNodeText(link).isEmpty ? null : seoNodeText(link),
      );
      continue;
    }
    if (seoNodeText(link).isEmpty &&
        !link.children.any((c) => c.tag.toLowerCase() == 'img')) {
      yield SeoFinding(
        check: SeoCheck.linkNoText,
        severity: SeoSeverity.warning,
        path: path,
        message: 'a link with no anchor text — nothing tells a crawler '
            'what it points at',
        detail: href,
      );
    }
  }

  // ── structured data
  yield* _auditSchemas(path, meta, base, policy);
}

// ─────────────────────────────── URLs ───────────────────────────────

Iterable<SeoFinding> _auditUrls(
  SeoResolvedPage page,
  SeoMeta meta,
  List<SeoRoute> routes,
  String base,
  SeoAuditPolicy policy,
) sync* {
  final path = page.path;

  void check(String? url, String what) {}

  final canonical = meta.canonicalUrl;
  if (canonical != null && canonical.isNotEmpty) {
    // A canonical the URL policy refuses is worse than none: the head
    // gets no <link rel="canonical"> at all, AND the non-null value
    // suppresses the automatic derivation from siteBase. The page ends
    // up strictly worse off than if nothing had been set.
    if (!isAllowedSeoAttribute('href', canonical)) {
      yield SeoFinding(
        check: SeoCheck.urlRejectedByPolicy,
        severity: SeoSeverity.error,
        path: path,
        message: 'the canonical URL is refused by the URL policy, so the '
            'page ends up with NO canonical — and setting it also '
            'suppressed the automatic one',
        detail: canonical,
      );
    } else if (!_isAbsolute(canonical)) {
      yield SeoFinding(
        check: SeoCheck.canonicalRelative,
        severity: SeoSeverity.error,
        path: path,
        message: 'rel=canonical must be an absolute URL',
        detail: canonical,
      );
    } else if (canonical.startsWith(base)) {
      final target = canonical.substring(base.length);
      final normalized = target.isEmpty ? '/' : target;
      if (matchSeoRoute(routes, normalized) == null) {
        yield SeoFinding(
          check: SeoCheck.canonicalUnknownPath,
          severity: SeoSeverity.error,
          path: path,
          message: 'the canonical points at a path no route serves — it '
              'canonicalises this page to a 404',
          detail: canonical,
        );
      }
    }
  }

  for (final entry in meta.alternates.entries) {
    if (!isAllowedSeoAttribute('href', entry.value)) {
      yield SeoFinding(
        check: SeoCheck.urlRejectedByPolicy,
        severity: SeoSeverity.error,
        path: path,
        message: 'an hreflang URL is refused by the URL policy and will '
            'not be emitted',
        detail: '${entry.key} → ${entry.value}',
      );
    }
  }

  final ogImage = meta.openGraph?.image;
  if (ogImage != null && ogImage.isNotEmpty && !_isAbsolute(ogImage)) {
    yield SeoFinding(
      check: SeoCheck.schemaRelativeUrl,
      severity: SeoSeverity.error,
      path: path,
      message: 'og:image must be absolute — social scrapers do not '
          'resolve relative URLs',
      detail: ogImage,
    );
  }
  check(null, '');
}

// ─────────────────────────── structured data ───────────────────────────

/// Properties Google documents as required, per schema type.
const Map<String, List<String>> _requiredSchemaFields = {
  'Article': ['headline'],
  'NewsArticle': ['headline'],
  'BlogPosting': ['headline'],
  'Product': ['name'],
  'Organization': ['name'],
  'WebSite': ['name'],
  'Event': ['name', 'startDate'],
  'LocalBusiness': ['name'],
  'Review': ['reviewRating'],
};

Iterable<SeoFinding> _auditSchemas(
  String path,
  SeoMeta meta,
  String base,
  SeoAuditPolicy policy,
) sync* {
  for (final schema in meta.schemas) {
    // A value JSON cannot encode (a Duration, a DateTime, an enum)
    // throws only when the page is rendered — in a production request
    // or halfway through a build, not when the route table is written.
    String? json;
    try {
      json = schema.toJsonString();
    } catch (error) {
      yield SeoFinding(
        check: SeoCheck.schemaInvalidJson,
        severity: SeoSeverity.error,
        path: path,
        message: 'a schema value cannot be encoded as JSON; this throws '
            'when the page renders, not here',
        detail: '${schema.type}: $error',
      );
      continue;
    }

    final required = _requiredSchemaFields[schema.type];
    if (required != null) {
      for (final field in required) {
        final value = schema.properties[field];
        if (value == null || (value is String && value.trim().isEmpty)) {
          yield SeoFinding(
            check: SeoCheck.schemaMissingRequired,
            severity: SeoSeverity.error,
            path: path,
            message: '${schema.type} is missing the required property '
                '"$field" — the rich result will not be granted',
          );
        }
      }
    }

    for (final key in const ['url', 'image', 'logo']) {
      final value = schema.properties[key];
      if (value is String && value.isNotEmpty && !_isAbsolute(value)) {
        yield SeoFinding(
          check: SeoCheck.schemaRelativeUrl,
          severity: SeoSeverity.error,
          path: path,
          message: '${schema.type}.$key must be an absolute URL in JSON-LD',
          detail: value,
        );
      }
    }
    if (json.isEmpty) continue;
  }
}

// ──────────────────────── across the whole site ────────────────────────

Iterable<SeoFinding> _auditAcrossPages(
  List<SeoResolvedPage> indexable,
  List<SeoResolvedPage> all,
  String base,
  SeoAuditPolicy policy,
) sync* {
  // Duplicate titles and descriptions — the copy-pasted route table.
  yield* _duplicates(
    indexable,
    (p) => p.document?.meta.title?.trim(),
    SeoCheck.titleDuplicate,
    'share this title',
  );
  yield* _duplicates(
    indexable,
    (p) => p.document?.meta.description?.trim(),
    SeoCheck.descriptionDuplicate,
    'share this description',
  );

  // Where every internal link actually lands.
  final byPath = {for (final p in all) p.path: p};
  for (final page in all) {
    final doc = page.document;
    if (doc == null) continue;
    for (final link in SeoBodyFacts.of(doc.body).links) {
      final href = link.attributes['href']?.trim() ?? '';
      final target = _internalTarget(href, base);
      if (target == null) continue;
      final resolved = byPath[target];
      if (resolved == null) {
        yield SeoFinding(
          check: SeoCheck.linkBroken,
          severity: SeoSeverity.error,
          path: page.path,
          message: 'links to a path that no route serves',
          detail: href,
        );
      } else if (resolved.document?.statusCode != null &&
          resolved.document!.statusCode >= 400) {
        yield SeoFinding(
          check: SeoCheck.linkToError,
          severity: SeoSeverity.error,
          path: page.path,
          message: 'links to a page that resolves to '
              '${resolved.document!.statusCode}',
          detail: href,
        );
      }
    }
  }

  // hreflang is only worth anything when the cluster agrees with itself.
  final alternatesByPath = <String, Map<String, String>>{
    for (final p in indexable)
      if ((p.document?.meta.alternates ?? const {}).isNotEmpty)
        p.path: p.document!.meta.alternates,
  };
  for (final entry in alternatesByPath.entries) {
    final path = entry.key;
    final alternates = entry.value;
    final selfUrl = path == '/' ? '$base/' : '$base$path';

    if (!alternates.values.any((u) => _sameUrl(u, selfUrl, base, path))) {
      yield SeoFinding(
        check: SeoCheck.hreflangMissingSelf,
        severity: SeoSeverity.error,
        path: path,
        message: 'the hreflang cluster does not include this page itself; '
            'Google discards a cluster that is not self-referential',
      );
    }

    for (final alternate in alternates.entries) {
      final target = _internalTarget(alternate.value, base);
      if (target == null) continue;
      final other = alternatesByPath[target];
      if (!byPath.containsKey(target)) {
        yield SeoFinding(
          check: SeoCheck.hreflangUnknownTarget,
          severity: SeoSeverity.error,
          path: path,
          message: 'an hreflang alternate points at a path no route serves',
          detail: '${alternate.key} → ${alternate.value}',
        );
      } else if (other == null ||
          !other.values.any((u) => _sameUrl(u, selfUrl, base, path))) {
        yield SeoFinding(
          check: SeoCheck.hreflangNotReciprocal,
          severity: SeoSeverity.error,
          path: path,
          message: 'declares ${alternate.key} → $target, but that page '
              'does not link back; Google ignores one-way clusters',
          detail: alternate.value,
        );
      }
    }
  }
}

Iterable<SeoFinding> _duplicates(
  List<SeoResolvedPage> pages,
  String? Function(SeoResolvedPage) valueOf,
  SeoCheck check,
  String phrase,
) sync* {
  final byValue = <String, List<String>>{};
  for (final page in pages) {
    final value = valueOf(page);
    if (value == null || value.isEmpty) continue;
    byValue.putIfAbsent(value, () => []).add(page.path);
  }
  for (final entry in byValue.entries) {
    if (entry.value.length < 2) continue;
    for (final path in entry.value) {
      yield SeoFinding(
        check: check,
        severity: SeoSeverity.warning,
        path: path,
        message: '${entry.value.length} pages $phrase',
        detail:
            '"${entry.key}" — also ${entry.value.where((p) => p != path).join(', ')}',
      );
    }
  }
}

// ───────────────────────────── helpers ─────────────────────────────

String _stripSlash(String url) =>
    url.endsWith('/') ? url.substring(0, url.length - 1) : url;

bool _isAbsolute(String url) =>
    url.startsWith('http://') || url.startsWith('https://');

/// The site-local path [href] points at, or `null` when it is external,
/// a fragment, or a non-http scheme.
String? _internalTarget(String href, String base) {
  if (href.isEmpty || href.startsWith('#')) return null;
  if (href.startsWith(base)) {
    final rest = href.substring(base.length);
    final withoutQuery = rest.split('#').first.split('?').first;
    return normalizeSeoPath(withoutQuery.isEmpty ? '/' : withoutQuery);
  }
  if (href.startsWith('/') && !href.startsWith('//')) {
    return normalizeSeoPath(href.split('#').first.split('?').first);
  }
  return null;
}

bool _sameUrl(String url, String selfUrl, String base, String path) {
  if (url == selfUrl) return true;
  final target = _internalTarget(url, base);
  return target != null && target == path;
}
