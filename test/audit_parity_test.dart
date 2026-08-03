import 'package:esen_seo/esen_seo.dart';
import 'package:esen_seo/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _base = 'https://x.dev';

Set<String> _ids(SeoAuditReport r) => {for (final f in r.findings) f.check.id};

void main() {
  group('compareSeoTrees (pure — no widget needed)', () {
    test('identical trees produce nothing', () {
      final tree = [
        SeoNode(tag: 'h1', text: 'Willkommen'),
        SeoNode(tag: 'p', text: 'Ein Absatz Text.'),
      ];
      expect(
        compareSeoTrees(path: '/', ssr: tree, app: tree),
        isEmpty,
      );
    });

    test('a different h1 is the headline failure', () {
      final findings = compareSeoTrees(
        path: '/',
        ssr: [SeoNode(tag: 'h1', text: 'Rotes Rennrad')],
        app: [SeoNode(tag: 'h1', text: 'Blaues Rennrad')],
      );
      expect(_idsOf(findings), contains('parity.h1-differs'));
      expect(findings.first.severity, SeoSeverity.error);
    });

    test('text sent only to crawlers is cloaking, however accidental', () {
      final findings = compareSeoTrees(
        path: '/',
        ssr: [
          SeoNode(tag: 'h1', text: 'Angebot'),
          SeoNode(tag: 'p', text: 'Nur fuer Suchmaschinen sichtbarer Text.'),
        ],
        app: [SeoNode(tag: 'h1', text: 'Angebot')],
      );
      expect(_idsOf(findings), contains('parity.ssr-only-text'));
      expect(
        findings
            .firstWhere((f) => f.check == SeoCheck.paritySsrOnlyText)
            .severity,
        SeoSeverity.error,
      );
    });

    test('a heading only the app shows means the route body went stale', () {
      final findings = compareSeoTrees(
        path: '/',
        ssr: [SeoNode(tag: 'h1', text: 'Titel')],
        app: [
          SeoNode(tag: 'h1', text: 'Titel'),
          SeoNode(tag: 'h2', text: 'Neuer Abschnitt'),
        ],
      );
      expect(_idsOf(findings), contains('parity.app-only-heading'));
      // A warning, not an error: the app may legitimately show more.
      expect(
        findings
            .firstWhere((f) => f.check == SeoCheck.parityAppOnlyHeading)
            .severity,
        SeoSeverity.warning,
      );
    });

    test('whitespace and case are not content differences', () {
      final findings = compareSeoTrees(
        path: '/',
        ssr: [SeoNode(tag: 'h1', text: 'Rotes   Rennrad')],
        app: [SeoNode(tag: 'h1', text: 'rotes rennrad')],
      );
      expect(findings, isEmpty);
    });

    test('ignoreText silences a cookie banner on both sides', () {
      final findings = compareSeoTrees(
        path: '/',
        ssr: [SeoNode(tag: 'h1', text: 'Titel')],
        app: [
          SeoNode(tag: 'h1', text: 'Titel'),
          SeoNode(tag: 'h2', text: 'Cookie-Hinweis'),
        ],
        policy: const SeoParityPolicy(ignoreText: {'Cookie'}),
      );
      expect(findings, isEmpty);
    });
  });

  group('auditSeoParity (against a real pumped app)', () {
    List<SeoRoute> routes(String serverHeadline) => [
          SeoRoute(
            path: '/',
            meta: (_) => const SeoMeta(
              title: 'Eine ganz gewoehnliche Startseite',
              description: 'Eine Beschreibung, die bequem in das Fenster '
                  'passt, das Suchmaschinen tatsaechlich anzeigen.',
            ),
            body: (_) => [SeoNode(tag: 'h1', text: serverHeadline)],
          ),
        ];

    Widget app(String appHeadline) => MaterialApp(
          home: Scaffold(body: Text(appHeadline).h1),
        );

    testWidgets('agreeing trees pass', (tester) async {
      final report = await auditSeoParity(
        routes: routes('Willkommen'),
        siteBase: _base,
        paths: const ['/'],
        pump: (_) async {
          await tester.pumpWidget(app('Willkommen'));
          await tester.pumpAndSettle();
        },
      );
      expect(report.passes(), isTrue, reason: report.describe());
      expect(report.pagesAudited, 1);
    });

    testWidgets('a widget edited without the route table is caught',
        (tester) async {
      // The realistic failure: someone renames the headline in the
      // widget and forgets the route body. Nothing else in the package
      // can notice — the two trees come from different code.
      final report = await auditSeoParity(
        routes: routes('Alter Titel'),
        siteBase: _base,
        paths: const ['/'],
        pump: (_) async {
          await tester.pumpWidget(app('Neuer Titel'));
          await tester.pumpAndSettle();
        },
      );
      expect(_ids(report), contains('parity.h1-differs'));
      expect(report.passes(), isFalse);
      expect(report.describe(), contains('Alter Titel'));
    });

    testWidgets('pages nobody checked are named, not silently skipped',
        (tester) async {
      final report = await auditSeoParity(
        routes: [
          ...routes('Willkommen'),
          SeoRoute(
            path: '/docs',
            meta: (_) => const SeoMeta(title: 'Dokumentation lesen'),
          ),
        ],
        siteBase: _base,
        paths: const ['/'],
        pump: (_) async {
          await tester.pumpWidget(app('Willkommen'));
          await tester.pumpAndSettle();
        },
      );
      // A shrinking sample must not quietly become no sample.
      expect(_ids(report), contains('parity.not-covered'));
      expect(report.describe(), contains('/docs'));
    });
  });
}

Set<String> _idsOf(List<SeoFinding> findings) =>
    {for (final f in findings) f.check.id};
