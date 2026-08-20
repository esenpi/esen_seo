import 'package:esen_seo/core.dart';

/// Example-owned collection logic: selected categories use title order.
SeoCollectionState transitionExampleCollection(
  SeoCollectionState state,
  SeoCollectionAction action, {
  required List<SeoCollectionRecord> records,
  required int categoryCount,
  required int pageSize,
}) {
  if (action is SeoCollectionSelectCategory) {
    return SeoCollectionState(
      categoryIndex: action.index,
      sort: SeoCollectionSort.title,
    );
  }
  return transitionSeoCollection(
    state,
    action,
    records: records,
    categoryCount: categoryCount,
    pageSize: pageSize,
  );
}
