import 'package:esen_seo/core.dart';

/// Example-owned tabs logic: keyboard traversal stops instead of wrapping.
SeoTabsState transitionExampleTabs(
  SeoTabsState state,
  SeoTabsAction action,
) {
  final normalized = initialSeoTabsState(
    count: state.count,
    index: state.index,
  );
  if (normalized.count == 0) return normalized;
  final last = normalized.count - 1;
  final next = switch (action) {
    SeoTabsSelect(:final index) when index >= 0 && index <= last => index,
    SeoTabsSelect() => normalized.index,
    SeoTabsNext() => (normalized.index + 1).clamp(0, last),
    SeoTabsPrevious() => (normalized.index - 1).clamp(0, last),
    SeoTabsFirst() => 0,
    SeoTabsLast() => last,
  };
  return SeoTabsState(index: next, count: normalized.count);
}
