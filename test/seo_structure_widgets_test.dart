import 'package:esen_seo/esen_seo.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  setUp(enableSeoForTests);

  group('SeoNavMenu', () {
    const items = [
      SeoNavItem('Start', url: '/'),
      SeoNavItem('Leistungen', url: '/leistungen', children: [
        SeoNavItem('Flutter Apps', url: '/leistungen/apps'),
        SeoNavItem('SEO', url: '/leistungen/seo'),
      ]),
    ];

    testWidgets('mirrors submenus although they are closed on screen',
        (tester) async {
      await pumpSeo(tester, const SeoNavMenu(items: items));
      // Auf dem Schirm ist das Untermenü zu …
      expect(find.text('Flutter Apps'), findsNothing);
      // … im Quelltext steht es trotzdem, verschachtelt im Eltern-li.
      expect(
        EsenSeo.currentHtml,
        '<nav class="esen-seo-nav" aria-label="Hauptnavigation"><ul>'
        '<li><a href="/">Start</a></li>'
        '<li><a href="/leistungen">Leistungen</a><ul>'
        '<li><a href="/leistungen/apps">Flutter Apps</a></li>'
        '<li><a href="/leistungen/seo">SEO</a></li>'
        '</ul></li>'
        '</ul></nav>',
      );
    });

    testWidgets('opening a submenu leaves the mirror unchanged',
        (tester) async {
      await pumpSeo(tester, const SeoNavMenu(items: items));
      final closed = EsenSeo.currentHtml;
      await tester.tap(find.text('Leistungen'));
      await tester.pump();
      EsenSeo.refresh();
      expect(find.text('Flutter Apps'), findsOneWidget);
      expect(EsenSeo.currentHtml, closed);
    });

    testWidgets('entries without a URL become plain text', (tester) async {
      await pumpSeo(
        tester,
        const SeoNavMenu(items: [
          SeoNavItem('Mehr', children: [SeoNavItem('Blog', url: '/blog')]),
        ]),
      );
      expect(EsenSeo.currentHtml, contains('<li><span>Mehr</span><ul>'));
      expect(EsenSeo.currentHtml, contains('<a href="/blog">Blog</a>'));
    });

    testWidgets('nesting works arbitrarily deep', (tester) async {
      await pumpSeo(
        tester,
        const SeoNavMenu(items: [
          SeoNavItem('A', url: '/a', children: [
            SeoNavItem('B', url: '/b', children: [
              SeoNavItem('C', url: '/c'),
            ]),
          ]),
        ]),
      );
      expect(EsenSeo.currentHtml, contains('<a href="/c">C</a>'));
      expect('<ul>'.allMatches(EsenSeo.currentHtml), hasLength(3));
    });

    testWidgets('blank URLs are not links', (tester) async {
      await pumpSeo(
        tester,
        const SeoNavMenu(items: [SeoNavItem('Leer', url: '   ')]),
      );
      expect(EsenSeo.currentHtml, contains('<span>Leer</span>'));
      expect(EsenSeo.currentHtml, isNot(contains('href')));
    });

    testWidgets('an empty menu mirrors nothing', (tester) async {
      await pumpSeo(tester, const SeoNavMenu(items: []));
      expect(tester.takeException(), isNull);
      expect(EsenSeo.currentHtml, isEmpty);
    });
  });

  group('SeoNavMenu interaction', () {
    testWidgets('a linked parent both navigates and opens its submenu',
        (tester) async {
      // Genau die Konstellation aus der Klassendoku: Eintrag mit URL
      // UND Untermenü. Beides muss erreichbar sein.
      final tapped = <String>[];
      await pumpSeo(
        tester,
        SeoNavMenu(
          items: const [
            SeoNavItem('Leistungen', url: '/leistungen', children: [
              SeoNavItem('Flutter Apps', url: '/apps'),
            ]),
          ],
          onTap: (item) => tapped.add(item.label),
        ),
      );

      // Label folgt dem Link …
      await tester.tap(find.text('Leistungen'));
      await tester.pump();
      expect(tapped, ['Leistungen']);
      expect(find.text('Flutter Apps'), findsNothing);

      // … der Pfeil daneben klappt auf.
      await tester.tap(find.text('▸'));
      await tester.pump();
      expect(find.text('Flutter Apps'), findsOneWidget);
      expect(tapped, ['Leistungen']);
    });

    testWidgets('an open submenu does not jump to another entry',
        (tester) async {
      const b = SeoNavItem('Mehr B', children: [SeoNavItem('b1')]);
      const c = SeoNavItem('Mehr C', children: [SeoNavItem('c1')]);
      await pumpSeo(tester, const SeoNavMenu(items: [b, c]));
      await tester.tap(find.text('Mehr B'));
      await tester.pump();
      expect(find.text('b1'), findsOneWidget);

      // Ein Eintrag wird vorne eingefügt — „offen" muss bei B bleiben.
      await pumpSeo(
        tester,
        const SeoNavMenu(items: [
          SeoNavItem('Mehr A', children: [SeoNavItem('a1')]),
          b,
          c,
        ]),
      );
      expect(find.text('b1'), findsOneWidget);
      expect(find.text('a1'), findsNothing);
    });

    testWidgets('the visible menu goes as deep as the mirror', (tester) async {
      // Der Spiegel war schon beliebig tief; auf dem Schirm endete es
      // bei zwei Ebenen, Enkel waren unerreichbar.
      await pumpSeo(
        tester,
        const SeoNavMenu(items: [
          SeoNavItem('A', children: [
            SeoNavItem('B', children: [SeoNavItem('C')]),
          ]),
        ]),
      );
      await tester.tap(find.text('A'));
      await tester.pump();
      expect(find.text('B'), findsOneWidget);
      await tester.tap(find.text('B'));
      await tester.pump();
      expect(find.text('C'), findsOneWidget);
    });

    testWidgets('same-named entries at different depths stay independent',
        (tester) async {
      await pumpSeo(
        tester,
        const SeoNavMenu(items: [
          SeoNavItem('Mehr', children: [
            SeoNavItem('Mehr', children: [SeoNavItem('tief')]),
          ]),
        ]),
      );
      await tester.tap(find.text('Mehr').first);
      await tester.pump();
      // Nur die erste Ebene ist offen — der gleichnamige Enkel nicht.
      expect(find.text('tief'), findsNothing);
    });

    testWidgets('a removed entry does not stay open', (tester) async {
      await pumpSeo(
        tester,
        const SeoNavMenu(items: [
          SeoNavItem('Weg', children: [SeoNavItem('x')]),
          SeoNavItem('Bleibt', children: [SeoNavItem('y')]),
        ]),
      );
      await tester.tap(find.text('Weg'));
      await tester.pump();
      expect(find.text('x'), findsOneWidget);

      await pumpSeo(
        tester,
        const SeoNavMenu(items: [
          SeoNavItem('Bleibt', children: [SeoNavItem('y')]),
        ]),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('y'), findsNothing);
    });
  });

  group('SeoListView', () {
    List<SeoNode> nodesFor(String item, int index) => [
          SeoNode(tag: 'h2', text: item),
        ];

    testWidgets('mirrors every entry, not just the built ones', (tester) async {
      // 200 Einträge in einem 600px-Viewport: Flutter baut nur eine
      // Handvoll — der Spiegel muss trotzdem alle enthalten.
      final items = [for (var i = 0; i < 200; i++) 'Beitrag $i'];
      await pumpSeo(
        tester,
        SeoListView<String>(
          items: items,
          itemBuilder: (_, item, __) => SizedBox(height: 80, child: Text(item)),
          nodeBuilder: nodesFor,
        ),
      );

      expect(find.text('Beitrag 150'), findsNothing); // nicht gebaut
      expect(EsenSeo.currentHtml, contains('<h2>Beitrag 150</h2>'));
      expect(EsenSeo.currentHtml, contains('<h2>Beitrag 199</h2>'));
      expect('<h2>'.allMatches(EsenSeo.currentHtml), hasLength(200));
    });

    testWidgets('ul wraps its entries in li automatically', (tester) async {
      await pumpSeo(
        tester,
        SeoListView<String>(
          items: const ['A', 'B'],
          listTag: 'ul',
          itemBuilder: (_, item, __) => Text(item),
          nodeBuilder: (item, _) => [SeoNode(tag: 'span', text: item)],
        ),
      );
      expect(
        EsenSeo.currentHtml,
        '<ul class="esen-seo-list"><li><span>A</span></li>'
        '<li><span>B</span></li></ul>',
      );
    });

    testWidgets('a div list emits the nodes unwrapped', (tester) async {
      await pumpSeo(
        tester,
        SeoListView<String>(
          items: const ['A'],
          itemBuilder: (_, item, __) => Text(item),
          nodeBuilder: (item, _) => [SeoNode(tag: 'article', text: item)],
        ),
      );
      expect(
        EsenSeo.currentHtml,
        '<div class="esen-seo-list"><article>A</article></div>',
      );
    });

    testWidgets('an empty list mirrors nothing', (tester) async {
      await pumpSeo(
        tester,
        SeoListView<String>(
          items: const [],
          itemBuilder: (_, item, __) => Text(item),
          nodeBuilder: nodesFor,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(EsenSeo.currentHtml, isEmpty);
    });

    testWidgets('a blank tag never swallows the entries', (tester) async {
      // '' bedeutet „kein Wrapper" — niemals ein leerer Elementname,
      // der den kompletten Inhalt aus dem Spiegel wirft.
      await pumpSeo(
        tester,
        SeoListView<String>(
          items: const ['A', 'B'],
          listTag: '  ',
          itemTag: '',
          itemBuilder: (_, item, __) => Text(item),
          nodeBuilder: (item, _) => [SeoNode(tag: 'span', text: item)],
        ),
      );
      expect(
        EsenSeo.currentHtml,
        '<div class="esen-seo-list"><span>A</span><span>B</span></div>',
      );
    });

    testWidgets('entries whose builder returns nothing are skipped',
        (tester) async {
      await pumpSeo(
        tester,
        SeoListView<String>(
          items: const ['A', 'B'],
          listTag: 'ul',
          itemBuilder: (_, item, __) => Text(item),
          nodeBuilder: (item, _) =>
              item == 'A' ? [SeoNode(tag: 'span', text: item)] : const [],
        ),
      );
      expect('<li>'.allMatches(EsenSeo.currentHtml), hasLength(1));
    });
  });

  group('SeoTabs', () {
    final tabs = [
      SeoTab(
        label: 'Beschreibung',
        content: const Text('Leichtes Rennrad.'),
        nodes: [SeoNode(tag: 'p', text: 'Leichtes Rennrad.')],
      ),
      SeoTab(
        label: 'Technische Daten',
        content: const Text('8,4 kg'),
        nodes: [SeoNode(tag: 'p', text: 'Gewicht: 8,4 kg')],
      ),
    ];

    testWidgets('mirrors inactive panels too', (tester) async {
      await pumpSeo(tester, SeoTabs(tabs: tabs));
      // Nur der aktive Tab ist auf dem Schirm …
      expect(find.text('8,4 kg'), findsNothing);
      // … beide Panels stehen im Quelltext, je unter eigener Überschrift.
      expect(
        EsenSeo.currentHtml,
        '<div class="esen-seo-tabs">'
        '<section><h3>Beschreibung</h3><p>Leichtes Rennrad.</p></section>'
        '<section><h3>Technische Daten</h3><p>Gewicht: 8,4 kg</p></section>'
        '</div>',
      );
    });

    testWidgets('switching tabs leaves the mirror unchanged', (tester) async {
      await pumpSeo(tester, SeoTabs(tabs: tabs));
      final before = EsenSeo.currentHtml;
      await tester.tap(find.text('Technische Daten'));
      await tester.pump();
      EsenSeo.refresh();
      expect(find.text('8,4 kg'), findsOneWidget);
      expect(EsenSeo.currentHtml, before);
    });

    testWidgets('an out-of-range initial index is clamped', (tester) async {
      await pumpSeo(tester, SeoTabs(tabs: tabs, initialIndex: 99));
      expect(tester.takeException(), isNull);
      expect(find.text('8,4 kg'), findsOneWidget);
    });

    testWidgets('the heading level is configurable and clamped',
        (tester) async {
      await pumpSeo(tester, SeoTabs(tabs: tabs, headingLevel: 0));
      expect(EsenSeo.currentHtml, contains('<h1>Beschreibung</h1>'));
    });

    testWidgets('no tabs mirror nothing', (tester) async {
      await pumpSeo(tester, const SeoTabs(tabs: []));
      expect(tester.takeException(), isNull);
      expect(EsenSeo.currentHtml, isEmpty);
    });

    testWidgets('replacing the data resets to the initial tab', (tester) async {
      // Produkt A, dritter Reiter offen — dann wird Produkt B geladen.
      // Der Reiter von A darf nicht offen bleiben.
      final produktA = [
        for (final label in ['A1', 'A2', 'A3'])
          SeoTab(
            label: label,
            content: Text('Inhalt $label'),
            nodes: [SeoNode(tag: 'p', text: 'Inhalt $label')],
          ),
      ];
      final produktB = [
        for (final label in ['B1', 'B2', 'B3'])
          SeoTab(
            label: label,
            content: Text('Inhalt $label'),
            nodes: [SeoNode(tag: 'p', text: 'Inhalt $label')],
          ),
      ];

      await pumpSeo(tester, SeoTabs(tabs: produktA));
      await tester.tap(find.text('A3'));
      await tester.pump();
      expect(find.text('Inhalt A3'), findsOneWidget);

      await pumpSeo(tester, SeoTabs(tabs: produktB));
      expect(find.text('Inhalt B1'), findsOneWidget);
      expect(find.text('Inhalt B3'), findsNothing);
    });

    testWidgets('the selection survives an unrelated rebuild', (tester) async {
      await pumpSeo(tester, SeoTabs(tabs: tabs));
      await tester.tap(find.text('Technische Daten'));
      await tester.pump();
      await pumpSeo(tester, SeoTabs(tabs: tabs));
      expect(find.text('8,4 kg'), findsOneWidget);
    });

    testWidgets('shrinking the tab list keeps the index valid', (tester) async {
      await pumpSeo(tester, SeoTabs(tabs: tabs, initialIndex: 1));
      await pumpSeo(tester, SeoTabs(tabs: [tabs.first]));
      expect(tester.takeException(), isNull);
      expect(find.text('Leichtes Rennrad.'), findsOneWidget);
    });
  });
}
