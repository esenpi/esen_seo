import 'package:flutter/widgets.dart';

import '../audit/parity_compare.dart';
import '../audit/seo_audit_report.dart';
import '../audit/seo_finding.dart';
import '../controller/seo_controller.dart';
import '../renderer/seo_node.dart';
import '../routing/seo_resolution.dart';
import '../routing/seo_resolved_page.dart';
import '../routing/seo_route.dart';

/// Captures the semantic mirror of whatever is currently mounted.
///
/// The audit's other half. Everything the pure-Dart engine checks comes
/// from the route table, which means it can only ever confirm that the
/// table agrees with itself. This is the one check that compares the
/// table against the thing users actually see.
///
/// Turns the controller on first: `.seo()` extensions read
/// `SeoController.enabled` at **build** time, so a tree pumped before
/// that is switched on carries no markers at all and every comparison
/// would come back empty — passing for the wrong reason.
List<SeoNode> captureSeoNodes() {
  final root = WidgetsBinding.instance.rootElement;
  if (root == null) {
    throw StateError(
      'captureSeoNodes() found no widget tree — pump one first.',
    );
  }
  return SeoController.instance.collectNodes(root);
}

/// Prepares the SEO pipeline for a parity test.
///
/// Call this **before** `pumpWidget`. In a widget test `kIsWeb` is
/// false, so the mirror is off by default and every `.seo()` call is a
/// no-op; without this the captured tree is empty.
void enableSeoForParity() {
  SeoController.debugForceEnable = true;
  SeoController.instance.resetForTest();
}

/// Checks that the app renders what the route table promises.
///
/// [pump] is called once per path and must mount the app at that route
/// — how is up to the caller's router:
///
/// ```dart
/// testWidgets('bots and users see the same pages', (tester) async {
///   final report = await auditSeoParity(
///     routes: seoRoutes,
///     siteBase: siteBase,
///     paths: const ['/', '/docs'],
///     pump: (path) async {
///       await tester.pumpWidget(MyApp(initialRoute: path));
///       await tester.pumpAndSettle();
///     },
///   );
///   expect(report.passes(), isTrue, reason: '\n${report.describe()}');
/// });
/// ```
///
/// Paths not covered by [paths] are reported once as
/// [SeoCheck.parityNotCovered] — a shrinking sample should not quietly
/// become no sample at all.
Future<SeoAuditReport> auditSeoParity({
  required List<SeoRoute> routes,
  required String siteBase,
  required List<String> paths,
  required Future<void> Function(String path) pump,
  SeoParityPolicy policy = const SeoParityPolicy(),
  List<String> additionalPaths = const [],
}) async {
  enableSeoForParity();

  final resolved = await resolveSeoPages(
    routes: routes,
    canonicalBase: siteBase,
    additionalPaths: additionalPaths,
    detail: SeoDetail.full,
  );
  final byPath = {for (final page in resolved) page.path: page};

  final findings = <SeoFinding>[];
  var covered = 0;

  final seen = <String>{};
  for (final rawPath in paths) {
    final path = normalizeSeoPath(rawPath);
    // The same path listed twice would pump twice and report every
    // finding twice.
    if (!seen.add(path)) continue;

    var page = byPath[path];
    if (page == null) {
      // Not in the enumeration is not the same as not served. A
      // `/products/:slug` route without `enumeratePaths` serves this URL
      // perfectly well, so resolve it on the spot instead of claiming
      // the table does not know it — which was simply untrue.
      final match = matchSeoRoute(routes, path);
      if (match != null) {
        page = SeoResolvedPage(
          path: path,
          route: match.route,
          params: match.params,
          resolution: await match.resolve(
            detail: SeoDetail.full,
            canonicalBase: siteBase,
          ),
        );
      }
    }
    if (page == null) {
      findings.add(SeoFinding(
        check: SeoCheck.parityNotCovered,
        severity: SeoSeverity.warning,
        path: path,
        message: 'asked to check parity for a path the route table does '
            'not serve',
      ));
      continue;
    }
    final document = page.document;
    if (document == null) continue; // a redirect has no body to compare

    await pump(path);
    covered++;

    findings.addAll(compareSeoTrees(
      path: path,
      ssr: document.body,
      app: captureSeoNodes(),
      policy: policy,
    ));
  }

  // Say plainly which indexable pages nobody looked at, so a sample
  // that quietly shrank to one route is visible in the report.
  final unchecked = [
    for (final page in resolved)
      if (page.isIndexable && !paths.map(normalizeSeoPath).contains(page.path))
        page.path,
  ];
  if (unchecked.isNotEmpty) {
    findings.add(SeoFinding(
      check: SeoCheck.parityNotCovered,
      severity: SeoSeverity.info,
      message: '${unchecked.length} indexable page(s) were not checked for '
          'parity',
      detail: unchecked.take(5).join(', '),
    ));
  }

  return SeoAuditReport(findings: findings, pagesAudited: covered);
}
