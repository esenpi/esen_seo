import 'dart:io';

import 'package:esen_seo/esen_seo.dart';
import 'package:esen_seo/server.dart' show prerenderSite;
import 'package:esen_seo/src/controller/seo_controller.dart';
import 'package:esen_seo/src/renderer/seo_container.dart';
import 'package:esen_seo/src/renderer/seo_stylesheet.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

const _template = '''
<!DOCTYPE html>
<html>
<head>
  <base href="/">
  <meta charset="UTF-8">
  <title>example</title>
</head>
<body>
  <script src="flutter_bootstrap.js" async></script>
</body>
</html>
''';

List<SeoRoute> _routes() => [
      SeoRoute(
        path: '/',
        meta: (_) => const SeoMeta(title: 'Home'),
        body: (_) => [SeoNode(tag: 'h1', text: 'Willkommen')],
      ),
    ];

void main() {
  group('seoContainerHtml', () {
    test('seoOnly stays byte-identical to the previous behaviour', () {
      expect(
        seoContainerHtml('<h1>Hi</h1>'),
        '<div id="esen-seo-content" aria-hidden="true" inert '
        'style="position:absolute;top:0;left:0;width:0;height:0;'
        'overflow:hidden;pointer-events:none;"><h1>Hi</h1></div>',
      );
    });

    test('visibleShell drops aria-hidden and covers the viewport', () {
      final html =
          seoContainerHtml('<h1>Hi</h1>', mode: SeoRenderMode.visibleShell);
      expect(html, contains('id="esen-seo-content"'));
      // Der Shell IST in dieser Phase der echte Inhalt:
      expect(html, isNot(contains('aria-hidden')));
      // Marker, an dem der Injector den Handoff erkennt:
      expect(html, contains('data-esen-seo-shell="visible"'));
      expect(html, contains('<h1>Hi</h1>'));
      // Deckt Flutters leere Boot-Oberfläche ab:
      expect(html, contains('position:fixed'));
      expect(html, contains('z-index:9999'));
    });

    test('the shell carries its transition from the start', () {
      // Die Blende darf beim Handoff nur noch die Opazität ändern —
      // eine erst dann gesetzte transition würde nicht animieren.
      expect(seoShellStyle, contains('transition:opacity ${seoShellFadeMs}ms'));
      expect(seoShellStyle, isNot(contains('opacity:0')));
    });

    test('seoContainerStyleFor hides only in seoOnly mode', () {
      expect(seoContainerStyleFor(SeoRenderMode.seoOnly), seoContainerStyle);
      expect(seoContainerStyleFor(SeoRenderMode.visibleShell), seoShellStyle);
    });
  });

  group('stylesheet delivery', () {
    test('wraps CSS in a managed style tag', () {
      expect(
        seoStyleTagHtml('h1{color:red}'),
        '<style data-esen-seo-style>h1{color:red}</style>',
      );
    });

    test('uses its own marker so setMeta cannot wipe the styles', () {
      // injectMetaNodes ersetzt alles mit data-esen-seo — der Shell darf
      // seine Styles nicht mittendrin verlieren.
      expect(seoStyleTagHtml('a{}'), contains(seoStyleAttribute));
      expect(seoStyleTagHtml('a{}'), isNot(contains('<style data-esen-seo>')));
    });

    test('neutralizes </style> so CSS cannot break out', () {
      final css = seoStyleTagHtml('h1::after{content:"</style><b>x</b>"}');
      expect(css, isNot(contains('</style><b>')));
      expect(css, contains(r'\3c /style'));
      // Genau ein schließendes Tag — das eigene:
      expect('</style>'.allMatches(css), hasLength(1));
    });

    test('leaves legitimate CSS characters untouched', () {
      const css = 'a > b{color:red}@media (400px <= width){a{color:blue}}';
      expect(escapeStylesheet(css), css);
    });

    test('the default stylesheet is scoped and safe to inline', () {
      expect(seoDefaultStylesheet, contains('#esen-seo-content'));
      expect(seoDefaultStylesheet, isNot(contains('</style')));
      // Nichts außerhalb des Containers anfassen:
      expect(seoDefaultStylesheet, isNot(contains('\nbody{')));
      // Deckend, sonst scheint Flutters leere Oberfläche durch:
      expect(seoDefaultStylesheet, contains('background:#fff'));
    });
  });

  group('prerenderSite render modes', () {
    late Directory buildDir;

    setUp(() async {
      buildDir = await Directory.systemTemp.createTemp('esen_seo_shell');
      File('${buildDir.path}/index.html').writeAsStringSync(_template);
    });

    tearDown(() => buildDir.delete(recursive: true));

    test('default stays the invisible mirror without any CSS', () async {
      await prerenderSite(
        routes: _routes(),
        siteBase: 'https://x.dev',
        buildDir: buildDir.path,
      );
      final html = File('${buildDir.path}/index.html').readAsStringSync();
      expect(html, contains('aria-hidden="true"'));
      expect(html, isNot(contains('data-esen-seo-shell')));
      expect(html, isNot(contains('<style')));
    });

    test('visibleShell bakes a visible container plus inline CSS', () async {
      await prerenderSite(
        routes: _routes(),
        siteBase: 'https://x.dev',
        buildDir: buildDir.path,
        renderMode: SeoRenderMode.visibleShell,
        stylesheet: seoDefaultStylesheet,
      );
      final html = File('${buildDir.path}/index.html').readAsStringSync();

      // Sichtbarer Shell mit Handoff-Marker:
      expect(html, contains('data-esen-seo-shell="visible"'));
      expect(html, isNot(contains('aria-hidden="true"')));
      expect(html, contains('<h1>Willkommen</h1>'));

      // CSS inline im Head — vor </head> und vor dem Body:
      expect(html, contains('<style data-esen-seo-style>'));
      expect(
        html.indexOf('<style data-esen-seo-style>'),
        lessThan(html.indexOf('</head>')),
      );

      // Die Flutter-App bootet weiterhin:
      expect(html, contains('flutter_bootstrap.js'));
    });

    test('the 404 page follows the same mode', () async {
      await prerenderSite(
        routes: _routes(),
        siteBase: 'https://x.dev',
        buildDir: buildDir.path,
        renderMode: SeoRenderMode.visibleShell,
        stylesheet: 'h1{color:red}',
      );
      final html = File('${buildDir.path}/404.html').readAsStringSync();
      expect(html, contains('data-esen-seo-shell="visible"'));
      expect(
          html, contains('<style data-esen-seo-style>h1{color:red}</style>'));
    });

    test('refuses to prerender an already prerendered template', () async {
      await prerenderSite(
        routes: _routes(),
        siteBase: 'https://x.dev',
        buildDir: buildDir.path,
      );
      // Der zweite Lauf würde index.html als eigenes Template lesen und
      // Container, Canonical und JSON-LD verdoppeln.
      expect(
        () => prerenderSite(
          routes: _routes(),
          siteBase: 'https://x.dev',
          buildDir: buildDir.path,
        ),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('already prerendered'),
        )),
      );
      expect(
        'id="esen-seo-content"'
            .allMatches(File('${buildDir.path}/index.html').readAsStringSync()),
        hasLength(1),
      );
    });

    test('refuses route paths that escape the build directory', () async {
      // Mit einem CMS hinter den Routen kämen solche Pfade aus fremder
      // Hand — sie dürfen nicht außerhalb von build/web schreiben.
      expect(
        () => prerenderSite(
          routes: [
            SeoRoute(path: '/../entwischt', meta: (_) => const SeoMeta()),
          ],
          siteBase: 'https://x.dev',
          buildDir: buildDir.path,
        ),
        throwsArgumentError,
      );
      expect(
        () => prerenderSite(
          routes: _routes(),
          siteBase: 'https://x.dev',
          buildDir: buildDir.path,
          additionalPaths: ['/blog/../../weg'],
        ),
        throwsArgumentError,
      );
      expect(Directory('${buildDir.path}/../entwischt').existsSync(), isFalse);
    });

    test('refuses an IndexNow key that is not a plain file name', () async {
      expect(
        () => prerenderSite(
          routes: _routes(),
          siteBase: 'https://x.dev',
          buildDir: buildDir.path,
          indexNowKey: '../../etc/passwd',
        ),
        throwsArgumentError,
      );
    });

    test('an empty stylesheet writes no style tag', () async {
      await prerenderSite(
        routes: _routes(),
        siteBase: 'https://x.dev',
        buildDir: buildDir.path,
        renderMode: SeoRenderMode.visibleShell,
        stylesheet: '   ',
      );
      expect(
        File('${buildDir.path}/index.html').readAsStringSync(),
        isNot(contains('<style')),
      );
    });
  });

  group('shell handoff trigger', () {
    setUp(enableSeoForTests);

    testWidgets('the first refresh injects even with an empty tree',
        (tester) async {
      // Eine reine Canvas-App (kein Text/Image) spiegelt nichts — das
      // HTML bleibt ''. Die erste Injection muss trotzdem laufen, sonst
      // startet der visibleShell-Handoff nie und der prerenderte Shell
      // überdeckt die gebootete App für immer.
      expect(SeoController.instance.debugHasInjected, isFalse);
      await pumpSeo(tester, const SizedBox());
      expect(EsenSeo.currentHtml, isEmpty);
      expect(SeoController.instance.debugHasInjected, isTrue);
    });
  });

  group('developer-supplied styling hooks', () {
    setUp(enableSeoForTests);

    testWidgets('class and style pass through on text', (tester) async {
      await pumpSeo(
        tester,
        const Text('Titel').seo(
          SeoTextTag.h1,
          {'class': 'hero-title', 'style': 'text-align:center'},
        ),
      );
      expect(
        EsenSeo.currentHtml,
        '<h1 class="hero-title" style="text-align:center">Titel</h1>',
      );
    });

    testWidgets('class passes through on containers', (tester) async {
      await pumpSeo(
        tester,
        Column(children: [const Text('Inhalt').seo(SeoTextTag.p)])
            .seo(SeoContainerTag.section, {'class': 'card'}),
      );
      expect(
        EsenSeo.currentHtml,
        '<section class="card"><p>Inhalt</p></section>',
      );
    });

    testWidgets('event handlers stay blocked next to class', (tester) async {
      await pumpSeo(
        tester,
        const Text('Titel').seo(
          SeoTextTag.h1,
          {'class': 'ok', 'onclick': 'alert(1)'},
        ),
      );
      expect(EsenSeo.currentHtml, '<h1 class="ok">Titel</h1>');
    });
  });
}
