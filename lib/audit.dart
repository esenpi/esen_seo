/// The SEO auditor — pure Dart, no Flutter, no `dart:io`.
///
/// It answers one question: *is this site actually SEO-correct?* — and
/// it answers it from the **route table**, before anything is built.
/// The package owns that table, so it already knows every URL, every
/// title and every node the server will render. A broken internal link
/// is an `href` that `matchSeoRoute` cannot match; nothing has to be
/// crawled and no HTML has to be parsed.
///
/// What it catches is the class of mistake the renderer *cannot* catch,
/// because each one is a perfectly legal use of the API:
///
/// - a `robots: 'noindex'` page that is still listed in `sitemap.xml`,
/// - a concrete route shadowed by a `:param` pattern declared before it,
///   so the page never runs while the sitemap still advertises its URL,
/// - a `canonicalUrl` the URL policy refuses — which leaves the page
///   with *no* canonical, and suppresses the automatic one as well,
/// - a schema value that JSON cannot encode, which throws when the page
///   renders rather than when the table is written.
///
/// Put it in a test and it runs in the CI you already have:
///
/// ```dart
/// test('the site is SEO-healthy', () async {
///   assertSeoHealthy(
///     await auditSeoRoutes(routes: seoRoutes, siteBase: siteBase),
///   );
/// });
/// ```
///
/// Use [assertSeoHealthy] rather than writing the comparison by hand.
/// An earlier version of this comment suggested
/// `expect(report.describe(), isNot(contains('[error]')))`, which never
/// failed — `describe()` marks an error with `x`, not with `[error]` —
/// so the recommended test passed on a broken site.
///
/// Or run it from a script, the same way `prerenderSite` is run:
///
/// ```dart
/// // bin/seo_audit.dart
/// final report = await auditSeoRoutes(routes: seoRoutes, siteBase: siteBase);
/// stdout.write(report.describe());
/// exit(report.passes() ? 0 : 1);
/// ```
library;

export 'src/audit/audit_engine.dart' show auditSeoPages, auditSeoRoutes;
export 'src/audit/expect_healthy.dart' show SeoAuditFailure, assertSeoHealthy;
export 'src/audit/seo_audit_policy.dart' show SeoAuditPolicy;
export 'src/audit/seo_audit_report.dart' show SeoAuditReport;
export 'src/audit/seo_finding.dart' show SeoCheck, SeoFinding, SeoSeverity;
