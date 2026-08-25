import 'dart:ui' show SemanticsFlag;

import 'package:esen_seo/workflow_flutter.dart';
import 'package:esen_seo/esen_seo.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsData;
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  setUp(enableSeoForTests);

  testWidgets('native initial view and semantic source share one plan',
      (tester) async {
    await _pump(tester, _widget());
    final state = tester.state(find.byType(SeoEditorialWorkflow))
        as SeoBlockState<SeoEditorialWorkflow>;
    final actual = const HtmlRenderer().render(state.toSeoNodes());
    final expected = const HtmlRenderer().render(
      buildSeoEditorialWorkflowNodes(
        stages: _nodeStages(),
        initialState: initialSeoEditorialWorkflowState,
        project: _view,
        interactionId: 'article-workflow',
        heading: 'Freigabeprozess',
        submitLabel: 'Zur Prüfung',
        approveLabel: 'Freigeben',
        rejectLabel: 'Ablehnen',
        publishLabel: 'Veröffentlichen',
      ),
    );
    expect(actual, expected);
    expect(find.text('Status: Entwurf'), findsOneWidget);
    expect(find.text('Entwurf bearbeiten'), findsOneWidget);
  });

  testWidgets('frozen action sequence matches the pure state history',
      (tester) async {
    final changes = <SeoEditorialWorkflowEvaluation>[];
    await _pump(tester, _widget(onChanged: changes.add));

    for (final (label, status) in const [
      ('Zur Prüfung', 'Status: Prüfung'),
      ('Ablehnen', 'Status: Entwurf'),
      ('Zur Prüfung', 'Status: Prüfung'),
      ('Freigeben', 'Status: Freigegeben'),
      ('Ablehnen', 'Status: Entwurf'),
      ('Zur Prüfung', 'Status: Prüfung'),
      ('Freigeben', 'Status: Freigegeben'),
      ('Veröffentlichen', 'Status: Veröffentlicht'),
    ]) {
      await tester.tap(find.widgetWithText(OutlinedButton, label));
      await tester.pump();
      expect(find.text(status), findsOneWidget);
    }

    expect(changes, hasLength(8));
    expect(changes.last.state.stage, SeoEditorialWorkflowStage.published);
    expect(changes.last.state.history, hasLength(9));
    for (final label in const [
      'Zur Prüfung',
      'Freigeben',
      'Ablehnen',
      'Veröffentlichen',
    ]) {
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, label),
            )
            .onPressed,
        isNull,
      );
    }
  });

  testWidgets('only graph-admitted native actions are enabled', (tester) async {
    await _pump(tester, _widget());
    expect(_enabled(tester, 'Zur Prüfung'), isTrue);
    expect(_enabled(tester, 'Freigeben'), isFalse);
    expect(_enabled(tester, 'Ablehnen'), isFalse);
    expect(_enabled(tester, 'Veröffentlichen'), isFalse);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Zur Prüfung'));
    await tester.pump();
    expect(_enabled(tester, 'Zur Prüfung'), isFalse);
    expect(_enabled(tester, 'Freigeben'), isTrue);
    expect(_enabled(tester, 'Ablehnen'), isTrue);
    expect(_enabled(tester, 'Veröffentlichen'), isFalse);
  });

  testWidgets('invalid application candidate never partially updates native UI',
      (tester) async {
    await _pump(
      tester,
      _widget(
        transition: (state, action) => const SeoEditorialWorkflowState(
          stage: SeoEditorialWorkflowStage.published,
          history: [
            SeoEditorialWorkflowStage.draft,
            SeoEditorialWorkflowStage.review,
            SeoEditorialWorkflowStage.approved,
            SeoEditorialWorkflowStage.published,
          ],
        ),
      ),
    );
    await tester.tap(find.widgetWithText(OutlinedButton, 'Zur Prüfung'));
    await tester.pump();
    expect(find.text('Status: Entwurf'), findsOneWidget);
    expect(find.text('Entwurf bearbeiten'), findsOneWidget);
    expect(find.text('2. Prüfung'), findsNothing);
  });

  testWidgets('progress and live status expose native semantics',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, _widget());
    final draft =
        tester.getSemantics(find.byType(Chip).first).getSemanticsData();
    expect(_hasFlag(draft, SemanticsFlag.isSelected), isTrue);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Zur Prüfung'));
    await tester.pump();
    final live = tester
        .getSemantics(find.bySemanticsLabel('Status Prüfung'))
        .getSemanticsData();
    expect(_hasFlag(live, SemanticsFlag.isLiveRegion), isTrue);
    semantics.dispose();
  });

  testWidgets('semantic mirror remains at the initial state after interaction',
      (tester) async {
    await _pump(tester, _widget());
    final state = tester.state(find.byType(SeoEditorialWorkflow))
        as SeoBlockState<SeoEditorialWorkflow>;
    final before = const HtmlRenderer().render(state.toSeoNodes());
    await tester.tap(find.widgetWithText(OutlinedButton, 'Zur Prüfung'));
    await tester.pump();
    final after = const HtmlRenderer().render(state.toSeoNodes());
    expect(after, before);
    expect(after, contains('data-esen-initial-stage="0"'));
  });
}

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
      MaterialApp(home: Scaffold(body: child)),
    );

SeoEditorialWorkflow _widget({
  SeoEditorialWorkflowTransition transition = transitionSeoEditorialWorkflow,
  ValueChanged<SeoEditorialWorkflowEvaluation>? onChanged,
}) =>
    SeoEditorialWorkflow(
      stages: [
        for (final stage in _nodeStages())
          SeoEditorialWorkflowStageContent(
            label: stage.label,
            content: Text(stage.nodes.single.text!),
            nodes: stage.nodes,
          ),
      ],
      initialState: initialSeoEditorialWorkflowState,
      transition: transition,
      project: _view,
      interactionId: 'article-workflow',
      heading: 'Freigabeprozess',
      submitLabel: 'Zur Prüfung',
      approveLabel: 'Freigeben',
      rejectLabel: 'Ablehnen',
      publishLabel: 'Veröffentlichen',
      onChanged: onChanged,
    );

List<SeoEditorialWorkflowStageEntry> _nodeStages() => [
      (
        label: 'Entwurf',
        nodes: [SeoNode(tag: 'p', text: 'Entwurf bearbeiten')],
      ),
      (
        label: 'Prüfung',
        nodes: [SeoNode(tag: 'p', text: 'Inhalt prüfen')],
      ),
      (
        label: 'Freigegeben',
        nodes: [SeoNode(tag: 'p', text: 'Freigabe dokumentiert')],
      ),
      (
        label: 'Veröffentlicht',
        nodes: [SeoNode(tag: 'p', text: 'Beitrag öffentlich')],
      ),
    ];

SeoEditorialWorkflowView _view(SeoEditorialWorkflowState state) {
  const labels = ['Entwurf', 'Prüfung', 'Freigegeben', 'Veröffentlicht'];
  final label = labels[state.stage.index];
  return SeoEditorialWorkflowView(
    statusText: label,
    summaryText: '$label · ${state.history.length} Stationen',
    announcementText: 'Status $label',
    activeStageRegion: state.stage.index,
  );
}

bool _enabled(WidgetTester tester, String label) =>
    tester
        .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, label))
        .onPressed !=
    null;

bool _hasFlag(SemanticsData data, SemanticsFlag flag) {
  // Flutter 3.27 does not expose SemanticsData.flagsCollection yet.
  // ignore: deprecated_member_use
  return data.hasFlag(flag);
}
