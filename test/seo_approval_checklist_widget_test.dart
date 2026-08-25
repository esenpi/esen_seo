import 'dart:ui' show SemanticsFlag;

import 'package:esen_seo/checklist_flutter.dart';
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
    final state = tester.state(find.byType(SeoApprovalChecklist))
        as SeoBlockState<SeoApprovalChecklist>;
    final actual = const HtmlRenderer().render(state.toSeoNodes());
    final expected = const HtmlRenderer().render(
      buildSeoApprovalChecklistNodes(
        items: _nodeItems(),
        initialState: _initial,
        project: _view,
        interactionId: 'article-checklist',
        heading: 'Freigabe-Checkliste',
        statusLabel: 'Freigabestatus',
        progressLabel: 'Prüffortschritt',
      ),
    );

    expect(actual, expected);
    expect(find.text('Freigabestatus: Offen'), findsOneWidget);
    expect(find.text('Titel und Teaser prüfen'), findsOneWidget);
  });

  testWidgets('native controls follow the shared atomic state', (tester) async {
    final changes = <SeoApprovalChecklistEvaluation>[];
    await _pump(tester, _widget(onChanged: changes.add));

    await tester.tap(find.widgetWithText(CheckboxListTile, 'Inhalt'));
    await tester.pump();
    expect(find.text('2 / 3 erledigt'), findsOneWidget);

    await tester.tap(find.widgetWithText(CheckboxListTile, 'SEO'));
    await tester.pump();
    expect(find.text('Freigabestatus: Bereit'), findsOneWidget);
    expect(changes, hasLength(2));
    expect(changes.last.state.checked, [true, true, true]);
  });

  testWidgets('rewritten neighbouring state never partially updates native UI',
      (tester) async {
    await _pump(
      tester,
      _widget(
        transition: (_, __) => const SeoApprovalChecklistState(
          checked: [true, false, true],
        ),
      ),
    );

    await tester.tap(find.widgetWithText(CheckboxListTile, 'Inhalt'));
    await tester.pump();
    expect(find.text('1 / 3 erledigt'), findsOneWidget);
    expect(find.text('Freigabestatus: Offen'), findsOneWidget);
  });

  testWidgets('progress and live update expose native semantics',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, _widget());
    expect(find.bySemanticsLabel('Prüffortschritt'), findsOneWidget);

    await tester.tap(find.widgetWithText(CheckboxListTile, 'Inhalt'));
    await tester.pump();
    final live = tester
        .getSemantics(find.bySemanticsLabel('2 Prüfpunkte erledigt'))
        .getSemanticsData();
    expect(_hasFlag(live, SemanticsFlag.isLiveRegion), isTrue);
    semantics.dispose();
  });

  testWidgets('semantic mirror remains at the initial state after interaction',
      (tester) async {
    await _pump(tester, _widget());
    final state = tester.state(find.byType(SeoApprovalChecklist))
        as SeoBlockState<SeoApprovalChecklist>;
    final before = const HtmlRenderer().render(state.toSeoNodes());
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Inhalt'));
    await tester.pump();
    final after = const HtmlRenderer().render(state.toSeoNodes());
    expect(after, before);
    expect(after, contains('data-esen-initial-checked="0,1,0"'));
  });
}

const _initial = SeoApprovalChecklistState(
  checked: [false, true, false],
);

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
      MaterialApp(home: Scaffold(body: child)),
    );

SeoApprovalChecklist _widget({
  SeoApprovalChecklistTransition transition = transitionSeoApprovalChecklist,
  ValueChanged<SeoApprovalChecklistEvaluation>? onChanged,
}) =>
    SeoApprovalChecklist(
      items: [
        for (final item in _nodeItems())
          SeoApprovalChecklistItemContent(
            label: item.label,
            content: Text(item.nodes.single.text!),
            nodes: item.nodes,
          ),
      ],
      initialState: _initial,
      transition: transition,
      project: _view,
      interactionId: 'article-checklist',
      heading: 'Freigabe-Checkliste',
      statusLabel: 'Freigabestatus',
      progressLabel: 'Prüffortschritt',
      onChanged: onChanged,
    );

List<SeoApprovalChecklistItemEntry> _nodeItems() => [
      (
        label: 'Inhalt',
        nodes: [SeoNode(tag: 'p', text: 'Titel und Teaser prüfen')],
      ),
      (
        label: 'Quellen',
        nodes: [SeoNode(tag: 'p', text: 'Quellen nachvollziehen')],
      ),
      (
        label: 'SEO',
        nodes: [SeoNode(tag: 'p', text: 'Metadaten vervollständigen')],
      ),
    ];

SeoApprovalChecklistView _view(SeoApprovalChecklistState state) {
  final count = seoApprovalChecklistCheckedCount(state);
  return SeoApprovalChecklistView(
    statusText: isSeoApprovalChecklistComplete(state) ? 'Bereit' : 'Offen',
    summaryText: '$count / ${state.checked.length} erledigt',
    announcementText: '$count Prüfpunkte erledigt',
  );
}

bool _hasFlag(SemanticsData data, SemanticsFlag flag) {
  // Flutter 3.27 does not expose SemanticsData.flagsCollection yet.
  // ignore: deprecated_member_use
  return data.hasFlag(flag);
}
