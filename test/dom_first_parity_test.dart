import 'package:esen_seo/esen_seo.dart';
import 'package:esen_seo/testing.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('parity audit does not grade a DOM-first route as unchecked',
      (tester) async {
    var pumpCount = 0;
    final report = await auditSeoParity(
      routes: [
        SeoRoute(
          path: '/dom',
          delivery: SeoRouteDelivery.domFirst,
          meta: (_) => const SeoMeta(title: 'DOM page'),
          body: (_) => [SeoNode(tag: 'h1', text: 'DOM page')],
        ),
      ],
      siteBase: 'https://x.dev',
      paths: const ['/dom'],
      pump: (_) async {
        pumpCount++;
        await tester.pumpWidget(const SizedBox());
      },
    );

    expect(report.passes(), isTrue, reason: report.describe());
    expect(report.pagesAudited, 0);
    expect(pumpCount, 0);
    expect(report.findings, isEmpty);
  });

  testWidgets('DOM-first pages do not hide missing Flutter parity coverage',
      (tester) async {
    final report = await auditSeoParity(
      routes: [
        SeoRoute(
          path: '/dom',
          delivery: SeoRouteDelivery.domFirst,
          meta: (_) => const SeoMeta(title: 'DOM page'),
          body: (_) => [SeoNode(tag: 'h1', text: 'DOM page')],
        ),
        SeoRoute(
          path: '/flutter',
          meta: (_) => const SeoMeta(title: 'Flutter page'),
          body: (_) => [SeoNode(tag: 'h1', text: 'Flutter page')],
        ),
      ],
      siteBase: 'https://x.dev',
      paths: const ['/dom'],
      pump: (_) async => tester.pumpWidget(const SizedBox()),
    );

    expect(report.passes(), isFalse);
    expect(report.describe(), contains('/flutter'));
    expect(report.describe(), isNot(contains('/dom,')));
  });
}
