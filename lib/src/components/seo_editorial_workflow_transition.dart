/// Pure editorial workflow state shared by native and browser presentations.
library;

import 'seo_configurator_transition.dart' show canonicalizeSeoConfiguratorText;

typedef SeoEditorialWorkflowTransition = SeoEditorialWorkflowState Function(
  SeoEditorialWorkflowState state,
  SeoEditorialWorkflowAction action,
);

typedef SeoEditorialWorkflowViewProjection = SeoEditorialWorkflowView Function(
  SeoEditorialWorkflowState state,
);

const int seoEditorialWorkflowMaxHistoryEntries = 32;
const int seoEditorialWorkflowMaxStatusTextLength = 128;
const int seoEditorialWorkflowMaxSummaryTextLength = 512;
const int seoEditorialWorkflowMaxAnnouncementTextLength = 512;
const int seoEditorialWorkflowMaxAggregateTextLength = 1024;

enum SeoEditorialWorkflowStage {
  draft,
  review,
  approved,
  published,
}

final class SeoEditorialWorkflowState {
  const SeoEditorialWorkflowState({
    required this.stage,
    required this.history,
  });

  final SeoEditorialWorkflowStage stage;
  final List<SeoEditorialWorkflowStage> history;

  @override
  bool operator ==(Object other) =>
      other is SeoEditorialWorkflowState &&
      other.stage == stage &&
      _sameStages(other.history, history);

  @override
  int get hashCode => Object.hash(stage, Object.hashAll(history));
}

sealed class SeoEditorialWorkflowAction {
  const SeoEditorialWorkflowAction();
}

final class SeoEditorialWorkflowSubmit extends SeoEditorialWorkflowAction {
  const SeoEditorialWorkflowSubmit();
}

final class SeoEditorialWorkflowApprove extends SeoEditorialWorkflowAction {
  const SeoEditorialWorkflowApprove();
}

final class SeoEditorialWorkflowReject extends SeoEditorialWorkflowAction {
  const SeoEditorialWorkflowReject();
}

final class SeoEditorialWorkflowPublish extends SeoEditorialWorkflowAction {
  const SeoEditorialWorkflowPublish();
}

final class SeoEditorialWorkflowView {
  const SeoEditorialWorkflowView({
    required this.statusText,
    required this.summaryText,
    required this.announcementText,
    required this.activeStageRegion,
  });

  final String statusText;
  final String summaryText;
  final String announcementText;
  final int activeStageRegion;

  @override
  bool operator ==(Object other) =>
      other is SeoEditorialWorkflowView &&
      other.statusText == statusText &&
      other.summaryText == summaryText &&
      other.announcementText == announcementText &&
      other.activeStageRegion == activeStageRegion;

  @override
  int get hashCode => Object.hash(
        statusText,
        summaryText,
        announcementText,
        activeStageRegion,
      );
}

final class SeoEditorialWorkflowEvaluation {
  const SeoEditorialWorkflowEvaluation({
    required this.state,
    required this.view,
    required this.accepted,
  });

  final SeoEditorialWorkflowState state;
  final SeoEditorialWorkflowView view;
  final bool accepted;

  @override
  bool operator ==(Object other) =>
      other is SeoEditorialWorkflowEvaluation &&
      other.state == state &&
      other.view == view &&
      other.accepted == accepted;

  @override
  int get hashCode => Object.hash(state, view, accepted);
}

const SeoEditorialWorkflowState initialSeoEditorialWorkflowState =
    SeoEditorialWorkflowState(
  stage: SeoEditorialWorkflowStage.draft,
  history: [SeoEditorialWorkflowStage.draft],
);

bool isValidSeoEditorialWorkflowState(SeoEditorialWorkflowState state) {
  final history = state.history;
  if (history.isEmpty ||
      history.length > seoEditorialWorkflowMaxHistoryEntries ||
      history.first != SeoEditorialWorkflowStage.draft ||
      history.last != state.stage) {
    return false;
  }
  for (var index = 1; index < history.length; index++) {
    if (!_isSeoEditorialWorkflowEdge(history[index - 1], history[index])) {
      return false;
    }
  }
  return true;
}

bool isSeoEditorialWorkflowActionEnabled(
  SeoEditorialWorkflowState state,
  SeoEditorialWorkflowAction action,
) =>
    isValidSeoEditorialWorkflowState(state) &&
    state.history.length < seoEditorialWorkflowMaxHistoryEntries &&
    _targetSeoEditorialWorkflowStage(state.stage, action) != null;

SeoEditorialWorkflowState transitionSeoEditorialWorkflow(
  SeoEditorialWorkflowState state,
  SeoEditorialWorkflowAction action,
) {
  if (!isSeoEditorialWorkflowActionEnabled(state, action)) return state;
  final target = _targetSeoEditorialWorkflowStage(state.stage, action)!;
  return SeoEditorialWorkflowState(
    stage: target,
    history: List.unmodifiable([...state.history, target]),
  );
}

SeoEditorialWorkflowEvaluation? evaluateInitialSeoEditorialWorkflowView(
  SeoEditorialWorkflowViewProjection project,
  SeoEditorialWorkflowState state,
) {
  final canonicalState = _canonicalSeoEditorialWorkflowState(state);
  if (canonicalState == null) return null;
  final view = _projectSeoEditorialWorkflowView(project, canonicalState);
  if (view == null) return null;
  return SeoEditorialWorkflowEvaluation(
    state: canonicalState,
    view: view,
    accepted: false,
  );
}

SeoEditorialWorkflowEvaluation? evaluateSeoEditorialWorkflowAction({
  required SeoEditorialWorkflowTransition transition,
  required SeoEditorialWorkflowViewProjection project,
  required SeoEditorialWorkflowEvaluation current,
  required SeoEditorialWorkflowAction action,
}) {
  final state = _canonicalSeoEditorialWorkflowState(current.state);
  if (state == null) return null;
  final currentView = _validateSeoEditorialWorkflowView(current.view, state);
  if (currentView == null || currentView != current.view) return null;
  final retained = SeoEditorialWorkflowEvaluation(
    state: state,
    view: currentView,
    accepted: false,
  );
  if (!isSeoEditorialWorkflowActionEnabled(state, action)) return retained;

  final target = _targetSeoEditorialWorkflowStage(state.stage, action)!;
  final expected = SeoEditorialWorkflowState(
    stage: target,
    history: List.unmodifiable([...state.history, target]),
  );
  final SeoEditorialWorkflowState candidate;
  try {
    candidate = transition(state, action);
  } catch (_) {
    return retained;
  }
  if (candidate != expected) return retained;

  final view = _projectSeoEditorialWorkflowView(project, expected);
  if (view == null) return retained;
  return SeoEditorialWorkflowEvaluation(
    state: expected,
    view: view,
    accepted: true,
  );
}

SeoEditorialWorkflowView? _projectSeoEditorialWorkflowView(
  SeoEditorialWorkflowViewProjection project,
  SeoEditorialWorkflowState state,
) {
  final SeoEditorialWorkflowView raw;
  try {
    raw = project(state);
  } catch (_) {
    return null;
  }
  return _validateSeoEditorialWorkflowView(raw, state);
}

SeoEditorialWorkflowView? _validateSeoEditorialWorkflowView(
  SeoEditorialWorkflowView raw,
  SeoEditorialWorkflowState state,
) {
  if (raw.activeStageRegion != state.stage.index) return null;
  if (raw.statusText.length +
          raw.summaryText.length +
          raw.announcementText.length >
      seoEditorialWorkflowMaxAggregateTextLength) {
    return null;
  }
  final status = canonicalizeSeoConfiguratorText(
    raw.statusText,
    maxLength: seoEditorialWorkflowMaxStatusTextLength,
  );
  final summary = canonicalizeSeoConfiguratorText(
    raw.summaryText,
    maxLength: seoEditorialWorkflowMaxSummaryTextLength,
  );
  final announcement = canonicalizeSeoConfiguratorText(
    raw.announcementText,
    maxLength: seoEditorialWorkflowMaxAnnouncementTextLength,
  );
  if (status == null || summary == null || announcement == null) return null;
  return SeoEditorialWorkflowView(
    statusText: status,
    summaryText: summary,
    announcementText: announcement,
    activeStageRegion: state.stage.index,
  );
}

SeoEditorialWorkflowState? _canonicalSeoEditorialWorkflowState(
  SeoEditorialWorkflowState state,
) {
  if (!isValidSeoEditorialWorkflowState(state)) return null;
  return SeoEditorialWorkflowState(
    stage: state.stage,
    history: List.unmodifiable(state.history),
  );
}

SeoEditorialWorkflowStage? _targetSeoEditorialWorkflowStage(
  SeoEditorialWorkflowStage stage,
  SeoEditorialWorkflowAction action,
) =>
    switch ((stage, action)) {
      (SeoEditorialWorkflowStage.draft, SeoEditorialWorkflowSubmit()) =>
        SeoEditorialWorkflowStage.review,
      (SeoEditorialWorkflowStage.review, SeoEditorialWorkflowApprove()) =>
        SeoEditorialWorkflowStage.approved,
      (
        SeoEditorialWorkflowStage.review || SeoEditorialWorkflowStage.approved,
        SeoEditorialWorkflowReject()
      ) =>
        SeoEditorialWorkflowStage.draft,
      (SeoEditorialWorkflowStage.approved, SeoEditorialWorkflowPublish()) =>
        SeoEditorialWorkflowStage.published,
      _ => null,
    };

bool _isSeoEditorialWorkflowEdge(
  SeoEditorialWorkflowStage from,
  SeoEditorialWorkflowStage to,
) =>
    switch ((from, to)) {
      (SeoEditorialWorkflowStage.draft, SeoEditorialWorkflowStage.review) ||
      (SeoEditorialWorkflowStage.review, SeoEditorialWorkflowStage.approved) ||
      (SeoEditorialWorkflowStage.review, SeoEditorialWorkflowStage.draft) ||
      (SeoEditorialWorkflowStage.approved, SeoEditorialWorkflowStage.draft) ||
      (
        SeoEditorialWorkflowStage.approved,
        SeoEditorialWorkflowStage.published
      ) =>
        true,
      _ => false,
    };

bool _sameStages(
  List<SeoEditorialWorkflowStage> left,
  List<SeoEditorialWorkflowStage> right,
) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
