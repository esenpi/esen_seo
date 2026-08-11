/// Pure collection state shared by Flutter and the compiled DOM-first adapter.
library;

/// Largest collection the progressive adapter will enhance.
const int seoCollectionMaxItems = 2000;

/// Largest category set the progressive adapter will enhance.
const int seoCollectionMaxCategories = 32;

/// Largest normalized search corpus accepted for one enhanced item.
const int seoCollectionMaxSearchLength = 4096;

/// Largest exactly representable integer shared by Dart VM and JavaScript.
const int seoCollectionMaxSortKey = 9007199254740991;

/// Sort modes supported by the closed collection interaction contract.
enum SeoCollectionSort { newest, oldest, title }

/// Prepared pure data needed to select and order one collection entry.
///
/// Text is normalized once at construction instead of once per keystroke.
final class SeoCollectionRecord {
  SeoCollectionRecord({
    required String title,
    required String searchText,
    required List<int> categoryIndexes,
    required this.sortKey,
  })  : categoryIndexes = List.unmodifiable(categoryIndexes),
        normalizedTitle = normalizeSeoCollectionText(title),
        normalizedSearchText = normalizeSeoCollectionText(
          '$title $searchText',
        );

  final List<int> categoryIndexes;
  final String normalizedTitle;
  final String normalizedSearchText;
  final int sortKey;
}

/// Immutable interaction state for one collection.
class SeoCollectionState {
  const SeoCollectionState({
    this.query = '',
    this.categoryIndex,
    this.sort = SeoCollectionSort.newest,
    this.page = 0,
  });

  final String query;
  final int? categoryIndex;
  final SeoCollectionSort sort;
  final int page;
}

/// Result of applying [SeoCollectionState] to a complete data set.
class SeoCollectionSnapshot {
  const SeoCollectionSnapshot({
    required this.state,
    required this.orderedIndices,
    required this.visibleIndices,
    required this.matchCount,
    required this.pageCount,
  });

  final SeoCollectionState state;
  final List<int> orderedIndices;
  final List<int> visibleIndices;
  final int matchCount;
  final int pageCount;
}

/// Closed action vocabulary understood by both presentations.
sealed class SeoCollectionAction {
  const SeoCollectionAction();
}

final class SeoCollectionSetQuery extends SeoCollectionAction {
  const SeoCollectionSetQuery(this.query);
  final String query;
}

final class SeoCollectionSelectCategory extends SeoCollectionAction {
  const SeoCollectionSelectCategory(this.index);
  final int? index;
}

final class SeoCollectionSetSort extends SeoCollectionAction {
  const SeoCollectionSetSort(this.sort);
  final SeoCollectionSort sort;
}

final class SeoCollectionSetPage extends SeoCollectionAction {
  const SeoCollectionSetPage(this.page);
  final int page;
}

final class SeoCollectionNextPage extends SeoCollectionAction {
  const SeoCollectionNextPage();
}

final class SeoCollectionPreviousPage extends SeoCollectionAction {
  const SeoCollectionPreviousPage();
}

/// Keeps page sizes useful and bounds the amount shown in one DOM mutation.
int normalizeSeoCollectionPageSize(int pageSize) => pageSize.clamp(1, 100);

/// Bounds user-entered query state before either presentation evaluates it.
String boundSeoCollectionQuery(String input) {
  if (input.length <= seoCollectionMaxSearchLength) return input;
  var end = seoCollectionMaxSearchLength;
  final last = input.codeUnitAt(end - 1);
  if (last >= 0xD800 && last <= 0xDBFF) end--;
  return input.substring(0, end);
}

/// Whether [sortKey] has identical integer semantics on VM and JavaScript.
bool isValidSeoCollectionSortKey(int sortKey) =>
    sortKey >= -seoCollectionMaxSortKey && sortKey <= seoCollectionMaxSortKey;

/// Stable marker serialized into package-owned collection markup.
String seoCollectionSortMarker(SeoCollectionSort sort) => switch (sort) {
      SeoCollectionSort.newest => 'newest',
      SeoCollectionSort.oldest => 'oldest',
      SeoCollectionSort.title => 'title',
    };

/// Parses a package-owned sort marker.
SeoCollectionSort? parseSeoCollectionSort(String value) => switch (value) {
      'newest' => SeoCollectionSort.newest,
      'oldest' => SeoCollectionSort.oldest,
      'title' => SeoCollectionSort.title,
      _ => null,
    };

/// Normalizes human text identically in Flutter and compiled JavaScript.
///
/// German umlauts use their common ASCII spellings so `über` matches
/// `ueber`; common Latin accents and decomposed combining marks are folded too.
String normalizeSeoCollectionText(String input) {
  final output = StringBuffer();
  for (final rune in input.toLowerCase().runes) {
    if (rune >= 0x0300 && rune <= 0x036f) continue;
    output.write(switch (rune) {
      0x00E4 => 'ae',
      0x00F6 => 'oe',
      0x00FC => 'ue',
      0x00DF => 'ss',
      0x00E6 => 'ae',
      0x0153 => 'oe',
      0x00FE => 'th',
      0x00F0 => 'd',
      0x00E0 || 0x00E1 || 0x00E2 || 0x00E3 || 0x00E5 => 'a',
      0x00E7 || 0x0107 || 0x010D => 'c',
      0x010F => 'd',
      0x00E8 || 0x00E9 || 0x00EA || 0x00EB => 'e',
      0x00EC || 0x00ED || 0x00EE || 0x00EF => 'i',
      0x0142 => 'l',
      0x00F1 || 0x0144 => 'n',
      0x00F2 || 0x00F3 || 0x00F4 || 0x00F5 || 0x00F8 => 'o',
      0x0159 => 'r',
      0x015B || 0x0161 => 's',
      0x0165 => 't',
      0x00F9 || 0x00FA || 0x00FB => 'u',
      0x00FD || 0x00FF => 'y',
      0x017A || 0x017C || 0x017E => 'z',
      _ => String.fromCharCode(rune),
    });
  }
  return output.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Derives stable display categories, deduplicated by normalized label.
List<String> seoCollectionCategoryLabels(Iterable<List<String>> groups) {
  final labels = <String>[];
  final seen = <String>{};
  for (final group in groups) {
    for (final rawCategory in group) {
      final label = rawCategory.trim();
      final normalized = normalizeSeoCollectionText(label);
      if (normalized.isEmpty || !seen.add(normalized)) continue;
      labels.add(label);
    }
  }
  return List.unmodifiable(labels);
}

/// Maps one entry's labels to the stable indexes from [categoryLabels].
List<int> seoCollectionCategoryIndexes(
  List<String> categories,
  List<String> categoryLabels,
) {
  final indexByLabel = <String, int>{
    for (var index = 0; index < categoryLabels.length; index++)
      normalizeSeoCollectionText(categoryLabels[index]): index,
  };
  final indexes = <int>{};
  for (final category in categories) {
    final index = indexByLabel[normalizeSeoCollectionText(category.trim())];
    if (index != null) indexes.add(index);
  }
  return (indexes.toList()..sort()).toList(growable: false);
}

/// Computes the canonical result for [state] without mutating [records].
SeoCollectionSnapshot selectSeoCollection({
  required List<SeoCollectionRecord> records,
  required int categoryCount,
  required int pageSize,
  SeoCollectionState state = const SeoCollectionState(),
}) {
  final size = normalizeSeoCollectionPageSize(pageSize);
  final category = state.categoryIndex;
  final selectedCategory =
      category != null && category >= 0 && category < categoryCount
          ? category
          : null;
  final rawQuery = boundSeoCollectionQuery(state.query);
  final query = normalizeSeoCollectionText(rawQuery);
  final terms = query.isEmpty ? const <String>[] : query.split(' ');
  final ordered = <int>[];
  for (var index = 0; index < records.length; index++) {
    final record = records[index];
    if (selectedCategory != null &&
        !record.categoryIndexes.contains(selectedCategory)) {
      continue;
    }
    final corpus = record.normalizedSearchText;
    if (terms.any((term) => !corpus.contains(term))) continue;
    ordered.add(index);
  }

  ordered.sort((left, right) {
    final leftRecord = records[left];
    final rightRecord = records[right];
    final compared = switch (state.sort) {
      SeoCollectionSort.newest =>
        rightRecord.sortKey.compareTo(leftRecord.sortKey),
      SeoCollectionSort.oldest =>
        leftRecord.sortKey.compareTo(rightRecord.sortKey),
      SeoCollectionSort.title =>
        leftRecord.normalizedTitle.compareTo(rightRecord.normalizedTitle),
    };
    return compared == 0 ? left.compareTo(right) : compared;
  });

  final pageCount = (ordered.length + size - 1) ~/ size;
  final page = pageCount == 0 ? 0 : state.page.clamp(0, pageCount - 1);
  final start = page * size;
  final end = (start + size).clamp(0, ordered.length);
  final canonical = SeoCollectionState(
    query: rawQuery,
    categoryIndex: selectedCategory,
    sort: state.sort,
    page: page,
  );
  return SeoCollectionSnapshot(
    state: canonical,
    orderedIndices: List.unmodifiable(ordered),
    visibleIndices: List.unmodifiable(ordered.sublist(start, end)),
    matchCount: ordered.length,
    pageCount: pageCount,
  );
}

/// Applies one closed action and returns canonical collection state.
SeoCollectionState transitionSeoCollection(
  SeoCollectionState state,
  SeoCollectionAction action, {
  required List<SeoCollectionRecord> records,
  required int categoryCount,
  required int pageSize,
}) {
  final candidate = switch (action) {
    SeoCollectionSetQuery(:final query) => SeoCollectionState(
        query: query,
        categoryIndex: state.categoryIndex,
        sort: state.sort,
      ),
    SeoCollectionSelectCategory(:final index) => SeoCollectionState(
        query: state.query,
        categoryIndex: index,
        sort: state.sort,
      ),
    SeoCollectionSetSort(:final sort) => SeoCollectionState(
        query: state.query,
        categoryIndex: state.categoryIndex,
        sort: sort,
      ),
    SeoCollectionSetPage(:final page) => SeoCollectionState(
        query: state.query,
        categoryIndex: state.categoryIndex,
        sort: state.sort,
        page: page,
      ),
    SeoCollectionNextPage() => SeoCollectionState(
        query: state.query,
        categoryIndex: state.categoryIndex,
        sort: state.sort,
        page: state.page + 1,
      ),
    SeoCollectionPreviousPage() => SeoCollectionState(
        query: state.query,
        categoryIndex: state.categoryIndex,
        sort: state.sort,
        page: state.page - 1,
      ),
  };
  return selectSeoCollection(
    records: records,
    categoryCount: categoryCount,
    pageSize: pageSize,
    state: candidate,
  ).state;
}
