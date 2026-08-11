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
  }) {
    final queryValue = _single(queryValues);
    final query =
        queryValue != null && queryValue.length <= seoCollectionMaxSearchLength
            ? queryValue
            : '';

    final categoryValue = _single(categoryValues);
    final normalizedCategory =
        categoryValue != null && categoryValue.length <= _maxCategoryUrlLength
            ? normalizeSeoCollectionText(categoryValue)
            : '';
    final categoryIndex = normalizedCategory.isEmpty
        ? -1
        : categoryLabels.indexWhere(
            (label) => normalizeSeoCollectionText(label) == normalizedCategory,
          );

    final sortValue = _single(sortValues);
    final sort = sortValue == null
        ? initialSort
        : parseSeoCollectionSort(sortValue) ?? initialSort;

    final pageValue = _single(pageValues);
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
  SeoCollectionUrlValues encode(SeoCollectionState state) {
    final query = boundSeoCollectionQuery(state.query);
    final category = state.categoryIndex;
    return (
      query: normalizeSeoCollectionText(query).isEmpty ? null : query,
      category:
          category != null && category >= 0 && category < categoryLabels.length
              ? normalizeSeoCollectionText(categoryLabels[category])
              : null,
      sort: state.sort == initialSort
          ? null
          : seoCollectionSortMarker(state.sort),
      page: state.page > 0 ? '${state.page + 1}' : null,
    );
  }
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
