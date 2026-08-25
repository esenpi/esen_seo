/// Package-internal atomic evaluation shared by curated application slices.
library;

typedef SeoApplicationStateCanonicalizer<State> = State? Function(State state);
typedef SeoApplicationViewProjection<State, View> = View Function(State state);
typedef SeoApplicationViewValidator<State, View> = View? Function(
  View view,
  State state,
);
typedef SeoApplicationActionAdmission<State, Action> = bool Function(
  State state,
  Action action,
);
typedef SeoApplicationTransition<State, Action> = State Function(
  State state,
  Action action,
);
typedef SeoApplicationCandidateValidator<State, Action> = State? Function(
  State current,
  Action action,
  State candidate,
);

final class SeoApplicationEvaluation<State, View> {
  const SeoApplicationEvaluation({
    required this.state,
    required this.view,
    required this.accepted,
  });

  final State state;
  final View view;
  final bool accepted;
}

SeoApplicationEvaluation<State, View>?
    evaluateInitialSeoApplication<State, View>({
  required State state,
  required SeoApplicationStateCanonicalizer<State> canonicalizeState,
  required SeoApplicationViewProjection<State, View> project,
  required SeoApplicationViewValidator<State, View> validateView,
}) {
  final canonicalState = canonicalizeState(state);
  if (canonicalState == null) return null;
  final view = _projectSeoApplicationView(
    state: canonicalState,
    project: project,
    validateView: validateView,
  );
  if (view == null) return null;
  return SeoApplicationEvaluation(
    state: canonicalState,
    view: view,
    accepted: false,
  );
}

SeoApplicationEvaluation<State, View>?
    evaluateSeoApplicationAction<State, Action, View>({
  required State currentState,
  required View currentView,
  required Action action,
  required SeoApplicationStateCanonicalizer<State> canonicalizeState,
  required SeoApplicationViewValidator<State, View> validateView,
  required SeoApplicationActionAdmission<State, Action> isActionAdmitted,
  required SeoApplicationTransition<State, Action> transition,
  required SeoApplicationCandidateValidator<State, Action> validateCandidate,
  required SeoApplicationViewProjection<State, View> project,
}) {
  final state = canonicalizeState(currentState);
  if (state == null) return null;
  final view = validateView(currentView, state);
  if (view == null || view != currentView) return null;
  final retained = SeoApplicationEvaluation(
    state: state,
    view: view,
    accepted: false,
  );
  if (!isActionAdmitted(state, action)) return retained;

  final State rawCandidate;
  try {
    rawCandidate = transition(state, action);
  } catch (_) {
    return retained;
  }
  final candidate = validateCandidate(state, action, rawCandidate);
  if (candidate == null) return retained;
  final nextView = _projectSeoApplicationView(
    state: candidate,
    project: project,
    validateView: validateView,
  );
  if (nextView == null) return retained;
  return SeoApplicationEvaluation(
    state: candidate,
    view: nextView,
    accepted: true,
  );
}

View? _projectSeoApplicationView<State, View>({
  required State state,
  required SeoApplicationViewProjection<State, View> project,
  required SeoApplicationViewValidator<State, View> validateView,
}) {
  final View raw;
  try {
    raw = project(state);
  } catch (_) {
    return null;
  }
  return validateView(raw, state);
}
