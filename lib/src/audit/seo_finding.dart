/// What an audit found, and how much it matters.
///
/// The audit exists because the package cannot prevent these by
/// construction: they are all legitimate uses of the API that happen to
/// be wrong for SEO. A `robots: 'noindex'` page really can sit in the
/// sitemap, a concrete route really can be shadowed by a `:param`
/// pattern declared before it, a `canonicalUrl` the URL policy refuses
/// really does leave the page with no canonical at all. Nothing in the
/// renderer can tell those apart from what the author meant.
library;

/// How much a finding matters.
///
/// The split is not cosmetic: [error] is what `--fail-on=error` (and
/// `expectSeoHealthy`) fails a build on, so the line has to be drawn
/// where a false positive would be intolerable.
enum SeoSeverity {
  /// Something is measurably wrong and costs indexing: a page with no
  /// title, a link to nowhere, a canonical pointing at a 404.
  error,

  /// Very likely wrong, but a legitimate site can look like this — two
  /// pages sharing a title may be paginated variants.
  warning,

  /// Worth a look, never a reason to fail a build: title length, a
  /// skipped heading level.
  info,
}

/// The identity of a check, e.g. `title.missing`.
///
/// An extension type over [String], matching the `SeoTextTag` idiom
/// already in the package: the ids autocomplete and a typo is a compile
/// error, but they stay plain strings in JSON output and in a
/// `--ignore=` list.
extension type const SeoCheck(String id) implements String {
  // Metadata
  static const titleMissing = SeoCheck('title.missing');
  static const titleDuplicate = SeoCheck('title.duplicate');
  static const titleLength = SeoCheck('title.length');
  static const descriptionMissing = SeoCheck('description.missing');
  static const descriptionDuplicate = SeoCheck('description.duplicate');
  static const descriptionLength = SeoCheck('description.length');

  // Canonical and indexing signals
  static const urlRejectedByPolicy = SeoCheck('url.rejected-by-policy');
  static const canonicalRelative = SeoCheck('canonical.relative');
  static const canonicalUnknownPath = SeoCheck('canonical.unknown-path');
  static const robotsNoindexInSitemap = SeoCheck('robots.noindex-in-sitemap');
  static const sitemapEmpty = SeoCheck('sitemap.empty');

  // The route table itself
  static const routeShadowed = SeoCheck('route.shadowed');
  static const routeDuplicatePath = SeoCheck('route.duplicate-path');
  static const routeNotEnumerated = SeoCheck('route.not-enumerated');
  static const resolverFailed = SeoCheck('resolver.failed');

  // Document structure
  static const bodyEmpty = SeoCheck('body.empty');
  static const headingNoH1 = SeoCheck('heading.no-h1');
  static const headingMultipleH1 = SeoCheck('heading.multiple-h1');

  // Media and links
  static const imageAltMissing = SeoCheck('image.alt-missing');
  static const imageSrcMissing = SeoCheck('image.src-missing');
  static const linkBroken = SeoCheck('link.broken');
  static const linkToError = SeoCheck('link.to-error');
  static const linkEmptyHref = SeoCheck('link.empty-href');
  static const linkNoText = SeoCheck('link.no-text');

  // Translations
  static const hreflangMissingSelf = SeoCheck('hreflang.missing-self');
  static const hreflangNotReciprocal = SeoCheck('hreflang.not-reciprocal');
  static const hreflangUnknownTarget = SeoCheck('hreflang.unknown-target');

  // Structured data
  static const schemaInvalidJson = SeoCheck('schema.invalid-json');
  static const schemaMissingRequired = SeoCheck('schema.missing-required');
  static const schemaRelativeUrl = SeoCheck('schema.relative-url');

  // Parity — does the app render what the server claims?
  //
  // These need a pumped widget tree, so they come from
  // `auditSeoParity` in package:esen_seo/testing.dart rather than from
  // the pure-Dart engine.
  static const paritySsrOnlyText = SeoCheck('parity.ssr-only-text');
  static const parityH1Differs = SeoCheck('parity.h1-differs');
  static const parityAppOnlyHeading = SeoCheck('parity.app-only-heading');
  static const parityLinkMissingInApp = SeoCheck('parity.link-missing-in-app');
  static const parityNotCovered = SeoCheck('parity.not-covered');
}

/// One problem, on one page.
class SeoFinding {
  const SeoFinding({
    required this.check,
    required this.severity,
    required this.message,
    this.path,
    this.detail,
  });

  /// Which check produced this — stable across versions, so it can be
  /// suppressed by id.
  final SeoCheck check;

  final SeoSeverity severity;

  /// One sentence saying what is wrong, in terms of the author's own
  /// route table rather than of the audit's internals.
  final String message;

  /// The page it applies to; `null` for site-wide findings such as
  /// [SeoCheck.sitemapEmpty].
  final String? path;

  /// The offending value, when quoting it helps — the duplicate title,
  /// the href that matched nothing.
  final String? detail;

  /// A stable identity for deduplication and for "did this finding
  /// already exist" comparisons between runs.
  String get fingerprint => '$check|${path ?? ''}|${detail ?? ''}';

  Map<String, Object?> toJson() => {
        'check': check.id,
        'severity': severity.name,
        'message': message,
        if (path != null) 'path': path,
        if (detail != null) 'detail': detail,
      };

  @override
  String toString() {
    final where = path == null ? '' : ' $path';
    final what = detail == null ? '' : ' — $detail';
    return '[${severity.name}] ${check.id}$where: $message$what';
  }
}
