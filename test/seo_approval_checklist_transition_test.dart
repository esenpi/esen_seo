import 'package:esen_seo/checklist.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('approval checklist transition', () {
    test('changes exactly one expected item per accepted action', () {
      var current = evaluateInitialSeoApprovalChecklistView(
        _view,
        initialSeoApprovalChecklistState(itemCount: 3)!,
        itemCount: 3,
      )!;

      for (final action in const [
        SeoApprovalChecklistSetItem(0, true),
        SeoApprovalChecklistSetItem(2, true),
        SeoApprovalChecklistSetItem(1, true),
        SeoApprovalChecklistSetItem(0, false),
      ]) {
        current = evaluateSeoApprovalChecklistAction(
          transition: transitionSeoApprovalChecklist,
          project: _view,
          current: current,
          action: action,
          itemCount: 3,
        )!;
        expect(current.accepted, isTrue);
      }

      expect(current.state.checked, [false, true, true]);
      expect(seoApprovalChecklistCheckedCount(current.state), 2);
      expect(isSeoApprovalChecklistComplete(current.state), isFalse);
    });

    test('invalid and repeated actions do not invoke application code', () {
      var transitionCalls = 0;
      var projectionCalls = 0;
      final current = _evaluation([false, false]);

      for (final action in const [
        SeoApprovalChecklistSetItem(-1, true),
        SeoApprovalChecklistSetItem(2, true),
        SeoApprovalChecklistSetItem(0, false),
      ]) {
        final result = evaluateSeoApprovalChecklistAction(
          transition: (state, action) {
            transitionCalls++;
            return transitionSeoApprovalChecklist(state, action);
          },
          project: (state) {
            projectionCalls++;
            return _view(state);
          },
          current: current,
          action: action,
          itemCount: 2,
        );
        expect(result?.accepted, isFalse);
      }
      expect(transitionCalls, 0);
      expect(projectionCalls, 0);
    });

    test('application transition cannot rewrite neighbouring flags', () {
      final current = _evaluation([false, false, false]);
      final result = evaluateSeoApprovalChecklistAction(
        transition: (_, __) => const SeoApprovalChecklistState(
          checked: [true, true, false],
        ),
        project: _view,
        current: current,
        action: const SeoApprovalChecklistSetItem(0, true),
        itemCount: 3,
      );

      expect(result?.accepted, isFalse);
      expect(result?.state.checked, [false, false, false]);
    });

    test('exceptions and invalid projection retain the complete snapshot', () {
      final current = _evaluation([false, false]);
      final thrown = evaluateSeoApprovalChecklistAction(
        transition: (_, __) => throw StateError('transition failed'),
        project: _view,
        current: current,
        action: const SeoApprovalChecklistSetItem(0, true),
        itemCount: 2,
      );
      final invalid = evaluateSeoApprovalChecklistAction(
        transition: transitionSeoApprovalChecklist,
        project: (_) => const SeoApprovalChecklistView(
          statusText: ' ',
          summaryText: 'Summary',
          announcementText: 'Announcement',
        ),
        current: current,
        action: const SeoApprovalChecklistSetItem(0, true),
        itemCount: 2,
      );

      for (final result in [thrown, invalid]) {
        expect(result?.accepted, isFalse);
        expect(result?.state, current.state);
        expect(result?.view, current.view);
      }
    });

    test('canonicalizes mutable state and validates item count', () {
      final mutable = [false, true];
      final initial = evaluateInitialSeoApprovalChecklistView(
        _view,
        SeoApprovalChecklistState(checked: mutable),
        itemCount: 2,
      )!;
      mutable[0] = true;

      expect(initial.state.checked, [false, true]);
      expect(() => initial.state.checked[0] = true, throwsUnsupportedError);
      expect(
        evaluateInitialSeoApprovalChecklistView(
          _view,
          const SeoApprovalChecklistState(checked: [false]),
          itemCount: 2,
        ),
        isNull,
      );
      expect(initialSeoApprovalChecklistState(itemCount: 0), isNull);
      expect(
        initialSeoApprovalChecklistState(
          itemCount: 2,
          checkedIndexes: const [0, 0],
        ),
        isNull,
      );
    });

    test('bounds raw text before bidi cleanup and rejects malformed UTF-16',
        () {
      final cleaned = evaluateInitialSeoApprovalChecklistView(
        (_) => const SeoApprovalChecklistView(
          statusText: 'Of\u202efen',
          summaryText: 'Noch offen',
          announcementText: 'Status offen',
        ),
        const SeoApprovalChecklistState(checked: [false]),
        itemCount: 1,
      );
      expect(cleaned?.view.statusText, 'Offen');

      for (final status in [
        '${List.filled(seoApprovalChecklistMaxStatusTextLength, 'x').join()}\u202e',
        'bad\ud800',
        '   ',
      ]) {
        expect(
          evaluateInitialSeoApprovalChecklistView(
            (_) => SeoApprovalChecklistView(
              statusText: status,
              summaryText: 'Summary',
              announcementText: 'Announcement',
            ),
            const SeoApprovalChecklistState(checked: [false]),
            itemCount: 1,
          ),
          isNull,
        );
      }
    });
  });
}

SeoApprovalChecklistEvaluation _evaluation(List<bool> checked) =>
    evaluateInitialSeoApprovalChecklistView(
      _view,
      SeoApprovalChecklistState(checked: checked),
      itemCount: checked.length,
    )!;

SeoApprovalChecklistView _view(SeoApprovalChecklistState state) {
  final count = seoApprovalChecklistCheckedCount(state);
  final complete = isSeoApprovalChecklistComplete(state);
  return SeoApprovalChecklistView(
    statusText: complete ? 'Bereit' : 'Offen',
    summaryText: '$count / ${state.checked.length} erledigt',
    announcementText: '$count Prüfpunkte erledigt',
  );
}
