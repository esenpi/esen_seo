/// Pure URL-state codec for a progressively enhanced collection.
library;

import 'seo_collection_transition.dart';
import 'seo_component_format.dart';

/// Canonical encoded values for one collection's URL parameters.
typedef SeoCollectionUrlValues = ({
  String? query,
  String? category,
  String? sort,
  String? page,
});

/// Maps one collection's closed state to namespaced query parameters.
///
/// The codec knows nothing about browser history. It accepts decoded query
/// values and emits canonical encoded values; the web adapter owns URL parsing
/// and mutation.
final class SeoCollectionUrlCodec {
  SeoCollectionUrlCodec({
    required String interactionId,
    required List<String> categoryLabels,
    this.initialSort = SeoCollectionSort.newest,
  })  : interactionId = _validInteractionId(interactionId),
        categoryLabels = seoCollectionCategoryLabels([categoryLabels]);

  final String interactionId;
  final List<String> categoryLabels;
  final SeoCollectionSort initialSort;

  String get queryParameter => 'esen.$interactionId.q';
  String get categoryParameter => 'esen.$interactionId.category';
  String get sortParameter => 'esen.$interactionId.sort';
  String get pageParameter => 'esen.$interactionId.page';

  /// Decodes one state from already URL-decoded query values.
  ///
  /// Missing, duplicate, oversized and malformed values fall back to the
  /// collection defaults. Record-dependent page clamping remains the job of
  /// [selectSeoCollection].
  SeoCollectionState decode({
    List<String> queryValues = const [],
    List<String> categoryValues = const [],
    List<String> sortValues = const [],
    List<String> pageValues = const [],
  }) =>
      decodeUniqueValues(
        queryValue: _single(queryValues),
        categoryValue: _single(categoryValues),
        sortValue: _single(sortValues),
        pageValue: _single(pageValues),
      );

  /// Decodes query values after the caller has rejected duplicate parameters.
  ///
  /// The browser adapter uses this allocation-free boundary after requiring
  /// exactly one value per parameter. A missing or ambiguous value is `null`.
  SeoCollectionState decodeUniqueValues({
    String? queryValue,
    String? categoryValue,
    String? sortValue,
    String? pageValue,
  }) {
    final query =
        queryValue != null && queryValue.length <= seoCollectionMaxSearchLength
            ? queryValue
            : '';

    final normalizedCategory =
        categoryValue != null && categoryValue.length <= _maxCategoryUrlLength
            ? normalizeSeoCollectionText(categoryValue)
            : '';
    final categoryIndex = normalizedCategory.isEmpty
        ? -1
        : categoryLabels.indexWhere(
            (label) => normalizeSeoCollectionText(label) == normalizedCategory,
          );

    final sort = sortValue == null
        ? initialSort
        : parseSeoCollectionSort(sortValue) ?? initialSort;

    final page = pageValue != null && _urlPage.hasMatch(pageValue)
        ? (int.tryParse(pageValue) ?? 1) - 1
        : 0;

    return SeoCollectionState(
      query: query,
      categoryIndex: categoryIndex < 0 ? null : categoryIndex,
      sort: sort,
      page: page,
    );
  }

  /// Encodes canonical non-default values for one collection state.
  SeoCollectionUrlValues encode(SeoCollectionState state) => (
        query: encodeQueryValue(state),
        category: encodeCategoryValue(state),
        sort: encodeSortValue(state),
        page: encodePageValue(state),
      );

  /// Encodes the non-default query value for browser persistence.
  String? encodeQueryValue(SeoCollectionState state) {
    final query = boundSeoCollectionQuery(state.query);
    return normalizeSeoCollectionText(query).isEmpty ? null : query;
  }

  /// Encodes the stable category label for browser persistence.
  String? encodeCategoryValue(SeoCollectionState state) {
    final category = state.categoryIndex;
    return category != null && category >= 0 && category < categoryLabels.length
        ? normalizeSeoCollectionText(categoryLabels[category])
        : null;
  }

  /// Encodes the non-default sort marker for browser persistence.
  String? encodeSortValue(SeoCollectionState state) =>
      state.sort == initialSort ? null : seoCollectionSortMarker(state.sort);

  /// Encodes the one-based non-default page for browser persistence.
  String? encodePageValue(SeoCollectionState state) =>
      state.page > 0 ? '${state.page + 1}' : null;
}

String? _single(List<String> values) =>
    values.length == 1 ? values.single : null;

String _validInteractionId(String value) {
  if (!isValidSeoInteractionId(value)) {
    throw ArgumentError.value(value, 'interactionId', 'Invalid interaction id');
  }
  return value;
}

const int _maxCategoryUrlLength = 200;
final RegExp _urlPage = RegExp(r'^[1-9][0-9]{0,8}$');
