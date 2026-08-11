import 'package:esen_seo/core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final codec = SeoCollectionUrlCodec(
    interactionId: 'blog-collection',
    categoryLabels: const ['Flutter', 'SEO', 'Überblick'],
  );

  test('uses fixed namespaced parameter names', () {
    expect(codec.queryParameter, 'esen.blog-collection.q');
    expect(codec.categoryParameter, 'esen.blog-collection.category');
    expect(codec.sortParameter, 'esen.blog-collection.sort');
    expect(codec.pageParameter, 'esen.blog-collection.page');
    expect(
      () => SeoCollectionUrlCodec(
        interactionId: 'not valid',
        categoryLabels: const [],
      ),
      throwsArgumentError,
    );
  });

  test('encodes only canonical non-default values', () {
    expect(
      codec.encode(const SeoCollectionState()),
      (query: null, category: null, sort: null, page: null),
    );
    expect(
      codec.encode(const SeoCollectionState(
        query: 'Flutter SEO',
        categoryIndex: 2,
        sort: SeoCollectionSort.oldest,
        page: 3,
      )),
      (
        query: 'Flutter SEO',
        category: 'ueberblick',
        sort: 'oldest',
        page: '4',
      ),
    );
    expect(
      codec.encode(const SeoCollectionState(
        query: '   ',
        categoryIndex: 99,
        page: -1,
      )),
      (query: null, category: null, sort: null, page: null),
    );
  });

  test('decodes category identity independently of display order', () {
    final reordered = SeoCollectionUrlCodec(
      interactionId: 'blog-collection',
      categoryLabels: const ['SEO', 'Überblick', 'Flutter'],
    );
    final state = reordered.decode(
      queryValues: const ['ueber schnell'],
      categoryValues: const ['ÜBERBLICK'],
      sortValues: const ['title'],
      pageValues: const ['2'],
    );

    expect(state.query, 'ueber schnell');
    expect(state.categoryIndex, 1);
    expect(state.sort, SeoCollectionSort.title);
    expect(state.page, 1);
  });

  test('duplicate, malformed and oversized values fall back safely', () {
    final state = codec.decode(
      queryValues: const ['first', 'second'],
      categoryValues: const ['missing'],
      sortValues: const ['sideways'],
      pageValues: const ['0002'],
    );
    expect(state.query, isEmpty);
    expect(state.categoryIndex, isNull);
    expect(state.sort, SeoCollectionSort.newest);
    expect(state.page, 0);

    final oversized = codec.decode(
      queryValues: [List.filled(5000, 'x').join()],
      categoryValues: [List.filled(201, 'x').join()],
      pageValues: const ['9999999999'],
    );
    expect(oversized.query, isEmpty);
    expect(oversized.categoryIndex, isNull);
    expect(oversized.page, 0);
  });

  test('respects a non-default initial sort', () {
    final oldest = SeoCollectionUrlCodec(
      interactionId: 'archive',
      categoryLabels: const [],
      initialSort: SeoCollectionSort.oldest,
    );
    expect(oldest.decode().sort, SeoCollectionSort.oldest);
    expect(
      oldest.encode(const SeoCollectionState(sort: SeoCollectionSort.oldest)),
      (query: null, category: null, sort: null, page: null),
    );
    expect(
      oldest.encode(const SeoCollectionState()),
      (query: null, category: null, sort: 'newest', page: null),
    );
  });
}
