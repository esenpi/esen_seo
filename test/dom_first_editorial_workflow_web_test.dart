@TestOn('browser')
library;

import 'dart:js_interop';

import 'package:esen_seo/core.dart';
import 'package:esen_seo/src/renderer/dom_first_editorial_workflow_adapter_web.dart';
import 'package:esen_seo/workflow.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;

void main() {
  late web.HTMLElement fixture;

  setUp(() {
    web.document.body?.setHTMLUnsafe('<div id="fixture"></div>'.toJS);
    fixture = web.document.getElementById('fixture')! as web.HTMLElement;
  });

  test('enhances exact builder markup without repairing initial content', () {
    final root = _workflow(fixture);
    final before = _contentSnapshot(root);

    _enhance();

    expect(root.getAttribute('data-esen-enhanced'), 'true');
    final after = _contentSnapshot(root);
    expect(after.status, before.status);
    expect(after.summary, before.summary);
    expect(after.regions, before.regions);
    expect(after.progress, before.progress);
    expect(after.history, before.history);
    expect(root.querySelectorAll('button'), hasLength(4));
    expect(_enabled(root, 'submit'), isTrue);
    expect(_enabled(root, 'approve'), isFalse);
    expect(_enabled(root, 'reject'), isFalse);
    expect(_enabled(root, 'publish'), isFalse);
  });

  test('frozen branching sequence updates one atomic package-owned view', () {
    final root = _workflow(fixture);
    _enhance();
    final sequence = <({String action, int stage, int history})>[
      (action: 'submit', stage: 1, history: 2),
      (action: 'reject', stage: 0, history: 3),
      (action: 'submit', stage: 1, history: 4),
      (action: 'approve', stage: 2, history: 5),
      (action: 'reject', stage: 0, history: 6),
      (action: 'submit', stage: 1, history: 7),
      (action: 'approve', stage: 2, history: 8),
      (action: 'publish', stage: 3, history: 9),
    ];

    for (final step in sequence) {
      _control(root, step.action).click();
      _assertState(root, step.stage, step.history);
    }

    expect(_history(root), [0, 1, 0, 1, 2, 0, 1, 2, 3]);
    expect(_announcement(root), 'Status Veröffentlicht');
    for (final action in const ['submit', 'approve', 'reject', 'publish']) {
      expect(_enabled(root, action), isFalse);
    }
    final terminal = root.outerHTML;
    for (final action in const ['submit', 'approve', 'reject', 'publish']) {
      _control(root, action).click();
    }
    expect(root.outerHTML, terminal);
  });

  test('invalid application transition never partially mutates', () {
    final root = _workflow(fixture);
    enhanceSeoDomFirstEditorialWorkflows(
      interactionIds: const {'article-workflow'},
      transition: (_, __) => const SeoEditorialWorkflowState(
        stage: SeoEditorialWorkflowStage.published,
        history: [
          SeoEditorialWorkflowStage.draft,
          SeoEditorialWorkflowStage.review,
          SeoEditorialWorkflowStage.approved,
          SeoEditorialWorkflowStage.published,
        ],
      ),
      project: _view,
    );
    final before = root.outerHTML;
    _control(root, 'submit').click();
    expect(root.outerHTML, before);
  });

  test('application text stays text and cannot create markup', () {
    final root = _workflow(fixture);
    const payload = '<img src=x onerror=alert(1)>';
    enhanceSeoDomFirstEditorialWorkflows(
      interactionIds: const {'article-workflow'},
      transition: transitionSeoEditorialWorkflow,
      project: (state) {
        final base = _view(state);
        return SeoEditorialWorkflowView(
          statusText: state.stage == SeoEditorialWorkflowStage.review
              ? payload
              : base.statusText,
          summaryText: base.summaryText,
          announcementText: base.announcementText,
          activeStageRegion: base.activeStageRegion,
        );
      },
    );
    _control(root, 'submit').click();
    expect(_status(root), payload);
    expect(root.querySelectorAll('img'), isEmpty);
    expect(root.querySelectorAll('[onerror]'), isEmpty);
  });

  test('tampering after mount deactivates before any state mutation', () {
    final root = _workflow(fixture);
    _enhance();
    root.querySelector('[data-esen-workflow-summary]')?.textContent = 'changed';
    final before = root.outerHTML;
    _control(root, 'submit').click();
    expect(root.outerHTML, before);
    _control(root, 'submit').click();
    expect(root.outerHTML, before);
  });

  test('malformed builder structure remains complete static HTML', () {
    final duplicate = _workflow(fixture, id: 'duplicate-workflow');
    duplicate
        .querySelector('[data-esen-workflow-history]')
        ?.appendChild(web.document.createElement('li'));
    final nested = _workflow(fixture, id: 'nested-workflow');
    nested
        .querySelector('[data-esen-workflow-status-text]')
        ?.appendChild(web.document.createElement('em'));
    final extra = _workflow(fixture, id: 'extra-workflow');
    extra.appendChild(web.document.createElement('p'));
    final duplicateId = _workflow(fixture, id: 'duplicate-id-workflow');
    final other = web.document.createElement('div') as web.HTMLElement
      ..id = 'duplicate-id-workflow';
    fixture.appendChild(other);

    enhanceSeoDomFirstEditorialWorkflows(
      interactionIds: const {
        'duplicate-workflow',
        'nested-workflow',
        'extra-workflow',
        'duplicate-id-workflow',
      },
      transition: transitionSeoEditorialWorkflow,
      project: _view,
    );

    for (final root in [duplicate, nested, extra, duplicateId]) {
      expect(root.hasAttribute('data-esen-enhanced'), isFalse);
      expect(root.querySelectorAll('button'), isEmpty);
      expect(root.textContent, contains('Entwurf bearbeiten'));
      expect(root.textContent, contains('Beitrag öffentlich'));
    }
  });

  test('focus moves only to a package-owned admitted control or region', () {
    final root = _workflow(fixture);
    _enhance();
    _control(root, 'submit').focus();
    _control(root, 'submit').click();
    expect(web.document.activeElement, _control(root, 'approve'));
    _control(root, 'approve').click();
    expect(web.document.activeElement, _control(root, 'reject'));
    _control(root, 'publish').click();
    expect(web.document.activeElement, root);
  });

  test('invalid admission refuses discovery before mutation', () {
    final root = _workflow(fixture);
    enhanceSeoDomFirstEditorialWorkflows(
      interactionIds: const {'article-workflow', 'Invalid ID'},
      transition: transitionSeoEditorialWorkflow,
      project: _view,
    );
    expect(root.hasAttribute('data-esen-enhanced'), isFalse);
    expect(root.querySelectorAll('button'), isEmpty);
  });
}

void _enhance() => enhanceSeoDomFirstEditorialWorkflows(
      interactionIds: const {'article-workflow'},
      transition: transitionSeoEditorialWorkflow,
      project: _view,
    );

web.HTMLElement _workflow(
  web.Element parent, {
  String id = 'article-workflow',
}) {
  final container = parent.querySelector('#esen-seo-content') ??
      (web.document.createElement('div') as web.HTMLElement
        ..id = 'esen-seo-content'
        ..setAttribute('data-esen-seo-dom-first', 'true'));
  if (container.parentElement == null) parent.appendChild(container);
  final holder = web.document.createElement('div') as web.HTMLElement;
  holder.setHTMLUnsafe(
    const HtmlRenderer()
        .render(buildSeoEditorialWorkflowNodes(
          stages: _stages(),
          initialState: initialSeoEditorialWorkflowState,
          project: _view,
          interactionId: id,
          heading: 'Freigabeprozess',
          interactionLabel: 'Freigabeprozess für einen Artikel',
          statusLabel: 'Status',
          progressLabel: 'Fortschritt',
          historyLabel: 'Verlauf',
          submitLabel: 'Zur Prüfung',
          approveLabel: 'Freigeben',
          rejectLabel: 'Ablehnen',
          publishLabel: 'Veröffentlichen',
        ))
        .toJS,
  );
  final root = holder.firstElementChild! as web.HTMLElement;
  container.appendChild(root);
  return root;
}

List<SeoEditorialWorkflowStageEntry> _stages() => [
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

({
  String status,
  String summary,
  List<String> regions,
  String progress,
  String history
}) _contentSnapshot(web.Element root) => (
      status: _status(root),
      summary:
          root.querySelector('[data-esen-workflow-summary]')?.textContent ?? '',
      regions: [
        for (var index = 0; index < 4; index++)
          _outerHtml(root.querySelector(
            '[data-esen-workflow-stage-region="$index"]',
          )),
      ],
      progress: _outerHtml(root.querySelector('[data-esen-workflow-progress]')),
      history: _outerHtml(root.querySelector('[data-esen-workflow-history]')),
    );

String _outerHtml(web.Element? element) => element == null
    ? ''
    : (element as web.HTMLElement).outerHTML.dartify()! as String;

void _assertState(web.Element root, int stage, int historyLength) {
  final regions = root.querySelectorAll('[data-esen-workflow-stage-region]');
  final active = <int>[];
  for (var index = 0; index < regions.length; index++) {
    if (!(regions.item(index) as web.Element).hasAttribute('hidden')) {
      active.add(index);
    }
  }
  expect(active, [stage]);
  expect(
    root
        .querySelector(
            '[data-esen-workflow-progress-stage][aria-current="step"]')
        ?.getAttribute('data-esen-workflow-progress-stage'),
    '$stage',
  );
  expect(_history(root), hasLength(historyLength));
  expect(_status(root),
      const ['Entwurf', 'Prüfung', 'Freigegeben', 'Veröffentlicht'][stage]);
  expect(_announcement(root), 'Status ${_status(root)}');
}

web.HTMLElement _control(web.Element root, String action) =>
    root.querySelector('[data-esen-workflow-$action]')! as web.HTMLElement;

bool _enabled(web.Element root, String action) =>
    !_control(root, action).hasAttribute('disabled');

String _status(web.Element root) =>
    root.querySelector('[data-esen-workflow-status-text]')?.textContent ?? '';

String _announcement(web.Element root) =>
    root.querySelector('[data-esen-workflow-announcement]')?.textContent ?? '';

List<int> _history(web.Element root) {
  final items = root.querySelectorAll('[data-esen-workflow-history-stage]');
  return [
    for (var index = 0; index < items.length; index++)
      int.parse((items.item(index) as web.Element)
          .getAttribute('data-esen-workflow-history-stage')!),
  ];
}
