/// Pure approval checklist state shared by native and browser presentations.
library;

import 'seo_application_evaluation.dart';
import 'seo_configurator_transition.dart' show canonicalizeSeoConfiguratorText;

typedef SeoApprovalChecklistTransition = SeoApprovalChecklistState Function(
  SeoApprovalChecklistState state,
  SeoApprovalChecklistAction action,
);

typedef SeoApprovalChecklistViewProjection = SeoApprovalChecklistView Function(
  SeoApprovalChecklistState state,
);

const int seoApprovalChecklistMaxItems = 32;
const int seoApprovalChecklistMaxStatusTextLength = 128;
const int seoApprovalChecklistMaxSummaryTextLength = 512;
const int seoApprovalChecklistMaxAnnouncementTextLength = 512;
const int seoApprovalChecklistMaxAggregateTextLength = 1024;

final class SeoApprovalChecklistState {
  const SeoApprovalChecklistState({required this.checked});

  final List<bool> checked;

  @override
  bool operator ==(Object other) =>
      other is SeoApprovalChecklistState && _sameFlags(other.checked, checked);

  @override
  int get hashCode => Object.hashAll(checked);
}

sealed class SeoApprovalChecklistAction {
  const SeoApprovalChecklistAction();
}

final class SeoApprovalChecklistSetItem extends SeoApprovalChecklistAction {
  const SeoApprovalChecklistSetItem(this.index, this.checked);

  final int index;
  final bool checked;
}

final class SeoApprovalChecklistView {
  const SeoApprovalChecklistView({
    required this.statusText,
    required this.summaryText,
    required this.announcementText,
  });

  final String statusText;
  final String summaryText;
  final String announcementText;

  @override
  bool operator ==(Object other) =>
      other is SeoApprovalChecklistView &&
      other.statusText == statusText &&
      other.summaryText == summaryText &&
      other.announcementText == announcementText;

  @override
  int get hashCode => Object.hash(statusText, summaryText, announcementText);
}

final class SeoApprovalChecklistEvaluation {
  const SeoApprovalChecklistEvaluation({
    required this.state,
    required this.view,
    required this.accepted,
  });

  final SeoApprovalChecklistState state;
  final SeoApprovalChecklistView view;
  final bool accepted;

  @override
  bool operator ==(Object other) =>
      other is SeoApprovalChecklistEvaluation &&
      other.state == state &&
      other.view == view &&
      other.accepted == accepted;

  @override
  int get hashCode => Object.hash(state, view, accepted);
}

SeoApprovalChecklistState? initialSeoApprovalChecklistState({
  required int itemCount,
  Iterable<int> checkedIndexes = const [],
}) {
  if (!_isValidItemCount(itemCount)) return null;
  final checked = List<bool>.filled(itemCount, false);
  for (final index in checkedIndexes) {
    if (index < 0 || index >= itemCount || checked[index]) return null;
    checked[index] = true;
  }
  return SeoApprovalChecklistState(checked: List.unmodifiable(checked));
}

bool isValidSeoApprovalChecklistState(
  SeoApprovalChecklistState state,
  int itemCount,
) =>
    _isValidItemCount(itemCount) && state.checked.length == itemCount;

int seoApprovalChecklistCheckedCount(SeoApprovalChecklistState state) =>
    state.checked.where((checked) => checked).length;

bool isSeoApprovalChecklistComplete(SeoApprovalChecklistState state) =>
    state.checked.isNotEmpty && state.checked.every((checked) => checked);

bool isSeoApprovalChecklistActionEnabled(
  SeoApprovalChecklistState state,
  SeoApprovalChecklistAction action,
  int itemCount,
) =>
    isValidSeoApprovalChecklistState(state, itemCount) &&
    switch (action) {
      SeoApprovalChecklistSetItem(:final index, :final checked) =>
        index >= 0 && index < itemCount && state.checked[index] != checked,
    };

SeoApprovalChecklistState transitionSeoApprovalChecklist(
  SeoApprovalChecklistState state,
  SeoApprovalChecklistAction action,
) {
  final itemCount = state.checked.length;
  if (!isSeoApprovalChecklistActionEnabled(state, action, itemCount)) {
    return state;
  }
  final change = action as SeoApprovalChecklistSetItem;
  final checked = [...state.checked]..[change.index] = change.checked;
  return SeoApprovalChecklistState(checked: List.unmodifiable(checked));
}

SeoApprovalChecklistEvaluation? evaluateInitialSeoApprovalChecklistView(
  SeoApprovalChecklistViewProjection project,
  SeoApprovalChecklistState state, {
  required int itemCount,
}) {
  final result = evaluateInitialSeoApplication(
    state: state,
    canonicalizeState: (candidate) =>
        _canonicalSeoApprovalChecklistState(candidate, itemCount),
    project: project,
    validateView: _validateSeoApprovalChecklistView,
  );
  if (result == null) return null;
  return SeoApprovalChecklistEvaluation(
    state: result.state,
    view: result.view,
    accepted: result.accepted,
  );
}

SeoApprovalChecklistEvaluation? evaluateSeoApprovalChecklistAction({
  required SeoApprovalChecklistTransition transition,
  required SeoApprovalChecklistViewProjection project,
  required SeoApprovalChecklistEvaluation current,
  required SeoApprovalChecklistAction action,
  required int itemCount,
}) {
  final result = evaluateSeoApplicationAction(
    currentState: current.state,
    currentView: current.view,
    action: action,
    canonicalizeState: (candidate) =>
        _canonicalSeoApprovalChecklistState(candidate, itemCount),
    validateView: _validateSeoApprovalChecklistView,
    isActionAdmitted: (state, candidateAction) =>
        isSeoApprovalChecklistActionEnabled(
      state,
      candidateAction,
      itemCount,
    ),
    transition: transition,
    validateCandidate: (state, candidateAction, candidate) {
      final change = candidateAction as SeoApprovalChecklistSetItem;
      final flags = [...state.checked]..[change.index] = change.checked;
      final expected = SeoApprovalChecklistState(
        checked: List.unmodifiable(flags),
      );
      return candidate == expected ? expected : null;
    },
    project: project,
  );
  if (result == null) return null;
  return SeoApprovalChecklistEvaluation(
    state: result.state,
    view: result.view,
    accepted: result.accepted,
  );
}

SeoApprovalChecklistView? _validateSeoApprovalChecklistView(
  SeoApprovalChecklistView raw,
  SeoApprovalChecklistState _,
) {
  if (raw.statusText.length +
          raw.summaryText.length +
          raw.announcementText.length >
      seoApprovalChecklistMaxAggregateTextLength) {
    return null;
  }
  final status = canonicalizeSeoConfiguratorText(
    raw.statusText,
    maxLength: seoApprovalChecklistMaxStatusTextLength,
  );
  final summary = canonicalizeSeoConfiguratorText(
    raw.summaryText,
    maxLength: seoApprovalChecklistMaxSummaryTextLength,
  );
  final announcement = canonicalizeSeoConfiguratorText(
    raw.announcementText,
    maxLength: seoApprovalChecklistMaxAnnouncementTextLength,
  );
  if (status == null || summary == null || announcement == null) return null;
  return SeoApprovalChecklistView(
    statusText: status,
    summaryText: summary,
    announcementText: announcement,
  );
}

SeoApprovalChecklistState? _canonicalSeoApprovalChecklistState(
  SeoApprovalChecklistState state,
  int itemCount,
) =>
    isValidSeoApprovalChecklistState(state, itemCount)
        ? SeoApprovalChecklistState(
            checked: List.unmodifiable(state.checked),
          )
        : null;

bool _isValidItemCount(int itemCount) =>
    itemCount >= 1 && itemCount <= seoApprovalChecklistMaxItems;

bool _sameFlags(List<bool> left, List<bool> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
