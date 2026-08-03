import 'seo_audit_report.dart';
import 'seo_finding.dart';

/// Thrown by [assertSeoHealthy] when a report does not pass.
///
/// Carries the whole report in its message, because a bare "expected
/// true" tells a developer nothing about which page is wrong.
class SeoAuditFailure implements Exception {
  SeoAuditFailure(this.report, this.threshold);

  final SeoAuditReport report;
  final SeoSeverity threshold;

  @override
  String toString() => 'The SEO audit found problems at '
      '${threshold.name} severity or worse:\n\n${report.describe()}';
}

/// Throws [SeoAuditFailure] unless [report] passes at [threshold].
///
/// The one call a test needs:
///
/// ```dart
/// test('the site has no SEO errors', () async {
///   assertSeoHealthy(
///     await auditSeoRoutes(routes: seoRoutes, siteBase: siteBase),
///   );
/// });
/// ```
///
/// It exists because the obvious hand-written alternative is easy to
/// get wrong in a way that always passes — this package shipped a doc
/// comment recommending `expect(report.describe(), isNot(contains(
/// '[error]')))`, which never failed, because `describe()` marks errors
/// with `x`. A helper that owns the comparison cannot drift from the
/// format it is comparing against.
void assertSeoHealthy(
  SeoAuditReport report, {
  SeoSeverity threshold = SeoSeverity.error,
}) {
  if (!report.passes(threshold: threshold)) {
    throw SeoAuditFailure(report, threshold);
  }
}
