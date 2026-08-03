// The audit, wired up the way the README recommends: a plain test in
// the suite you already run. No new CI job, no build step — it reads
// the route table directly, so it catches a broken link or a shadowed
// route before `flutter build web` has done any work.
import 'package:esen_seo/server.dart';
import 'package:example/seo_routes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the site has no SEO errors', () async {
    final report = await auditSeoRoutes(routes: seoRoutes, siteBase: siteBase);

    // describe() as the reason, so a failure prints the whole report
    // instead of just "expected true".
    expect(report.passes(), isTrue, reason: '\n${report.describe()}');
  });

  test('every page is reachable and indexable', () async {
    final report = await auditSeoRoutes(routes: seoRoutes, siteBase: siteBase);
    expect(report.pagesAudited, greaterThan(0));
    expect(
      report.partial,
      isFalse,
      reason: 'a page failed to resolve, so the audit is incomplete:\n'
          '${report.describe()}',
    );
  });

  test('warnings are visible but do not fail the build', () async {
    // The example deliberately keeps a few short descriptions. They are
    // worth seeing and not worth blocking a release over — which is the
    // whole reason severity exists.
    final report = await auditSeoRoutes(routes: seoRoutes, siteBase: siteBase);
    expect(report.errorCount, 0, reason: '\n${report.describe()}');
    printOnFailure(report.describe());
  });
}
