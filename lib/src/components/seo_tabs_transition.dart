/// Pure state transition shared by Flutter and DOM-first tab presentations.
library;

/// A state-free tabs transition shared by platform presentations.
typedef SeoTabsTransition = SeoTabsState Function(
  SeoTabsState state,
  SeoTabsAction action,
);

/// Executes [transition] within the closed state contract of a tabs control.
///
/// Application logic cannot change the panel count or select a missing panel.
/// A thrown exception or invalid result leaves the last valid state unchanged
/// on both Flutter and DOM-first presentations.
SeoTabsState applySeoTabsTransition(
  SeoTabsTransition transition,
  SeoTabsState state,
  SeoTabsAction action,
) {
  final current = _normalizedSeoTabsState(state);
  final SeoTabsState result;
  try {
    result = transition(current, action);
  } catch (_) {
    return current;
  }
  if (result.count != current.count ||
      result.index < 0 ||
      result.index >= current.count) {
    return current;
  }
  return result;
}

/// The complete state needed to select one panel in a tab group.
final class SeoTabsState {
  const SeoTabsState({required this.index, required this.count});

  /// The selected tab index. [transitionSeoTabs] normalizes it before use.
  final int index;

  /// The number of tabs. Negative input is normalized to zero.
  final int count;

  @override
  bool operator ==(Object other) =>
      other is SeoTabsState && other.index == index && other.count == count;

  @override
  int get hashCode => Object.hash(index, count);
}

/// A user intent understood by the shared tabs transition.
sealed class SeoTabsAction {
  const SeoTabsAction();
}

/// Selects one tab by index. Out-of-range indices leave selection unchanged.
final class SeoTabsSelect extends SeoTabsAction {
  const SeoTabsSelect(this.index);

  final int index;
}

/// Selects the next tab, wrapping from the last tab to the first.
final class SeoTabsNext extends SeoTabsAction {
  const SeoTabsNext();
}

/// Selects the previous tab, wrapping from the first tab to the last.
final class SeoTabsPrevious extends SeoTabsAction {
  const SeoTabsPrevious();
}

/// Selects the first tab.
final class SeoTabsFirst extends SeoTabsAction {
  const SeoTabsFirst();
}

/// Selects the last tab.
final class SeoTabsLast extends SeoTabsAction {
  const SeoTabsLast();
}

/// Returns a valid initial state for [count] tabs.
SeoTabsState initialSeoTabsState({required int count, int index = 0}) =>
    _normalizedSeoTabsState(SeoTabsState(index: index, count: count));

/// Computes the next tab state without retaining state or performing effects.
SeoTabsState transitionSeoTabs(SeoTabsState state, SeoTabsAction action) {
  final normalized = _normalizedSeoTabsState(state);
  final count = normalized.count;
  if (count == 0) return normalized;

  final current = normalized.index;
  final next = switch (action) {
    SeoTabsSelect(:final index) when index >= 0 && index < count => index,
    SeoTabsSelect() => current,
    SeoTabsNext() => (current + 1) % count,
    SeoTabsPrevious() => (current - 1 + count) % count,
    SeoTabsFirst() => 0,
    SeoTabsLast() => count - 1,
  };
  return SeoTabsState(index: next, count: count);
}

SeoTabsState _normalizedSeoTabsState(SeoTabsState state) {
  final count = state.count < 0 ? 0 : state.count;
  if (count == 0) return const SeoTabsState(index: 0, count: 0);
  return SeoTabsState(index: state.index.clamp(0, count - 1), count: count);
}
