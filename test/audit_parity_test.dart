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

    test('an app shell with its own h1 does not mean the page differs', () {
      // Smart defaults turn an untagged brand text into an <h1>, so the
      // app tree legitimately carries a heading the route body never
      // will. Comparing first-to-first made every shell a build failure.
      final findings = compareSeoTrees(
        path: '/',
        ssr: [SeoNode(tag: 'h1', text: 'Willkommen')],
        app: [
          SeoNode(tag: 'h1', text: 'esen_seo'), // the shell's brand
          SeoNode(tag: 'h1', text: 'Willkommen'), // the actual page
        ],
      );
      expect(_idsOf(findings), isNot(contains('parity.h1-differs')));
      // The extra heading is still surfaced — as a warning.
      expect(_idsOf(findings), contains('parity.app-only-heading'));
    });

    test('an inactive Navigator route left in the tree is tolerated', () {
      // Flutter keeps the previous page mounted after a push, so its
      // h1 is still in the captured tree.
      final findings = compareSeoTrees(
        path: '/b',
        ssr: [SeoNode(tag: 'h1', text: 'Seite B')],
        app: [
          SeoNode(tag: 'h1', text: 'Seite A'),
          SeoNode(tag: 'h1', text: 'Seite B'),
        ],
      );
      expect(_idsOf(findings), isNot(contains('parity.h1-differs')));
    });

    test('punctuation and typography are not content differences', () {
      for (final (ssr, app) in [
        ('Flutter Web richtig indexieren', 'Flutter Web richtig indexieren!'),
        ('Jetzt starten.', 'Jetzt starten'),
        ('Das "beste" Werkzeug', 'Das “beste” Werkzeug'),
      ]) {
        final findings = compareSeoTrees(
          path: '/',
          ssr: [SeoNode(tag: 'p', text: ssr)],
          app: [SeoNode(tag: 'p', text: app)],
        );
        expect(findings, isEmpty, reason: '"$ssr" vs "$app"');
      }
    });

    test('genuinely missing text is still caught', () {
      final findings = compareSeoTrees(
        path: '/',
        ssr: [SeoNode(tag: 'p', text: 'Nur fuer Suchmaschinen bestimmt')],
        app: [SeoNode(tag: 'p', text: 'Etwas ganz anderes')],
      );
      expect(_idsOf(findings), contains('parity.ssr-only-text'));
    });

    test('whitespace and case are not content differences', () {
      final findings = compareSeoTrees(
        path: '/',
        ssr: [SeoNode(tag: 'h1', text: 'Rotes   Rennrad')],
        app: [SeoNode(tag: 'h1', text: 'rotes rennrad')],
      );
      expect(findings, isEmpty);
    });

    test('the app rendering the headline as a <p> is a difference', () {
      // The sharpest case, and the one the earlier guard let through: the
      // words are all there, so the text check finds nothing missing, and
      // the app has no <h1> at all, so a check that only ran when one
      // existed skipped silently. The page really does differ — the
      // server promises a heading the app never delivers.
      final findings = compareSeoTrees(
        path: '/',
        ssr: [SeoNode(tag: 'h1', text: 'Willkommen bei esen_seo')],
        app: [SeoNode(tag: 'p', text: 'Willkommen bei esen_seo')],
      );
      expect(_idsOf(findings), contains('parity.h1-differs'));
      expect(
        findings.first.message,
        contains('not as a heading'),
      );
    });

    test('words scattered across the app are not the passage', () {
      // The bag-of-words comparison passed this: every word of the SSR
      // passage exists somewhere in the app — one in the nav, one in a
      // footnote — but the passage itself was never delivered.
      final findings = compareSeoTrees(
        path: '/',
        ssr: [
          SeoNode(tag: 'p', text: 'Kostenlose Lieferung ab fünfzig Euro'),
        ],
        app: [
          SeoNode(tag: 'p', text: 'Kostenlose Beratung'),
          SeoNode(tag: 'p', text: 'Lieferung morgen'),
          SeoNode(tag: 'p', text: 'ab Lager verfügbar'),
          SeoNode(tag: 'p', text: 'fünfzig Filialen'),
          SeoNode(tag: 'p', text: 'Euro und Dollar'),
        ],
      );
      expect(_idsOf(findings), contains('parity.ssr-only-text'));
    });

    test('overlapping pairs do not impersonate one contiguous passage', () {
      // Both pairs "buy now" and "now free" occur, but never together.
      final findings = compareSeoTrees(
        path: '/',
        ssr: [SeoNode(tag: 'p', text: 'buy now free')],
        app: [SeoNode(tag: 'p', text: 'buy now later now free')],
      );
      expect(_idsOf(findings), contains('parity.ssr-only-text'));
      expect(
        findings
            .firstWhere((f) => f.check == SeoCheck.paritySsrOnlyText)
            .severity,
        SeoSeverity.warning,
      );
    });

    test('a passage split across adjacent nodes still counts as delivered', () {
      // The tolerance the old check existed for must survive: wording
      // that merely moved between nodes — a sentence split over two
      // spans — is not a content difference.
      final findings = compareSeoTrees(
        path: '/',
        ssr: [
          SeoNode(tag: 'p', text: 'Flutter Web richtig indexieren lassen'),
        ],
        app: [
          SeoNode(tag: 'span', text: 'Flutter Web'),
          SeoNode(tag: 'span', text: 'richtig indexieren lassen'),
        ],
      );
      expect(findings, isEmpty, reason: findings.join('\n'));
    });

    test('a pathologically deep tree reports truncation, not a crash', () {
      SeoNode deep(int n) => n == 0
          ? SeoNode(tag: 'p', text: 'Grund')
          : SeoNode(tag: 'div', children: [deep(n - 1)]);
      final findings = compareSeoTrees(
        path: '/',
        ssr: [SeoNode(tag: 'p', text: 'Oben'), deep(5000)],
        app: [SeoNode(tag: 'p', text: 'Oben')],
      );
      expect(_idsOf(findings), contains('body.truncated'));
      expect(findings.single.severity, SeoSeverity.error);
      // And nothing else: with the deep half of one tree unseen,
      // "this text reaches only crawlers" would be a confident error
      // about content nobody compared.
      expect(_idsOf(findings), isNot(contains('parity.ssr-only-text')),
          reason: findings.join('\n'));
    });

    test('an inline icon inside a sentence is not cloaking', () {
      // Text.rich flattens a WidgetSpan to U+FFFC. Treating it as a
      // word severed the surrounding passage and reported the text as
      // error-severity cloaking — on identical visible text.
      final findings = compareSeoTrees(
        path: '/',
        ssr: [SeoNode(tag: 'p', text: 'Rated 4.8 by 200 users')],
        app: [SeoNode(tag: 'p', text: 'Rated 4.8 ￼ by 200 users')],
      );
      expect(findings, isEmpty, reason: findings.join('\n'));
    });

    test('scattered words are a warning, absent words an error', () {
      // A Row of Columns interleaves label and value runs in tree
      // order — 'Gewicht', 'Rahmen', '8 kg', 'Carbon' — so the prose
      // passage exists on screen but not as adjacent tokens. Failing
      // the build over that teaches teams to turn the check off; words
      // that are genuinely GONE still must fail it.
      final scattered = compareSeoTrees(
        path: '/',
        ssr: [
          SeoNode(tag: 'p', text: 'Gewicht: 8 kg'),
          SeoNode(tag: 'p', text: 'Rahmen: Carbon'),
        ],
        app: [
          SeoNode(tag: 'span', text: 'Gewicht'),
          SeoNode(tag: 'span', text: 'Rahmen'),
          SeoNode(tag: 'span', text: '8 kg'),
          SeoNode(tag: 'span', text: 'Carbon'),
        ],
      );
      expect(_idsOf(scattered), contains('parity.ssr-only-text'));
      expect(
        scattered
            .firstWhere((f) => f.check == SeoCheck.paritySsrOnlyText)
            .severity,
        SeoSeverity.warning,
        reason: scattered.join('\n'),
      );

      final gone = compareSeoTrees(
        path: '/',
        ssr: [SeoNode(tag: 'p', text: 'Nur fuer Suchmaschinen bestimmt')],
        app: [SeoNode(tag: 'p', text: 'Etwas ganz anderes')],
      );
      expect(
        gone.firstWhere((f) => f.check == SeoCheck.paritySsrOnlyText).severity,
        SeoSeverity.error,
      );
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

    testWidgets('a path served by an un-enumerated :param route is checked',
        (tester) async {
      // It used to be skipped with a warning claiming the table does
      // not serve it — which was untrue, and meant pagesAudited was 0
      // while the test looked like it had passed.
      final report = await auditSeoParity(
        routes: [
          SeoRoute(
            path: '/products/:slug',
            meta: (p) => SeoMeta(title: 'Produkt ${p['slug']} ansehen'),
            body: (p) => [SeoNode(tag: 'h1', text: 'Produkt ${p['slug']}')],
          ),
        ],
        siteBase: _base,
        paths: const ['/products/rennrad'],
        pump: (_) async {
          await tester.pumpWidget(app('Produkt rennrad'));
          await tester.pumpAndSettle();
        },
      );
      expect(report.pagesAudited, 1);
      expect(_ids(report), isNot(contains('parity.not-covered')));
      expect(report.passes(), isTrue, reason: report.describe());
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
      // Still a pass: sampling is the caller's call, as long as they
      // sampled something.
      expect(report.passes(), isTrue);
    });

    testWidgets('checking nothing at all is a failure, not a pass',
        (tester) async {
      // `paths: []` used to be a green run that proved nothing — an
      // "info" finding cannot hold up the claim this file makes.
      final report = await auditSeoParity(
        routes: routes('Willkommen'),
        siteBase: _base,
        paths: const [],
        pump: (_) async {
          await tester.pumpWidget(app('Willkommen'));
          await tester.pumpAndSettle();
        },
      );
      expect(report.passes(), isFalse, reason: report.describe());
      expect(report.describe(), contains('proves nothing'));
    });
  });
}

Set<String> _idsOf(List<SeoFinding> findings) =>
    {for (final f in findings) f.check.id};
