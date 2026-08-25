@TestOn('browser')
library;

import 'dart:js_interop';

import 'package:esen_seo/checklist.dart';
import 'package:esen_seo/core.dart';
import 'package:esen_seo/src/renderer/dom_first_approval_checklist_adapter_web.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;

void main() {
  late web.HTMLElement fixture;

  setUp(() {
    web.document.body?.setHTMLUnsafe('<div id="fixture"></div>'.toJS);
    fixture = web.document.getElementById('fixture')! as web.HTMLElement;
  });

  test('enhances exact builder markup without repairing initial content', () {
    final root = _checklist(fixture);
    final before = _snapshot(root);

    _enhance();

    expect(root.getAttribute('data-esen-enhanced'), 'true');
    expect(_snapshot(root), before);
    expect(root.querySelectorAll('button'), hasLength(3));
    expect(_checked(root, 0), isFalse);
    expect(_checked(root, 1), isTrue);
    expect(_checked(root, 2), isFalse);
  });

  test('closed item sequence updates one atomic package-owned view', () {
    final root = _checklist(fixture);
    _enhance();

    _control(root, 0).click();
    _assertState(root, [true, true, false]);
    _control(root, 2).click();
    _assertState(root, [true, true, true]);
    _control(root, 1).click();
    _assertState(root, [true, false, true]);

    expect(_status(root), 'Offen');
    expect(_summary(root), '2 / 3 erledigt');
    expect(_announcement(root), '2 Prüfpunkte erledigt');
  });

  test('rewritten neighbouring state never partially mutates', () {
    final root = _checklist(fixture);
    enhanceSeoDomFirstApprovalChecklists(
      interactionIds: const {'article-checklist'},
      transition: (_, __) => const SeoApprovalChecklistState(
        checked: [true, false, true],
      ),
      project: _view,
    );
    final before = root.outerHTML;
    _control(root, 0).click();
    expect(root.outerHTML, before);
  });

  test('application text stays text and cannot create markup', () {
    final root = _checklist(fixture);
    const payload = '<img src=x onerror=alert(1)>';
    enhanceSeoDomFirstApprovalChecklists(
      interactionIds: const {'article-checklist'},
      transition: transitionSeoApprovalChecklist,
      project: (state) {
        final base = _view(state);
        return SeoApprovalChecklistView(
          statusText: state.checked[0] ? payload : base.statusText,
          summaryText: base.summaryText,
          announcementText: base.announcementText,
        );
      },
    );
    _control(root, 0).click();
    expect(_status(root), payload);
    expect(root.querySelectorAll('img'), isEmpty);
    expect(root.querySelectorAll('[onerror]'), isEmpty);
  });

  test('tampering after mount deactivates before state mutation', () {
    final root = _checklist(fixture);
    _enhance();
    root.querySelector('[data-esen-checklist-summary]')?.textContent =
        'changed';
    final before = root.outerHTML;
    _control(root, 0).click();
    expect(root.outerHTML, before);
    _control(root, 0).click();
    expect(root.outerHTML, before);
  });

  test('post-mount control and ARIA tampering always fails closed', () {
    final progress = _checklist(fixture, id: 'progress-checklist');
    final group = _checklist(fixture, id: 'group-checklist');
    final region = _checklist(fixture, id: 'region-checklist');
    final label = _checklist(fixture, id: 'label-checklist');
    final duplicate = _checklist(fixture, id: 'control-id-checklist');
    enhanceSeoDomFirstApprovalChecklists(
      interactionIds: const {
        'progress-checklist',
        'group-checklist',
        'region-checklist',
        'label-checklist',
        'control-id-checklist',
      },
      transition: transitionSeoApprovalChecklist,
      project: _view,
    );

    progress
        .querySelector('[data-esen-checklist-progress]')
        ?.setAttribute('aria-valuemax', '99');
    group
        .querySelector('.esen-seo-approval-checklist-controls')
        ?.setAttribute('role', 'list');
    region.setAttribute('aria-label', 'changed');
    label.querySelector('[data-esen-checklist-item-label]')?.id = 'changed';
    final duplicateControl = web.document.createElement('span');
    duplicateControl.id = 'control-id-checklist-item-0-control';
    fixture.appendChild(duplicateControl);

    for (final root in [progress, group, region, label, duplicate]) {
      final before = root.outerHTML;
      _control(root, 0).click();
      expect(root.outerHTML, before);
      _control(root, 0).click();
      expect(root.outerHTML, before);
    }
  });

  test('application exceptions deactivate without partial mutation', () {
    final root = _checklist(fixture);
    enhanceSeoDomFirstApprovalChecklists(
      interactionIds: const {'article-checklist'},
      transition: (_, __) => throw StateError('application failed'),
      project: _view,
    );
    final before = root.outerHTML;

    _control(root, 0).click();
    expect(root.outerHTML, before);
    _control(root, 0).click();
    expect(root.outerHTML, before);
  });

  test('malformed builder structure remains complete static HTML', () {
    final duplicate = _checklist(fixture, id: 'duplicate-checklist');
    duplicate
        .querySelector('.esen-seo-approval-checklist-items')
        ?.appendChild(web.document.createElement('li'));
    final nested = _checklist(fixture, id: 'nested-checklist');
    nested
        .querySelector('[data-esen-checklist-status-text]')
        ?.appendChild(web.document.createElement('em'));
    final extra = _checklist(fixture, id: 'extra-checklist');
    extra.appendChild(web.document.createElement('p'));
    final duplicateId = _checklist(fixture, id: 'duplicate-id-checklist');
    fixture.appendChild(
        web.document.createElement('div')..id = 'duplicate-id-checklist');

    enhanceSeoDomFirstApprovalChecklists(
      interactionIds: const {
        'duplicate-checklist',
        'nested-checklist',
        'extra-checklist',
        'duplicate-id-checklist',
      },
      transition: transitionSeoApprovalChecklist,
      project: _view,
    );

    for (final root in [duplicate, nested, extra, duplicateId]) {
      expect(root.hasAttribute('data-esen-enhanced'), isFalse);
      expect(root.querySelectorAll('button'), isEmpty);
      expect(root.textContent, contains('Titel und Teaser prüfen'));
      expect(root.textContent, contains('Metadaten vervollständigen'));
    }
  });

  test('controls own checkbox semantics and fixed label references', () {
    final root = _checklist(fixture);
    _enhance();

    for (var index = 0; index < 3; index++) {
      final control = _control(root, index);
      expect(control.tagName, 'BUTTON');
      expect(control.getAttribute('role'), 'checkbox');
      expect(
        control.getAttribute('aria-labelledby'),
        'article-checklist-item-$index-label',
      );
      expect(control.getAttribute('data-esen-checklist-control'), '$index');
    }
  });

  test('invalid admission refuses discovery before mutation', () {
    final root = _checklist(fixture);
    enhanceSeoDomFirstApprovalChecklists(
      interactionIds: const {'article-checklist', 'Invalid ID'},
      transition: transitionSeoApprovalChecklist,
      project: _view,
    );
    expect(root.hasAttribute('data-esen-enhanced'), isFalse);
    expect(root.querySelectorAll('button'), isEmpty);
  });
}

void _enhance() => enhanceSeoDomFirstApprovalChecklists(
      interactionIds: const {'article-checklist'},
      transition: transitionSeoApprovalChecklist,
      project: _view,
    );

web.HTMLElement _checklist(
  web.Element parent, {
  String id = 'article-checklist',
}) {
  final container = parent.querySelector('#esen-seo-content') ??
      (web.document.createElement('div') as web.HTMLElement
        ..id = 'esen-seo-content'
        ..setAttribute('data-esen-seo-dom-first', 'true'));
  if (container.parentElement == null) parent.appendChild(container);
  final holder = web.document.createElement('div') as web.HTMLElement;
  holder.setHTMLUnsafe(
    const HtmlRenderer()
        .render(buildSeoApprovalChecklistNodes(
          items: _items(),
          initialState: const SeoApprovalChecklistState(
            checked: [false, true, false],
          ),
          project: _view,
          interactionId: id,
          heading: 'Freigabe-Checkliste',
          interactionLabel: 'Prüfpunkte für den Artikel',
          statusLabel: 'Status',
          progressLabel: 'Fortschritt',
        ))
        .toJS,
  );
  final root = holder.firstElementChild! as web.HTMLElement;
  container.appendChild(root);
  return root;
}

List<SeoApprovalChecklistItemEntry> _items() => [
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

({String status, String summary, String progress, String items}) _snapshot(
  web.Element root,
) =>
    (
      status: _status(root),
      summary: _summary(root),
      progress: _outerHtml(
        root.querySelector('[data-esen-checklist-progress]'),
      ),
      items: _outerHtml(
        root.querySelector('.esen-seo-approval-checklist-items'),
      ),
    );

String _outerHtml(web.Element? element) => element == null
    ? ''
    : (element as web.HTMLElement).outerHTML.dartify()! as String;

void _assertState(web.Element root, List<bool> checked) {
  final count = checked.where((value) => value).length;
  for (var index = 0; index < checked.length; index++) {
    expect(_checked(root, index), checked[index]);
  }
  expect(
    root
        .querySelector('[data-esen-checklist-progress]')
        ?.getAttribute('aria-valuenow'),
    '$count',
  );
  expect(
    root.querySelector('[data-esen-checklist-progress-text]')?.textContent,
    '$count / ${checked.length}',
  );
  expect(_summary(root), '$count / ${checked.length} erledigt');
  expect(_announcement(root), '$count Prüfpunkte erledigt');
}

web.HTMLElement _control(web.Element root, int index) => root.querySelector(
      '[data-esen-checklist-control="$index"]',
    )! as web.HTMLElement;

bool _checked(web.Element root, int index) =>
    _control(root, index).getAttribute('aria-checked') == 'true';

String _status(web.Element root) =>
    root.querySelector('[data-esen-checklist-status-text]')?.textContent ?? '';

String _summary(web.Element root) =>
    root.querySelector('[data-esen-checklist-summary]')?.textContent ?? '';

String _announcement(web.Element root) =>
    root.querySelector('[data-esen-checklist-announcement]')?.textContent ?? '';
