import 'package:esen_seo/core.dart';

SeoCollectionState transitionBenchmarkCollection(
  SeoCollectionState state,
  SeoCollectionAction action, {
  required List<SeoCollectionRecord> records,
  required int categoryCount,
  required int pageSize,
}) =>
    transitionSeoCollection(
      state,
      action,
      records: records,
      categoryCount: categoryCount,
      pageSize: pageSize,
    );
