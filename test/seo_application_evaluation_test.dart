import 'package:esen_seo/src/components/seo_application_evaluation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('internal application evaluation', () {
    test('canonicalizes and validates the initial snapshot', () {
      final result = evaluateInitialSeoApplication<int, String>(
        state: 2,
        canonicalizeState: (state) => state.clamp(0, 3),
        project: (state) => 'state:$state',
        validateView: (view, state) => view == 'state:$state' ? view : null,
      );

      expect(result?.state, 2);
      expect(result?.view, 'state:2');
      expect(result?.accepted, isFalse);
    });

    test('rejects invalid state and throwing initial projection', () {
      expect(
        evaluateInitialSeoApplication<int, String>(
          state: -1,
          canonicalizeState: (_) => null,
          project: (_) => 'unused',
          validateView: (view, _) => view,
        ),
        isNull,
      );
      expect(
        evaluateInitialSeoApplication<int, String>(
          state: 0,
          canonicalizeState: (state) => state,
          project: (_) => throw StateError('projection failed'),
          validateView: (view, _) => view,
        ),
        isNull,
      );
    });

    test('does not invoke application code for an inadmissible action', () {
      var transitionCalls = 0;
      var projectionCalls = 0;
      final result = evaluateSeoApplicationAction<int, int, String>(
        currentState: 1,
        currentView: 'state:1',
        action: 4,
        canonicalizeState: (state) => state,
        validateView: (view, state) => view == 'state:$state' ? view : null,
        isActionAdmitted: (_, __) => false,
        transition: (state, action) {
          transitionCalls++;
          return state + action;
        },
        validateCandidate: (_, __, candidate) => candidate,
        project: (state) {
          projectionCalls++;
          return 'state:$state';
        },
      );

      expect(result?.state, 1);
      expect(result?.view, 'state:1');
      expect(result?.accepted, isFalse);
      expect(transitionCalls, 0);
      expect(projectionCalls, 0);
    });

    test('refuses stale current view before transition', () {
      var transitionCalls = 0;
      final result = evaluateSeoApplicationAction<int, int, String>(
        currentState: 1,
        currentView: 'stale',
        action: 1,
        canonicalizeState: (state) => state,
        validateView: (view, state) => view == 'state:$state' ? view : null,
        isActionAdmitted: (_, __) => true,
        transition: (state, action) {
          transitionCalls++;
          return state + action;
        },
        validateCandidate: (_, __, candidate) => candidate,
        project: (state) => 'state:$state',
      );

      expect(result, isNull);
      expect(transitionCalls, 0);
    });

    test('retains atomically for thrown or invalid candidates', () {
      SeoApplicationEvaluation<int, String>? evaluate({
        required int Function(int, int) transition,
        required int? Function(int, int, int) validateCandidate,
      }) =>
          evaluateSeoApplicationAction(
            currentState: 1,
            currentView: 'state:1',
            action: 1,
            canonicalizeState: (state) => state,
            validateView: (view, state) => view == 'state:$state' ? view : null,
            isActionAdmitted: (_, __) => true,
            transition: transition,
            validateCandidate: validateCandidate,
            project: (state) => 'state:$state',
          );

      final thrown = evaluate(
        transition: (_, __) => throw StateError('transition failed'),
        validateCandidate: (_, __, candidate) => candidate,
      );
      final invalid = evaluate(
        transition: (state, action) => state + action,
        validateCandidate: (_, __, ___) => null,
      );

      for (final result in [thrown, invalid]) {
        expect(result?.state, 1);
        expect(result?.view, 'state:1');
        expect(result?.accepted, isFalse);
      }
    });

    test('retains when candidate projection throws or is invalid', () {
      SeoApplicationEvaluation<int, String>? evaluate(
        String Function(int) project,
      ) =>
          evaluateSeoApplicationAction(
            currentState: 1,
            currentView: 'state:1',
            action: 1,
            canonicalizeState: (state) => state,
            validateView: (view, state) => view == 'state:$state' ? view : null,
            isActionAdmitted: (_, __) => true,
            transition: (state, action) => state + action,
            validateCandidate: (_, __, candidate) => candidate,
            project: project,
          );

      expect(evaluate((_) => throw StateError('projection failed'))?.accepted,
          isFalse);
      expect(evaluate((_) => 'wrong')?.accepted, isFalse);
    });

    test('returns one accepted atomic candidate', () {
      final result = evaluateSeoApplicationAction<int, int, String>(
        currentState: 1,
        currentView: 'state:1',
        action: 2,
        canonicalizeState: (state) => state,
        validateView: (view, state) => view == 'state:$state' ? view : null,
        isActionAdmitted: (_, __) => true,
        transition: (state, action) => state + action,
        validateCandidate: (previous, action, candidate) =>
            candidate == previous + action ? candidate : null,
        project: (state) => 'state:$state',
      );

      expect(result?.state, 3);
      expect(result?.view, 'state:3');
      expect(result?.accepted, isTrue);
    });
  });
}
