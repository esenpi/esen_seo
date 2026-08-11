import 'package:esen_seo/core.dart';
import 'package:flutter_test/flutter_test.dart';

final _records = <SeoCollectionRecord>[
  SeoCollectionRecord(
    title: 'Über Flutter',
    searchText: 'Semantisches HTML und SEO',
    categoryIndexes: [0, 1],
    sortKey: 30,
  ),
  SeoCollectionRecord(
    title: 'CMS ohne Datenbank',
    searchText: 'Git und Publishing',
    categoryIndexes: [1],
    sortKey: 20,
  ),
  SeoCollectionRecord(
    title: 'JavaScript Adapter',
    searchText: 'Schnelle progressive Interaktion',
    categoryIndexes: [2],
    sortKey: 10,
  ),
  SeoCollectionRecord(
    title: 'Alpha',
    searchText: 'Flutter Grundlagen',
    categoryIndexes: [0],
    sortKey: 20,
  ),
];

final _items = <SeoCollectionComponentEntry>[
  (
    title: 'Älter',
    searchText: 'CMS & <script>',
    categories: ['CMS'],
    sortKey: 10,
    nodes: [SeoNode(tag: 'h2', text: 'Älter')],
  ),
  (
    title: 'Neuer',
    searchText: 'Flutter',
    categories: ['Flutter', 'CMS'],
    sortKey: 20,
    nodes: [SeoNode(tag: 'h2', text: 'Neuer')],
  ),
];

void main() {
  group('collection transition', () {
    test('normalizes German and decomposed Latin text consistently', () {
      expect(normalizeSeoCollectionText('  ÜBER   Größe '), 'ueber groesse');
      expect(normalizeSeoCollectionText('Cafe\u0301 & Æther'), 'cafe & aether');
    });

    test('search requires every term and combines with one category', () {
      final snapshot = selectSeoCollection(
        records: _records,
        categoryCount: 3,
        pageSize: 10,
        state: const SeoCollectionState(
          query: 'ueber seo',
          categoryIndex: 0,
        ),
      );

      expect(snapshot.orderedIndices, [0]);
      expect(snapshot.visibleIndices, [0]);
      expect(snapshot.matchCount, 1);
    });

    test('sorts stably and paginates without mutating the source', () {
      final original = List<SeoCollectionRecord>.of(_records);
      final newest = selectSeoCollection(
        records: _records,
        categoryCount: 3,
        pageSize: 2,
      );
      final secondPage = selectSeoCollection(
        records: _records,
        categoryCount: 3,
        pageSize: 2,
        state: const SeoCollectionState(page: 1),
      );
      final titles = selectSeoCollection(
        records: _records,
        categoryCount: 3,
        pageSize: 10,
        state: const SeoCollectionState(sort: SeoCollectionSort.title),
      );

      expect(newest.orderedIndices, [0, 1, 3, 2]);
      expect(newest.visibleIndices, [0, 1]);
      expect(secondPage.visibleIndices, [3, 2]);
      expect(secondPage.pageCount, 2);
      expect(titles.orderedIndices, [3, 1, 2, 0]);
      expect(_records, original);
    });

    test('actions reset dependent state and clamp invalid boundaries', () {
      const state = SeoCollectionState(
        categoryIndex: 1,
        sort: SeoCollectionSort.oldest,
        page: 10,
      );
      final queried = transitionSeoCollection(
        state,
        const SeoCollectionSetQuery('Flutter'),
        records: _records,
        categoryCount: 3,
        pageSize: 1,
      );
      final invalidCategory = transitionSeoCollection(
        queried,
        const SeoCollectionSelectCategory(99),
        records: _records,
        categoryCount: 3,
        pageSize: 1,
      );
      final previous = transitionSeoCollection(
        invalidCategory,
        const SeoCollectionPreviousPage(),
        records: _records,
        categoryCount: 3,
        pageSize: 1,
      );

      expect(queried.query, 'Flutter');
      expect(queried.page, 0);
      expect(invalidCategory.categoryIndex, isNull);
      expect(previous.page, 0);
    });

    test('empty results have a canonical zero page', () {
      final snapshot = selectSeoCollection(
        records: _records,
        categoryCount: 3,
        pageSize: 0,
        state: const SeoCollectionState(query: 'missing', page: 999),
      );

      expect(snapshot.matchCount, 0);
      expect(snapshot.pageCount, 0);
      expect(snapshot.state.page, 0);
      expect(snapshot.visibleIndices, isEmpty);
      expect(normalizeSeoCollectionPageSize(0), 1);
      expect(normalizeSeoCollectionPageSize(1000), 100);
    });

    test('bounds queries and rejects sort keys JavaScript cannot represent',
        () {
      final oversized = List.filled(5000, 'x').join();
      final snapshot = selectSeoCollection(
        records: _records,
        categoryCount: 3,
        pageSize: 10,
        state: SeoCollectionState(query: oversized),
      );

      expect(snapshot.state.query.length, seoCollectionMaxSearchLength);
      expect(isValidSeoCollectionSortKey(seoCollectionMaxSortKey), isTrue);
      expect(isValidSeoCollectionSortKey(seoCollectionMaxSortKey + 1), isFalse);

      final emojiQuery = List.filled(3000, '\u{1F642}').join();
      final boundedEmoji = boundSeoCollectionQuery(emojiQuery);
      expect(
          boundedEmoji.length, lessThanOrEqualTo(seoCollectionMaxSearchLength));
      expect(boundedEmoji.runes.every((rune) => rune == 0x1F642), isTrue);
    });

    test('prepares immutable normalized records once', () {
      final categories = <int>[1];
      final record = SeoCollectionRecord(
        title: ' Über ',
        searchText: 'Größe',
        categoryIndexes: categories,
        sortKey: 1,
      );
      categories.add(2);

      expect(record.normalizedTitle, 'ueber');
      expect(record.normalizedSearchText, 'ueber groesse');
      expect(record.categoryIndexes, [1]);
      expect(() => record.categoryIndexes.add(3), throwsUnsupportedError);
    });
  });

  group('collection markup', () {
    test('source contains every item in its useful initial order', () {
      const renderer = HtmlRenderer();
      final html = renderer.render(buildSeoCollectionNodes(
        items: _items,
        interactionId: 'blog-collection',
        pageSize: 1,
      ));

      expect(html.indexOf('<h2>Neuer</h2>'),
          lessThan(html.indexOf('<h2>Älter</h2>')));
      expect(html, contains('data-esen-component="collection"'));
      expect(html, contains('data-esen-page-size="1"'));
      expect(html, isNot(contains('data-esen-synchronize-url')));
      expect('data-esen-collection-item=""'.allMatches(html), hasLength(2));
      expect(html, contains('data-esen-item-categories="0 1"'));
      expect(
          html, contains('data-esen-item-search="cms &amp; &lt;script&gt;"'));
      expect(html, isNot(contains('<input')));
      expect(html, isNot(contains('<button')));
      expect(html, contains('<article'));
    });

    test('URL synchronization emits only on a valid interactive collection',
        () {
      const renderer = HtmlRenderer();
      final interactive = renderer.render(buildSeoCollectionNodes(
        items: _items,
        interactionId: 'blog-collection',
        synchronizeUrl: true,
      ));
      final staticMarkup = renderer.render(buildSeoCollectionNodes(
        items: _items,
        interactionId: 'not valid',
        synchronizeUrl: true,
      ));

      expect(
        interactive,
        contains('data-esen-synchronize-url="true"'),
      );
      expect(staticMarkup, isNot(contains('data-esen-synchronize-url')));
    });

    test('invalid configuration degrades to complete static markup', () {
      const renderer = HtmlRenderer();
      final html = renderer.render(buildSeoCollectionNodes(
        items: _items,
        interactionId: 'not valid',
      ));

      expect(html, contains('<h2>Neuer</h2>'));
      expect(html, contains('<h2>Älter</h2>'));
      expect(html, isNot(contains('data-esen-component')));
      expect(html, isNot(contains('data-esen-collection-item=""')));
    });

    test('single-item collections remain static and complete', () {
      const renderer = HtmlRenderer();
      final html = renderer.render(buildSeoCollectionNodes(
        items: [_items.first],
        interactionId: 'single-collection',
      ));

      expect(html, contains('<h2>Älter</h2>'));
      expect(html, isNot(contains('data-esen-component')));
    });

    test('cross-runtime-unsafe data stays complete but static', () {
      const renderer = HtmlRenderer();
      final unsafe = <SeoCollectionComponentEntry>[
        (
          title: 'Unsafe',
          searchText: 'Still visible',
          categories: [List.filled(201, 'x').join()],
          sortKey: seoCollectionMaxSortKey + 1,
          nodes: [SeoNode(tag: 'h2', text: 'Unsafe')],
        ),
        _items.last,
      ];
      final html = renderer.render(buildSeoCollectionNodes(
        items: unsafe,
        interactionId: 'unsafe-collection',
      ));

      expect(html, contains('<h2>Unsafe</h2>'));
      expect(html, contains('<h2>Neuer</h2>'));
      expect(html, isNot(contains('data-esen-component')));
    });
  });
}
