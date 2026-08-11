import 'package:esen_seo/esen_seo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

List<SeoCollectionEntry> _items() => [
      SeoCollectionEntry(
        title: 'Über Flutter',
        searchText: 'SEO und HTML',
        categories: const ['Flutter', 'SEO'],
        sortKey: 40,
        content: const Text('Flutter card'),
        nodes: [SeoNode(tag: 'h2', text: 'Über Flutter')],
      ),
      SeoCollectionEntry(
        title: 'CMS',
        searchText: 'Git Publishing',
        categories: const ['CMS'],
        sortKey: 30,
        content: const Text('CMS card'),
        nodes: [SeoNode(tag: 'h2', text: 'CMS')],
      ),
      SeoCollectionEntry(
        title: 'Adapter',
        searchText: 'JavaScript',
        categories: const ['JavaScript'],
        sortKey: 20,
        content: const Text('Adapter card'),
        nodes: [SeoNode(tag: 'h2', text: 'Adapter')],
      ),
      SeoCollectionEntry(
        title: 'Alpha',
        searchText: 'Flutter basics',
        categories: const ['Flutter'],
        sortKey: 10,
        content: const Text('Alpha card'),
        nodes: [SeoNode(tag: 'h2', text: 'Alpha')],
      ),
    ];

Future<void> _pump(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: SeoCollection(
            items: _items(),
            interactionId: 'article-collection',
            interactionLabel: 'Blogartikel',
            pageSize: 2,
            searchLabel: 'Artikel suchen',
            categoriesLabel: 'Kategorien',
            allCategoriesLabel: 'Alle',
            sortLabel: 'Sortieren',
            newestLabel: 'Neueste',
            oldestLabel: 'Älteste',
            titleLabel: 'Titel',
            previousLabel: 'Zurück',
            nextLabel: 'Weiter',
            resultsLabel: 'Artikel',
            noResultsLabel: 'Keine Artikel',
            pageLabel: 'Seite',
          ),
        ),
      ),
    ),
  );
  EsenSeo.refresh();
}

void main() {
  setUp(enableSeoForTests);

  testWidgets('mirror stays complete while Flutter starts on the first page',
      (tester) async {
    await _pump(tester);

    expect(find.text('Flutter card'), findsOneWidget);
    expect(find.text('CMS card'), findsOneWidget);
    expect(find.text('Adapter card'), findsNothing);
    expect(find.text('Alpha card'), findsNothing);
    expect(EsenSeo.currentHtml, contains('<h2>Über Flutter</h2>'));
    expect(EsenSeo.currentHtml, contains('<h2>CMS</h2>'));
    expect(EsenSeo.currentHtml, contains('<h2>Adapter</h2>'));
    expect(EsenSeo.currentHtml, contains('<h2>Alpha</h2>'));
    expect(EsenSeo.currentHtml, isNot(contains('<input')));
    expect(EsenSeo.currentHtml, isNot(contains('<button')));
  });

  testWidgets('search, categories, sort and pages use the shared transition',
      (tester) async {
    await _pump(tester);

    await tester.enterText(find.byType(EditableText), 'ueber seo');
    await tester.pump();
    expect(find.text('Flutter card'), findsOneWidget);
    expect(find.text('CMS card'), findsNothing);
    expect(find.text('1 Artikel'), findsOneWidget);

    await tester.enterText(find.byType(EditableText), '');
    await tester.tap(find.text('Flutter'));
    await tester.pump();
    expect(find.text('Flutter card'), findsOneWidget);
    expect(find.text('Alpha card'), findsOneWidget);
    expect(find.text('2 Artikel'), findsOneWidget);

    await tester.tap(find.text('Alle'));
    await tester.tap(find.text('Älteste'));
    await tester.pump();
    expect(find.text('Alpha card'), findsOneWidget);
    expect(find.text('Adapter card'), findsOneWidget);
    expect(find.text('Flutter card'), findsNothing);

    await tester.ensureVisible(find.text('›'));
    await tester.tap(find.text('›'));
    await tester.pump();
    expect(find.text('CMS card'), findsOneWidget);
    expect(find.text('Flutter card'), findsOneWidget);
    expect(find.text('Seite 2 / 2'), findsOneWidget);
  });

  testWidgets('no-result state keeps every control recoverable',
      (tester) async {
    await _pump(tester);

    await tester.enterText(find.byType(EditableText), 'nicht vorhanden');
    await tester.pump();
    expect(find.text('Keine Artikel'), findsOneWidget);
    expect(find.byType(EditableText), findsOneWidget);
    expect(find.text('Alle'), findsOneWidget);
    expect(find.text('Neueste'), findsOneWidget);
    expect(find.text('›'), findsNothing);
  });

  testWidgets('content updates preserve a selected category by label',
      (tester) async {
    var items = _items();
    late StateSetter rebuild;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return SeoCollection(
                  items: items,
                  interactionId: 'updating-collection',
                  pageSize: 10,
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Flutter'));
    await tester.pump();
    expect(find.text('Flutter card'), findsOneWidget);
    expect(find.text('Alpha card'), findsOneWidget);

    rebuild(() {
      items = [items[1], items[0], items[2], items[3]];
    });
    await tester.pump();
    expect(find.text('Flutter card'), findsOneWidget);
    expect(find.text('Alpha card'), findsOneWidget);
    expect(find.text('CMS card'), findsNothing);
  });
}
