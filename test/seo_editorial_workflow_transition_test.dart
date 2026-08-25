import 'package:esen_seo/workflow.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('editorial workflow transition', () {
    test('frozen branching sequence preserves an append-only history', () {
      var current = evaluateInitialSeoEditorialWorkflowView(
        _view,
        initialSeoEditorialWorkflowState,
      )!;
      final actions = <SeoEditorialWorkflowAction>[
        const SeoEditorialWorkflowSubmit(),
        const SeoEditorialWorkflowReject(),
        const SeoEditorialWorkflowSubmit(),
        const SeoEditorialWorkflowApprove(),
        const SeoEditorialWorkflowReject(),
        const SeoEditorialWorkflowSubmit(),
        const SeoEditorialWorkflowApprove(),
        const SeoEditorialWorkflowPublish(),
      ];
      final expected = [
        SeoEditorialWorkflowStage.review,
        SeoEditorialWorkflowStage.draft,
        SeoEditorialWorkflowStage.review,
        SeoEditorialWorkflowStage.approved,
        SeoEditorialWorkflowStage.draft,
        SeoEditorialWorkflowStage.review,
        SeoEditorialWorkflowStage.approved,
        SeoEditorialWorkflowStage.published,
      ];

      for (var index = 0; index < actions.length; index++) {
        current = evaluateSeoEditorialWorkflowAction(
          transition: transitionSeoEditorialWorkflow,
          project: _view,
          current: current,
          action: actions[index],
        )!;
        expect(current.accepted, isTrue);
        expect(current.state.stage, expected[index]);
        expect(current.state.history.last, expected[index]);
        expect(current.state.history, hasLength(index + 2));
      }

      expect(current.state.history, [
        SeoEditorialWorkflowStage.draft,
        ...expected,
      ]);
    });

    test('package graph refuses illegal and terminal actions before app code',
        () {
      var transitionCalls = 0;
      var projectionCalls = 0;
      SeoEditorialWorkflowState transition(
        SeoEditorialWorkflowState state,
        SeoEditorialWorkflowAction action,
      ) {
        transitionCalls++;
        return transitionSeoEditorialWorkflow(state, action);
      }

      SeoEditorialWorkflowView project(SeoEditorialWorkflowState state) {
        projectionCalls++;
        return _view(state);
      }

      final draft = evaluateInitialSeoEditorialWorkflowView(
          project, initialSeoEditorialWorkflowState)!;
      projectionCalls = 0;
      final refused = evaluateSeoEditorialWorkflowAction(
        transition: transition,
        project: project,
        current: draft,
        action: const SeoEditorialWorkflowPublish(),
      )!;
      expect(refused.accepted, isFalse);
      expect(transitionCalls, 0);
      expect(projectionCalls, 0);

      final published = _evaluation(SeoEditorialWorkflowState(
        stage: SeoEditorialWorkflowStage.published,
        history: const [
          SeoEditorialWorkflowStage.draft,
          SeoEditorialWorkflowStage.review,
          SeoEditorialWorkflowStage.approved,
          SeoEditorialWorkflowStage.published,
        ],
      ));
      for (final action in const <SeoEditorialWorkflowAction>[
        SeoEditorialWorkflowSubmit(),
        SeoEditorialWorkflowApprove(),
        SeoEditorialWorkflowReject(),
        SeoEditorialWorkflowPublish(),
      ]) {
        expect(
          evaluateSeoEditorialWorkflowAction(
            transition: transition,
            project: project,
            current: published,
            action: action,
          )?.accepted,
          isFalse,
        );
      }
      expect(transitionCalls, 0);
      expect(projectionCalls, 0);
    });

    test('transition cannot skip, rewrite, truncate or duplicate history', () {
      final current = _evaluation(initialSeoEditorialWorkflowState);
      final candidates = <SeoEditorialWorkflowState Function()>[
        () => const SeoEditorialWorkflowState(
              stage: SeoEditorialWorkflowStage.approved,
              history: [
                SeoEditorialWorkflowStage.draft,
                SeoEditorialWorkflowStage.review,
                SeoEditorialWorkflowStage.approved,
              ],
            ),
        () => const SeoEditorialWorkflowState(
              stage: SeoEditorialWorkflowStage.review,
              history: [SeoEditorialWorkflowStage.review],
            ),
        () => const SeoEditorialWorkflowState(
              stage: SeoEditorialWorkflowStage.review,
              history: [
                SeoEditorialWorkflowStage.draft,
                SeoEditorialWorkflowStage.review,
                SeoEditorialWorkflowStage.review,
              ],
            ),
        () => const SeoEditorialWorkflowState(
              stage: SeoEditorialWorkflowStage.draft,
              history: [SeoEditorialWorkflowStage.draft],
            ),
      ];
      for (final candidate in candidates) {
        final result = evaluateSeoEditorialWorkflowAction(
          transition: (_, __) => candidate(),
          project: _view,
          current: current,
          action: const SeoEditorialWorkflowSubmit(),
        )!;
        expect(result.accepted, isFalse);
        expect(result.state, initialSeoEditorialWorkflowState);
      }
    });

    test('exceptions and invalid projected values retain the full snapshot',
        () {
      final current = _evaluation(initialSeoEditorialWorkflowState);
      final thrown = evaluateSeoEditorialWorkflowAction(
        transition: (_, __) => throw StateError('no'),
        project: _view,
        current: current,
        action: const SeoEditorialWorkflowSubmit(),
      )!;
      expect(thrown.accepted, isFalse);
      expect(thrown.state, current.state);
      expect(thrown.view, current.view);

      final invalid = evaluateSeoEditorialWorkflowAction(
        transition: transitionSeoEditorialWorkflow,
        project: (state) => SeoEditorialWorkflowView(
          statusText: 'Review',
          summaryText: 'Ready',
          announcementText: 'Moved',
          activeStageRegion: state.stage.index + 1,
        ),
        current: current,
        action: const SeoEditorialWorkflowSubmit(),
      )!;
      expect(invalid.accepted, isFalse);
      expect(invalid.state, current.state);
    });

    test('text is bounded before bidi cleanup and malformed UTF-16 is refused',
        () {
      final cleaned = evaluateInitialSeoEditorialWorkflowView(
        (_) => const SeoEditorialWorkflowView(
          statusText: 'Ent\u202ewurf',
          summaryText: 'Bereit',
          announcementText: 'Status Entwurf',
          activeStageRegion: 0,
        ),
        initialSeoEditorialWorkflowState,
      );
      expect(cleaned?.view.statusText, 'Entwurf');

      for (final status in [
        '${List.filled(seoEditorialWorkflowMaxStatusTextLength, 'x').join()}\u202e',
        'bad\ud800',
        '   ',
      ]) {
        expect(
          evaluateInitialSeoEditorialWorkflowView(
            (_) => SeoEditorialWorkflowView(
              statusText: status,
              summaryText: 'Summary',
              announcementText: 'Announcement',
              activeStageRegion: 0,
            ),
            initialSeoEditorialWorkflowState,
          ),
          isNull,
        );
      }
    });

    test('invalid or externally mutated current state fails closed', () {
      final mutable = [SeoEditorialWorkflowStage.draft];
      final initial = evaluateInitialSeoEditorialWorkflowView(
        _view,
        SeoEditorialWorkflowState(
          stage: SeoEditorialWorkflowStage.draft,
          history: mutable,
        ),
      )!;
      mutable.add(SeoEditorialWorkflowStage.review);
      expect(initial.state.history, [SeoEditorialWorkflowStage.draft]);
      expect(() => initial.state.history.add(SeoEditorialWorkflowStage.review),
          throwsUnsupportedError);

      final invalid = SeoEditorialWorkflowEvaluation(
        state: const SeoEditorialWorkflowState(
          stage: SeoEditorialWorkflowStage.review,
          history: [SeoEditorialWorkflowStage.draft],
        ),
        view: initial.view,
        accepted: false,
      );
      expect(
        evaluateSeoEditorialWorkflowAction(
          transition: transitionSeoEditorialWorkflow,
          project: _view,
          current: invalid,
          action: const SeoEditorialWorkflowApprove(),
        ),
        isNull,
      );
    });

    test('history cap disables every otherwise legal action', () {
      final history = <SeoEditorialWorkflowStage>[
        SeoEditorialWorkflowStage.draft,
      ];
      for (var index = 1;
          index < seoEditorialWorkflowMaxHistoryEntries;
          index++) {
        history.add(index.isOdd
            ? SeoEditorialWorkflowStage.review
            : SeoEditorialWorkflowStage.draft);
      }
      final state = SeoEditorialWorkflowState(
        stage: SeoEditorialWorkflowStage.review,
        history: history,
      );
      expect(isValidSeoEditorialWorkflowState(state), isTrue);
      expect(
        isSeoEditorialWorkflowActionEnabled(
          state,
          const SeoEditorialWorkflowApprove(),
        ),
        isFalse,
      );
    });
  });
}

SeoEditorialWorkflowEvaluation _evaluation(SeoEditorialWorkflowState state) =>
    evaluateInitialSeoEditorialWorkflowView(_view, state)!;

SeoEditorialWorkflowView _view(SeoEditorialWorkflowState state) {
  final label = switch (state.stage) {
    SeoEditorialWorkflowStage.draft => 'Entwurf',
    SeoEditorialWorkflowStage.review => 'Prüfung',
    SeoEditorialWorkflowStage.approved => 'Freigegeben',
    SeoEditorialWorkflowStage.published => 'Veröffentlicht',
  };
  return SeoEditorialWorkflowView(
    statusText: label,
    summaryText: '$label · ${state.history.length} Stationen',
    announcementText: 'Status $label',
    activeStageRegion: state.stage.index,
  );
}
