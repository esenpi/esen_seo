import '../meta/seo_meta.dart';
import '../renderer/tag_policy.dart';
import '../routing/seo_resolution.dart';
import '../routing/seo_resolved_page.dart';
import '../routing/seo_route.dart';
import 'hreflang_codes.dart';
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
    findings.addAll(_auditAcrossPages(indexable, pages, base, policy, routes));
  }

  if (indexable.isEmpty) {
    findings.add(const SeoFinding(
      check: SeoCheck.sitemapEmpty,
      severity: SeoSeverity.error,
      message: 'no page is indexable — sitemap.xml would ship empty',
    ));
  }

  return SeoAuditReport(
    // Filtered here, once, rather than at each check. Asking every
    // check to remember `policy.isEnabled` is the kind of rule that
    // holds until someone adds the thirty-first — and a suppression
    // that silently does nothing is worse than none, because the team
    // believes they have turned the finding off.
    findings: [
      for (final finding in findings)
        if (policy.isEnabled(finding.check)) finding,
    ],
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
      // One defect, one finding — the shadow check below would report
      // the identical pattern a second time.
      continue;
    }
    seen[route.path] = i;

    // A concrete path declared after a pattern that swallows it never
    // runs. matchSeoRoute takes the FIRST match, so /blog/:slug before
    // /blog/archive means the archive page silently serves the pattern's
    // content — and the sitemap still advertises the URL.
    for (var j = 0; j < i; j++) {
      final earlier = routes[j];
      if (!earlier.hasParams) continue;

      // A concrete path swallowed by an earlier pattern.
      if (!route.hasParams && earlier.match(route.path) != null) {
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

      // A pattern swallowed by an earlier pattern — the same shape
      // (`/blog/:slug` then `/blog/:id`) or a wider one (`/:section/:slug`
      // before `/blog/:slug`). Either way the later pattern can never
      // win a match, and neither the duplicate-path check (the strings
      // differ) nor the concrete case above saw it.
      if (route.hasParams && _swallows(earlier.path, route.path)) {
        yield SeoFinding(
          check: SeoCheck.routeShadowed,
          severity: SeoSeverity.error,
          path: route.path,
          message: 'unreachable: an earlier pattern matches every URL this '
              'route could serve, so every request goes to that one instead',
          detail: 'shadowed by ${earlier.path}',
        );
        break;
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
  // An additionalPaths entry matching no route is a placeholder by
  // design — resolveSeoPages documents that its content is served
  // outside the table. Auditing the placeholder for a title it can
  // never have failed every legitimate use of the feature.
  if (page.route == null) return;
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
  // `none` is shorthand for `noindex, nofollow` — a page using it is
  // just as much out of the index as one saying so at length.
  final robots = meta.robots?.toLowerCase() ?? '';
  final noindex = robots.contains('noindex') ||
      robots.split(',').map((d) => d.trim()).contains('none');
  if (noindex && indexable) {
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
  if (facts.truncated) {
    // Without this, a truncated walk reads as "checked and clean"
    // about the part of the tree nobody looked at.
    yield SeoFinding(
      check: SeoCheck.bodyTruncated,
      severity: SeoSeverity.error,
      path: path,
      message: 'the body nests deeper than the renderer accepts '
          '(${SeoBodyFacts.maxDepth} levels) — rendering this page would '
          'throw, so the structural audit cannot complete',
    );
  }
  // Absence claims need the whole tree: a truncated walk cannot say
  // "empty" or "no h1" about the part nobody visited. (Presence claims
  // — a second <h1> that WAS found — stay valid regardless.)
  if (indexable && facts.isEmpty && !facts.truncated) {
    yield SeoFinding(
      check: SeoCheck.bodyEmpty,
      severity: SeoSeverity.warning,
      path: path,
      message: 'no server-side body: crawlers get metadata only, and the '
          'middleware falls through to the app shell',
    );
  } else if (indexable) {
    final h1s = facts.headings.where((h) => h.level == 1).toList();
    if (h1s.isEmpty && !facts.truncated) {
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
    // Presence is judged trimmed, the policy sees the RAW value — the
    // renderer does too, and its control-character rule refuses a URL
    // with a trailing newline. Checking the trimmed value here passed
    // an <img> whose src the renderer had already dropped.
    final rawSrc = image.attributes['src'];
    final src = rawSrc?.trim() ?? '';
    if (src.isEmpty) {
      yield SeoFinding(
        check: SeoCheck.imageSrcMissing,
        severity: SeoSeverity.error,
        path: path,
        message: 'an <img> with no src',
      );
    } else if (!isAllowedSeoAttribute('src', rawSrc!)) {
      // Same as the link case: the renderer drops it, so the page ships
      // an <img> that can never load.
      yield SeoFinding(
        check: SeoCheck.urlRejectedByPolicy,
        severity: SeoSeverity.error,
        path: path,
        message: 'this image\'s src is refused by the URL policy, so the '
            'rendered page has an <img> that cannot load',
        detail: src,
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
    final rawHref = link.attributes['href'];
    final href = rawHref?.trim();
    // The audit reads the model, but the renderer still transforms it:
    // a `javascript:` href is dropped, so what ships is an <a> with no
    // destination. Auditing the raw node called that a working link.
    // Anything the URL policy refuses is reported here, at the same
    // place the value was written.
    if (href != null &&
        href.isNotEmpty &&
        !isAllowedSeoAttribute('href', rawHref!)) {
      yield SeoFinding(
        check: SeoCheck.urlRejectedByPolicy,
        severity: SeoSeverity.error,
        path: path,
        message: 'this link\'s href is refused by the URL policy, so the '
            'rendered page has an <a> with no destination at all',
        detail: href,
      );
      continue;
    }
    if (href == null || href.isEmpty || href == '#') {
      yield SeoFinding(
        check: SeoCheck.linkEmptyHref,
        severity: SeoSeverity.warning,
        path: path,
        message: 'a link with no destination',
        detail: seoNodeText(link.node).isEmpty ? null : seoNodeText(link.node),
      );
      continue;
    }
    // The renderer ships the whole subtree inside the <a>, so an image
    // anywhere below it — a > div > img is what every card link looks
    // like — provides the anchor text via its alt.
    final linkedImages = SeoBodyFacts.of(link.node.children).images;
    final hasImageLabel = linkedImages.any(
      (image) => (image.attributes['alt'] ?? '').trim().isNotEmpty,
    );
    if (seoNodeText(link.node).isEmpty && !hasImageLabel) {
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
    } else {
      // Route the canonical through the same normaliser the link check
      // uses. Comparing the raw string against `base` treated
      // `https://x.dev.evil.com/` as internal, and left `?q=1#top` in
      // the path so a perfectly good search page canonicalising to
      // itself was reported as pointing at a 404.
      final target = _internalTarget(canonical, base);
      if (target != null && matchSeoRoute(routes, target) == null) {
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

  // Two different languages pointing at the same URL is the classic
  // copy-paste slip: the cluster stays formally valid — self-reference
  // and reciprocity both pass — while one language's real page is
  // silently orphaned. Same primary subtag (en, en-GB) and x-default
  // legitimately share a URL, so only distinct primaries count.
  final byTarget = <String, Set<String>>{};
  for (final entry in meta.alternates.entries) {
    if (entry.key.toLowerCase() == 'x-default') continue;
    final primary = entry.key.split(RegExp('[-_]')).first.toLowerCase();
    byTarget.putIfAbsent(entry.value, () => {}).add(primary);
  }
  for (final entry in byTarget.entries) {
    if (entry.value.length < 2) continue;
    yield SeoFinding(
      check: SeoCheck.hreflangDuplicateTarget,
      severity: SeoSeverity.warning,
      path: path,
      message: 'hreflang declares ${entry.value.join(' and ')} for the '
          'same URL — one of them is almost certainly a copy-paste slip, '
          'and its real page is orphaned from the cluster',
      detail: entry.key,
    );
  }

  for (final entry in meta.alternates.entries) {
    final url = entry.value;
    final where = '${entry.key} → $url';

    // Google matches hreflang codes against ISO 639-1 + optional script
    // and region, hyphen-separated. `en_US` — the single most common
    // authoring mistake — is silently ignored, which is the same
    // failure mode as a relative URL: nothing looks broken.
    if (!isValidHreflangCode(entry.key)) {
      yield SeoFinding(
        check: SeoCheck.hreflangInvalidCode,
        severity: SeoSeverity.error,
        path: path,
        message: 'not a valid hreflang code (language, optional script, '
            'optional region, hyphen-separated, or x-default) — Google '
            'ignores the annotation',
        detail: where,
      );
      continue;
    }

    if (!isAllowedSeoAttribute('href', url)) {
      yield SeoFinding(
        check: SeoCheck.urlRejectedByPolicy,
        severity: SeoSeverity.error,
        path: path,
        message: 'an hreflang URL is refused by the URL policy and will '
            'not be emitted',
        detail: where,
      );
      continue;
    }

    // Google's own requirement: hreflang annotations must be fully
    // qualified, scheme and host included. A relative value is emitted
    // happily by the renderer and then ignored by the crawler, which is
    // the worst combination — nothing looks broken.
    if (!_isAbsolute(url)) {
      yield SeoFinding(
        check: SeoCheck.hreflangRelative,
        severity: SeoSeverity.error,
        path: path,
        message: 'hreflang URLs must be absolute, including scheme and '
            'host — Google ignores relative ones',
        detail: where,
      );
      continue;
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
}

// ─────────────────────────── structured data ───────────────────────────

/// Properties Google documents as **required**: without them the item is
/// ineligible for the rich result, so the markup is inert.
const Map<String, List<String>> _requiredSchemaFields = {
  'Product': ['name'],
  // The site-name feature reads both — a WebSite without a `url` cannot
  // be tied to the site it names.
  'WebSite': ['name', 'url'],
  // A date and a place are what an event result *is*; Google lists both
  // alongside the name. `SeoSchema.event` omits `location` entirely when
  // neither location argument is given, which is exactly the gap.
  'Event': ['name', 'startDate', 'location'],
  // Same shape: `SeoSchema.localBusiness` leaves out `address` unless a
  // street, postcode or town is passed, and a local result without an
  // address cannot be placed on a map.
  'LocalBusiness': ['name', 'address'],
  // Google's review snippet needs all three — a rating on its own says
  // nothing about what was rated or who rated it.
  'Review': ['itemReviewed', 'author', 'reviewRating'],
  'BreadcrumbList': ['itemListElement'],
  'FAQPage': ['mainEntity'],
};

/// At least one of these is required, per type.
///
/// A `Product` with only a name is valid schema and still gets no
/// snippet: Google needs something to *show* — a price, a rating or a
/// review.
const Map<String, List<String>> _oneOfSchemaFields = {
  'Product': ['offers', 'review', 'aggregateRating'],
};

/// Properties Google merely **recommends**.
///
/// Article and its subtypes used to require `headline`; Google's
/// documentation now lists no required properties for them at all. A
/// missing headline still leaves the result with nothing to display, so
/// it is worth saying — as a warning, not as a build-breaking error.
const Map<String, List<String>> _recommendedSchemaFields = {
  'Article': ['headline'],
  'NewsArticle': ['headline'],
  'BlogPosting': ['headline'],
  // Google lists NO required properties for Organization — an error
  // here failed valid markup. The name is still the one property that
  // gives the knowledge panel something to show.
  'Organization': ['name'],
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
    try {
      schema.toJsonString();
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

    for (final field in _requiredSchemaFields[schema.type] ?? const []) {
      if (_isBlank(schema.properties[field])) {
        yield SeoFinding(
          check: SeoCheck.schemaMissingRequired,
          severity: SeoSeverity.error,
          path: path,
          message: '${schema.type} is missing the required property '
              '"$field" — the rich result will not be granted',
        );
      }
    }

    final oneOf = _oneOfSchemaFields[schema.type];
    if (oneOf != null &&
        oneOf.every((field) => _isBlank(schema.properties[field]))) {
      yield SeoFinding(
        check: SeoCheck.schemaMissingRequired,
        severity: SeoSeverity.error,
        path: path,
        message: '${schema.type} needs at least one of '
            '${oneOf.map((f) => '"$f"').join(', ')} — without one there is '
            'nothing for the snippet to show',
      );
    }

    for (final field in _recommendedSchemaFields[schema.type] ?? const []) {
      if (_isBlank(schema.properties[field])) {
        yield SeoFinding(
          check: SeoCheck.schemaMissingRecommended,
          severity: SeoSeverity.warning,
          path: path,
          message: '${schema.type} has no "$field"; Google no longer '
              'requires it, but the result has nothing to display without '
              'one',
        );
      }
    }

    // Inside the properties Google actually reads. An offers object
    // without a price, or a rating without a count, satisfies every
    // presence check above and still yields nothing: the shape is
    // right, and the snippet is not granted.
    if (schema.type == 'Product') {
      final offers = schema.properties['offers'];
      final values = offers is List ? offers : [offers];
      for (final offer in values) {
        if (_isBlank(offer)) continue;
        if (offer is! Map) {
          yield SeoFinding(
            check: SeoCheck.schemaMissingRequired,
            severity: SeoSeverity.error,
            path: path,
            message: 'Product.offers must be an Offer object or a list of '
                'Offer objects',
          );
          continue;
        }

        final type = offer['@type'];
        final aggregate =
            type == 'AggregateOffer' || !_isBlank(offer['lowPrice']);
        if (aggregate) {
          if (_isBlank(offer['lowPrice'])) {
            yield SeoFinding(
              check: SeoCheck.schemaMissingRequired,
              severity: SeoSeverity.error,
              path: path,
              message: 'Product AggregateOffer has no required "lowPrice"',
            );
          }
          if (_isBlank(offer['priceCurrency'])) {
            yield SeoFinding(
              check: SeoCheck.schemaMissingRequired,
              severity: SeoSeverity.error,
              path: path,
              message: 'Product AggregateOffer has no required '
                  '"priceCurrency"',
            );
          }
          continue;
        }

        final specifications = _schemaMaps(offer['priceSpecification']);
        final directPrice = !_isBlank(offer['price']);
        final pricedSpecifications = [
          for (final specification in specifications)
            if (!_isBlank(specification['price'])) specification,
        ];
        if (!directPrice && pricedSpecifications.isEmpty) {
          yield SeoFinding(
            check: SeoCheck.schemaMissingRequired,
            severity: SeoSeverity.error,
            path: path,
            message: 'Product Offer needs "price" or '
                '"priceSpecification.price"',
          );
          continue;
        }

        final hasCurrency = !_isBlank(offer['priceCurrency']) ||
            pricedSpecifications.any(
              (specification) => !_isBlank(specification['priceCurrency']),
            );
        if (!hasCurrency) {
          yield SeoFinding(
            check: SeoCheck.schemaMissingRecommended,
            severity: SeoSeverity.warning,
            path: path,
            message: 'Product Offer has a price but no currency — '
                'priceCurrency is recommended for product snippets and '
                'required for merchant listings',
          );
        }
      }
    }

    // A rating supplied as a one-element list is legal JSON-LD; the
    // offers check above already accepts that shape.
    final ratings = schema.properties['aggregateRating'];
    for (final rating in ratings is List ? ratings : [ratings]) {
      if (rating is! Map) continue;
      if (_isBlank(rating['ratingValue'])) {
        yield SeoFinding(
          check: SeoCheck.schemaMissingRequired,
          severity: SeoSeverity.error,
          path: path,
          message: '${schema.type}.aggregateRating has no "ratingValue"',
        );
      }
      if (_isBlank(rating['ratingCount']) && _isBlank(rating['reviewCount'])) {
        yield SeoFinding(
          check: SeoCheck.schemaMissingRequired,
          severity: SeoSeverity.error,
          path: path,
          message: '${schema.type}.aggregateRating needs "ratingCount" or '
              '"reviewCount" — a rating nobody appears to have given is '
              'not shown',
        );
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
  }
}

// ──────────────────────── across the whole site ────────────────────────

Iterable<SeoFinding> _auditAcrossPages(
  List<SeoResolvedPage> indexable,
  List<SeoResolvedPage> all,
  String base,
  SeoAuditPolicy policy,
  List<SeoRoute> routes,
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
      final target = _internalTarget(href, base, fromPath: page.path);
      if (target == null) continue;
      final resolved = byPath[target];
      if (resolved == null) {
        // Ask the router, not the enumeration. A `/docs/:page` route
        // without `enumeratePaths` serves every one of its URLs
        // perfectly well — the engine itself says so, one check above,
        // at warning severity. Judging links by which URLs happened to
        // be enumerated made deep links into such a route an error, on
        // the commonest shape a real app has.
        if (matchSeoRoute(routes, target) != null) continue;
        // An asset is not a page. /favicon.png and /files/x.pdf are
        // served by the static handler and were never meant to match a
        // route — the same rule the middleware uses to decide what is
        // a page path at all.
        if (!_looksLikePage(target)) continue;
        yield SeoFinding(
          check: SeoCheck.linkBroken,
          severity: SeoSeverity.error,
          path: page.path,
          message: 'links to a path that no route serves',
          // Quote the resolved path as well for a relative href: on
          // /docs/intro, `../start` is the URL /start, and the raw
          // attribute alone leaves the reader to work that out.
          detail: target == href ? href : '$href → $target',
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

  // Where each canonical actually lands. This needs the resolved set,
  // so it cannot live with the per-page canonical checks — and it is
  // the flagship case of the whole audit: a page that canonicalises
  // itself onto a 410 or a redirect asks Google to index something
  // that is not there.
  for (final page in indexable) {
    final canonical = page.document?.meta.canonicalUrl;
    if (canonical == null || canonical.isEmpty) continue;
    final target = _internalTarget(canonical, base);
    if (target == null || target == page.path) continue;
    final resolved = byPath[target];
    // Not in the resolved set: either no route serves it (the per-page
    // canonical.unknown-path check reported that) or an un-enumerated
    // :param route does — whose per-record status this synchronous
    // pass cannot know. A known limit, not a verdict.
    if (resolved == null) continue;

    final document = resolved.document;
    if (document == null) {
      yield SeoFinding(
        check: SeoCheck.canonicalNonIndexable,
        severity: SeoSeverity.error,
        path: page.path,
        message: 'the canonical points at a URL that redirects; Google '
            'follows the redirect and the signal is wasted',
        detail: canonical,
      );
    } else if (document.statusCode != 200) {
      yield SeoFinding(
        check: SeoCheck.canonicalNonIndexable,
        severity: SeoSeverity.error,
        path: page.path,
        message: 'the canonical points at a page that resolves to '
            '${document.statusCode} — this page asks to be indexed as one '
            'that is not there',
        detail: canonical,
      );
    } else if (_isNoindex(document.meta)) {
      // Judged by the robots signal, not by sitemap membership: a page
      // deliberately kept out of sitemap.xml is still perfectly
      // indexable, and canonicalising onto it is legitimate.
      yield SeoFinding(
        check: SeoCheck.canonicalNonIndexable,
        severity: SeoSeverity.error,
        path: page.path,
        message: 'the canonical points at a noindex page — two signals '
            'that cancel each other, so neither URL can rank',
        detail: canonical,
      );
    } else {
      final onward = document.meta.canonicalUrl;
      final onwardTarget =
          onward == null ? null : _internalTarget(onward, base);
      if (onward != null && onward.isNotEmpty && onwardTarget != target) {
        // A canonical chain: A says B is the original, B says C is.
        // Google follows one hop reluctantly and distrusts the rest.
        yield SeoFinding(
          check: SeoCheck.canonicalChain,
          severity: SeoSeverity.warning,
          path: page.path,
          message: 'the canonical\'s target canonicalises elsewhere — a '
              'chain (or loop) Google is documented to distrust; point '
              'both pages at the final URL',
          detail: '$canonical → $onward',
        );
      }
    }
  }

  // hreflang is only worth anything when the cluster agrees with itself.
  //
  // Built from ALL resolved pages, not only the indexable ones. A
  // language variant that is deliberately kept out of sitemap.xml still
  // declares its alternates, and judging reciprocity by sitemap
  // membership reported a perfectly symmetric cluster as one-way — and
  // said "that page does not link back", which was simply untrue.
  final alternatesByPath = <String, Map<String, String>>{
    for (final p in all)
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

      // Ask the router, exactly as the link check does. Judging this by
      // the enumerated set said "no route serves that path" about a
      // perfectly working `/en/products/:slug` URL — the same false
      // positive `link.broken` had, from the same cause.
      if (matchSeoRoute(routes, target) == null) {
        yield SeoFinding(
          check: SeoCheck.hreflangUnknownTarget,
          severity: SeoSeverity.error,
          path: path,
          message: 'an hreflang alternate points at a path no route serves',
          detail: '${alternate.key} → ${alternate.value}',
        );
        continue;
      }

      // Reciprocity can only be decided for a page that was actually
      // resolved. A URL served by an un-enumerated pattern is not in the
      // set, and it does not follow that it fails to link back.
      if (!byPath.containsKey(target)) continue;

      final other = alternatesByPath[target];
      if (other == null ||
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
  // Grouped case- and whitespace-insensitively: search engines treat
  // 'Home — Meine Seite' and 'home  — meine seite' as the same title,
  // and the templating slips this check exists for produce exactly
  // that kind of near-duplicate.
  final byValue = <String, List<String>>{};
  final original = <String, String>{};
  for (final page in pages) {
    final value = valueOf(page);
    if (value == null || value.isEmpty) continue;
    final key = value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    byValue.putIfAbsent(key, () => []).add(page.path);
    original[key] = value;
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
            '"${original[entry.key]}" — also ${entry.value.where((p) => p != path).join(', ')}',
      );
    }
  }
}

// ───────────────────────────── helpers ─────────────────────────────

String _stripSlash(String url) =>
    url.endsWith('/') ? url.substring(0, url.length - 1) : url;

/// Whether a path is a page rather than an asset — the same rule
/// `seoBotMiddleware` uses: a dot in the last segment means
/// `main.dart.js`, `favicon.png`, `whitepaper.pdf`.
bool _looksLikePage(String path) => !path.split('/').last.contains('.');

/// Whether a schema property is effectively absent — missing, or
/// present as an empty string, which JSON-LD consumers treat the same.
bool _isBlank(Object? value) =>
    value == null ||
    (value is String && value.trim().isEmpty) ||
    (value is Iterable && value.isEmpty) ||
    (value is Map && value.isEmpty);

List<Map> _schemaMaps(Object? value) => [
      for (final item in value is List ? value : [value])
        if (item is Map) item,
    ];

/// URL schemes are case-insensitive — `HTTPS://` is as absolute as
/// `https://`, and crawlers treat it so.
bool _isAbsolute(String url) {
  final lower = url.toLowerCase();
  return lower.startsWith('http://') || lower.startsWith('https://');
}

/// Whether the pattern [general] matches every URL [specific] could
/// serve.
///
/// True for two patterns of the same shape — `/blog/:slug` then
/// `/blog/:id`, where the parameter name never takes part in matching —
/// but also for a strictly wider one: `/:section/:slug` declared before
/// `/blog/:slug` swallows it just as completely, and checking only for
/// equal shapes missed that entirely.
bool _swallows(String general, String specific) {
  final g = general.split('/');
  final s = specific.split('/');
  if (g.length != s.length) return false;
  for (var i = 0; i < g.length; i++) {
    if (g[i].startsWith(':')) {
      // A parameter matches any segment EXCEPT an empty one —
      // SeoRoute's matcher rejects those, so a pattern with an empty
      // literal segment is not swallowed by a param at that position.
      if (s[i].isEmpty) return false;
      continue;
    }
    if (g[i] != s[i]) return false;
  }
  return true;
}

/// The site-local path [href] points at, seen from [fromPath].
///
/// Returns `null` for external hosts, fragments and non-web schemes.
/// Route paths live in decoded space (`/über`), URLs in encoded space
/// (`/%C3%BCber`) — everything returned from here is decoded so the
/// two spellings of the same page compare equal.
String? _internalTarget(String href, String base, {String fromPath = '/'}) {
  if (href.isEmpty || href.startsWith('#')) return null;

  // A site-rooted path. When the site itself lives under a path prefix
  // (a GitHub Pages project site, `siteBase: https://user.github.io/repo`),
  // a rooted href escapes the site unless it carries the prefix.
  if (href.startsWith('/') && !href.startsWith('//')) {
    return _stripBasePrefix(
      _decodePath(href.split('#').first.split('?').first),
      base,
    );
  }

  // A document-relative link — `about`, `../agb`. These were skipped
  // entirely, so a relative link to nowhere was never reported. Resolve
  // it against the page it appears on, the way a browser would.
  // [fromPath] is already a route path, so no prefix handling here.
  if (!href.contains(':') && !href.startsWith('//')) {
    final bare = href.split('#').first.split('?').first;
    if (bare.isEmpty) return null;
    final resolved = Uri.parse(fromPath).resolve(bare).path;
    return normalizeSeoPath(_decodePath(resolved.isEmpty ? '/' : resolved));
  }

  // Absolute URLs are compared by parsed host, not by string prefix:
  // `https://x.dev.evil.com/` starts with `https://x.dev` and is a
  // different site entirely.
  final parsed = Uri.tryParse(href);
  final origin = Uri.tryParse(base);
  if (parsed == null || origin == null) return null;
  // `//x.dev/agb` is scheme-relative: the same site, borrowing the
  // page's scheme — a browser follows it, so the audit checks it.
  final target =
      parsed.hasScheme ? parsed : parsed.replace(scheme: origin.scheme);
  if (target.host.isEmpty) return null;
  if (!const {'http', 'https'}.contains(target.scheme)) return null;
  if (target.scheme != origin.scheme) return null;
  if (target.host.toLowerCase() != origin.host.toLowerCase()) return null;
  // Uri fills in the scheme's default, so this also separates an
  // explicit `:8443` from an implicit `:443` — a different origin,
  // however similar the URL looks. Comparing only when both sides
  // named a port let that one through as internal.
  if (target.port != origin.port) return null;
  return _stripBasePrefix(
    _decodePath(target.path.isEmpty ? '/' : target.path),
    base,
  );
}

/// Percent-escapes decoded, invalid ones left alone. `Uri.path` returns
/// `/%C3%BCber` for a page the route table declares as `/über`; without
/// decoding, the package's own derived canonical failed its own audit.
String _decodePath(String path) {
  return normalizeSeoPath([
    for (final segment in path.split('/')) _decodePathSegment(segment),
  ].join('/'));
}

String _decodePathSegment(String segment) {
  try {
    // Preserve route boundaries. A URL segment `a%2Fb` may be captured as the
    // parameter `a/b`, but it is not the two-segment route `/a/b`.
    return Uri.decodeComponent(segment).replaceAll('/', '%2F');
  } on FormatException {
    return segment;
  } on ArgumentError {
    return segment;
  }
}

/// Maps a full URL path into route space when [base] carries a path
/// prefix, or returns it unchanged when it does not.
///
/// `https://user.github.io/repo/about` is the route `/about` of a site
/// based at `…/repo` — treating the prefix as part of the route failed
/// EVERY page of a subpath deployment through the auto-derived
/// canonical. A same-host path outside the prefix is not this site.
String? _stripBasePrefix(String path, String base) {
  final origin = Uri.tryParse(base);
  final prefix = origin == null ? '' : _stripSlash(_decodePath(origin.path));
  if (prefix.isEmpty) return normalizeSeoPath(path);
  if (path == prefix) return '/';
  if (path.startsWith('$prefix/')) {
    return normalizeSeoPath(path.substring(prefix.length));
  }
  return null;
}

/// The robots signal, not sitemap membership: `noindex` or `none`.
bool _isNoindex(SeoMeta meta) {
  final robots = meta.robots?.toLowerCase() ?? '';
  return robots.contains('noindex') ||
      robots.split(',').map((d) => d.trim()).contains('none');
}

bool _sameUrl(String url, String selfUrl, String base, String path) {
  if (url == selfUrl) return true;
  final target = _internalTarget(url, base);
  return target != null && target == path;
}
