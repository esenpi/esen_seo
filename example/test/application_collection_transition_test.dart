import 'package:esen_seo/esen_seo.dart';
import 'package:example/application_collection_transition.dart';
import 'package:example/seo_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

List<SeoCollectionRecord> _records() => [
      for (final (index, item) in demoCollectionItems.indexed)
        SeoCollectionRecord(
          title: item.title,
          searchText: item.searchText,
          categoryIndexes: [if (index != 1) 0, if (index == 1) 1],
          sortKey: item.sortKey,
        ),
    ];

void main() {
  test('application collection sorts selected categories by title', () {
    final records = _records();
    final state = transitionExampleCollection(
      const SeoCollectionState(query: 'runtime', page: 2),
      const SeoCollectionSelectCategory(0),
      records: records,
      categoryCount: 2,
      pageSize: 2,
    );

    expect(state.categoryIndex, 0);
    expect(state.query, isEmpty);
    expect(state.sort, SeoCollectionSort.title);
  });

  test('DOM-first route selects the compiled collection identity once', () {
    final route = seoRoutes.singleWhere(
      (route) => route.path == '/dom-first-application-collection',
    );

    expect(route.delivery, SeoRouteDelivery.domFirst);
    expect(
      route.applicationRuntime,
      const SeoDomFirstApplicationRuntime.collection('example-collection'),
    );
    expect(route.domFirstFeatures, isEmpty);
  });

  testWidgets('Flutter executes the same wrapping transition', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SeoCollection(
              pageSize: 2,
              transition: transitionExampleCollection,
              items: [
                for (final item in demoCollectionItems)
                  SeoCollectionEntry(
                    title: item.title,
                    searchText: item.searchText,
                    categories: item.categories,
                    sortKey: item.sortKey,
                    content: Text(item.title),
                    nodes: const [],
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Architecture'));
    await tester.pump();
    expect(find.text('Complete source'), findsOneWidget);
    expect(find.text('Semantic routes'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Complete source')).dy,
      lessThan(tester.getTopLeft(find.text('Semantic routes')).dy),
    );
  });
}
