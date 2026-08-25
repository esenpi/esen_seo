import 'package:esen_seo/core.dart';
import 'package:esen_seo/workflow.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('builder emits complete no-script content from one validated plan', () {
    final html = _html(interactionId: 'article-workflow');

    expect(html, contains('data-esen-component="editorial-workflow"'));
    expect(html, contains('data-esen-initial-stage="0"'));
    expect(html, contains('data-esen-initial-history="0"'));
    expect(html, contains('data-esen-prepaint-placeholder='));
    expect(html, contains('aria-current="step"'));
    expect(html, contains('Entwurf bearbeiten'));
    expect(html, contains('Redaktion prüft Inhalt und Quellen'));
    expect(html, contains('Freigabe ist dokumentiert'));
    expect(html, contains('Beitrag ist öffentlich'));
    expect('data-esen-workflow-stage-region'.allMatches(html), hasLength(4));
    expect('data-esen-workflow-progress-stage'.allMatches(html), hasLength(4));
    expect('data-esen-workflow-history-stage'.allMatches(html), hasLength(1));
    expect('aria-live="polite"'.allMatches(html), hasLength(1));
  });

  test('missing or invalid id keeps the same content completely static', () {
    for (final id in <String?>[null, 'Invalid ID']) {
      final html = _html(interactionId: id);
      expect(html, contains('Entwurf bearbeiten'));
      expect(html, contains('Beitrag ist öffentlich'));
      expect(html, isNot(contains('data-esen-component')));
      expect(html, isNot(contains('data-esen-workflow-')));
      expect(html, isNot(contains('aria-live')));
    }
  });

  test('builder preserves a complete valid initial history', () {
    const state = SeoEditorialWorkflowState(
      stage: SeoEditorialWorkflowStage.approved,
      history: [
        SeoEditorialWorkflowStage.draft,
        SeoEditorialWorkflowStage.review,
        SeoEditorialWorkflowStage.approved,
      ],
    );
    final html = _html(
      interactionId: 'article-workflow',
      initialState: state,
    );
    expect(html, contains('data-esen-initial-stage="2"'));
    expect(html, contains('data-esen-initial-history="0,1,2"'));
    expect('data-esen-workflow-history-stage'.allMatches(html), hasLength(3));
    expect(
        html,
        contains('data-esen-workflow-progress-stage="2" '
            'aria-current="step"'));
  });

  test('invalid labels, duplicate stages and invalid projection emit nothing',
      () {
    final stages = _stages();
    expect(
      buildSeoEditorialWorkflowNodes(
        stages: stages.take(3).toList(),
        initialState: initialSeoEditorialWorkflowState,
        project: _view,
      ),
      isEmpty,
    );
    expect(
      buildSeoEditorialWorkflowNodes(
        stages: [
          ...stages.take(3),
          (label: 'Freigegeben', nodes: stages.last.nodes),
        ],
        initialState: initialSeoEditorialWorkflowState,
        project: _view,
      ),
      isEmpty,
    );
    expect(
      buildSeoEditorialWorkflowNodes(
        stages: stages,
        initialState: initialSeoEditorialWorkflowState,
        project: (_) => const SeoEditorialWorkflowView(
          statusText: 'Entwurf',
          summaryText: 'Bereit',
          announcementText: 'Bereit',
          activeStageRegion: 3,
        ),
      ),
      isEmpty,
    );
  });

  test('placeholder fixes all four controls and their initial availability',
      () {
    final html = _html(interactionId: 'article-workflow');
    expect(
      'esen-seo-editorial-workflow-control-placeholder'.allMatches(html),
      hasLength(4),
    );
    expect('data-esen-placeholder-disabled'.allMatches(html), hasLength(3));
    expect(html, contains('Zur Prüfung geben'));
    expect(html, contains('Freigeben'));
    expect(html, contains('Ablehnen'));
    expect(html, contains('Veröffentlichen'));
  });
}

String _html({
  String? interactionId,
  SeoEditorialWorkflowState initialState = initialSeoEditorialWorkflowState,
}) =>
    const HtmlRenderer().render(buildSeoEditorialWorkflowNodes(
      stages: _stages(),
      initialState: initialState,
      project: _view,
      interactionId: interactionId,
      headingLevel: 1,
      heading: 'Redaktioneller Freigabeprozess',
      interactionLabel: 'Freigabeprozess für einen Artikel',
      statusLabel: 'Aktueller Status',
      progressLabel: 'Freigabefortschritt',
      historyLabel: 'Statusverlauf',
      submitLabel: 'Zur Prüfung geben',
      approveLabel: 'Freigeben',
      rejectLabel: 'Ablehnen',
      publishLabel: 'Veröffentlichen',
    ));

List<SeoEditorialWorkflowStageEntry> _stages() => [
      (
        label: 'Entwurf',
        nodes: [SeoNode(tag: 'p', text: 'Entwurf bearbeiten')],
      ),
      (
        label: 'Prüfung',
        nodes: [
          SeoNode(tag: 'p', text: 'Redaktion prüft Inhalt und Quellen'),
        ],
      ),
      (
        label: 'Freigegeben',
        nodes: [SeoNode(tag: 'p', text: 'Freigabe ist dokumentiert')],
      ),
      (
        label: 'Veröffentlicht',
        nodes: [SeoNode(tag: 'p', text: 'Beitrag ist öffentlich')],
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
