import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../components/seo_approval_checklist_component.dart';
import '../components/seo_approval_checklist_transition.dart';
import '../components/seo_component_format.dart';
import '../components/seo_configurator_transition.dart'
    show canonicalizeSeoConfiguratorText;
import 'seo_container.dart';

void enhanceSeoDomFirstApprovalChecklists({
  required Set<String> interactionIds,
  required SeoApprovalChecklistTransition transition,
  required SeoApprovalChecklistViewProjection project,
}) {
  if (interactionIds.isEmpty ||
      interactionIds.any((id) => !isValidSeoInteractionId(id))) {
    return;
  }
  for (final apply in _ChecklistApplyBoundary.discover(
    web.document,
    interactionIds,
    project,
  )) {
    _enhanceChecklist(apply, transition, project);
  }
}

void _enhanceChecklist(
  _ChecklistApplyBoundary apply,
  SeoApprovalChecklistTransition transition,
  SeoApprovalChecklistViewProjection project,
) {
  var current = apply.initial;
  var active = true;

  void dispatch(
    SeoApprovalChecklistAction action,
    web.HTMLElement source,
  ) {
    if (!active) return;
    SeoApprovalChecklistEvaluation? result;
    try {
      result = evaluateSeoApprovalChecklistAction(
        transition: transition,
        project: project,
        current: current,
        action: action,
        itemCount: apply.itemCount,
      );
    } catch (_) {
      active = false;
      return;
    }
    if (result == null) {
      active = false;
      return;
    }
    if (!result.accepted) return;
    if (!apply.state(current, result, source: source)) {
      active = false;
      return;
    }
    current = result;
  }

  apply.mount(dispatch);
}

typedef _ChecklistEventSink = void Function(
  SeoApprovalChecklistAction action,
  web.HTMLElement source,
);

final class _ChecklistItemEntry {
  const _ChecklistItemEntry({
    required this.label,
    required this.labelId,
  });

  final String label;
  final String labelId;
}

final class _ChecklistPlan {
  const _ChecklistPlan({
    required this.root,
    required this.id,
    required this.interactionLabel,
    required this.statusLabel,
    required this.progressLabel,
    required this.initial,
    required this.items,
    required this.statusSlot,
    required this.summarySlot,
    required this.progress,
    required this.progressText,
    required this.itemList,
    required this.announcement,
    required this.placeholder,
  });

  final web.HTMLElement root;
  final String id;
  final String interactionLabel;
  final String statusLabel;
  final String progressLabel;
  final SeoApprovalChecklistEvaluation initial;
  final List<_ChecklistItemEntry> items;
  final web.HTMLElement statusSlot;
  final web.HTMLElement summarySlot;
  final web.HTMLElement progress;
  final web.HTMLElement progressText;
  final web.HTMLElement itemList;
  final web.HTMLElement announcement;
  final web.HTMLElement placeholder;
}

final class _ChecklistApplyBoundary {
  _ChecklistApplyBoundary(this.document, this.plan);

  final web.Document document;
  final _ChecklistPlan plan;
  final List<web.HTMLElement> _controls = [];
  web.HTMLElement? _controlsRoot;
  var _announcementText = '';

  SeoApprovalChecklistEvaluation get initial => plan.initial;
  int get itemCount => plan.items.length;

  static List<_ChecklistApplyBoundary> discover(
    web.Document document,
    Set<String> interactionIds,
    SeoApprovalChecklistViewProjection project,
  ) {
    final container = document.getElementById(seoContainerId);
    if (container == null ||
        container.getAttribute(seoDomFirstAttribute) != 'true' ||
        _idCount(document, seoContainerId) != 1) {
      return const [];
    }
    final boundaries = <_ChecklistApplyBoundary>[];
    final roots = container
        .querySelectorAll('[data-esen-component="approval-checklist"]');
    for (var index = 0; index < roots.length; index++) {
      final raw = roots.item(index);
      if (raw == null || !interactionIds.contains((raw as web.Element).id)) {
        continue;
      }
      final plan = _validate(document, container, raw, project);
      if (plan != null) boundaries.add(_ChecklistApplyBoundary(document, plan));
    }
    return boundaries;
  }

  static _ChecklistPlan? _validate(
    web.Document document,
    web.Element container,
    web.Element root,
    SeoApprovalChecklistViewProjection project,
  ) {
    if (root.tagName != 'SECTION' ||
        !root.classList.contains('esen-seo-approval-checklist') ||
        root.getAttribute('data-esen-layout-stable') != 'true' ||
        root.getAttribute('data-esen-enhanced') == 'true' ||
        _hiddenByAncestor(root, container)) {
      return null;
    }
    final id = root.id;
    if (!isValidSeoInteractionId(id) || _idCount(document, id) != 1) {
      return null;
    }
    final labels = <String?>[
      _fixedLabel(root, 'data-esen-label'),
      _fixedLabel(root, 'data-esen-status-label'),
      _fixedLabel(root, 'data-esen-progress-label'),
    ];
    if (labels.any((label) => label == null)) return null;
    final checked = _strictChecked(
      root.getAttribute('data-esen-initial-checked'),
    );
    if (checked == null) return null;
    final state = SeoApprovalChecklistState(checked: checked);
    final initial = evaluateInitialSeoApprovalChecklistView(
      project,
      state,
      itemCount: checked.length,
    );
    if (initial == null) return null;

    final placeholders = root.querySelectorAll(
      ':scope > [data-esen-prepaint-placeholder="approval-checklist"]',
    );
    final statusSlots =
        root.querySelectorAll(':scope > p > [data-esen-checklist-status-text]');
    final summarySlots =
        root.querySelectorAll(':scope > p > [data-esen-checklist-summary]');
    final progresses =
        root.querySelectorAll(':scope > [data-esen-checklist-progress]');
    final itemLists = root.querySelectorAll(':scope > ul');
    final announcements =
        root.querySelectorAll(':scope > [data-esen-checklist-announcement]');
    if (placeholders.length != 1 ||
        statusSlots.length != 1 ||
        summarySlots.length != 1 ||
        progresses.length != 1 ||
        itemLists.length != 1 ||
        announcements.length != 1) {
      return null;
    }

    final children = root.children;
    final statusStrong = children.item(2)?.children.item(0);
    if (children.length != 7 ||
        !_headingTag.hasMatch(children.item(0)?.tagName ?? '') ||
        children.item(1) != placeholders.item(0) ||
        !_validSlotParagraph(children.item(2), statusSlots.item(0),
            strong: true) ||
        !_validSlotParagraph(children.item(3), summarySlots.item(0)) ||
        children.item(4) != progresses.item(0) ||
        children.item(5) != itemLists.item(0) ||
        children.item(6) != announcements.item(0) ||
        statusStrong?.childElementCount != 0 ||
        statusStrong?.textContent != '${labels[1]}: ') {
      return null;
    }

    final placeholder = placeholders.item(0)! as web.HTMLElement;
    final statusSlot = statusSlots.item(0)! as web.HTMLElement;
    final summarySlot = summarySlots.item(0)! as web.HTMLElement;
    final progress = progresses.item(0)! as web.HTMLElement;
    final itemList = itemLists.item(0)! as web.HTMLElement;
    final announcement = announcements.item(0)! as web.HTMLElement;
    final progressTexts = progress.querySelectorAll(
      ':scope > [data-esen-checklist-progress-text]',
    );
    final checkedCount = seoApprovalChecklistCheckedCount(initial.state);
    if (statusSlot.tagName != 'SPAN' ||
        summarySlot.tagName != 'SPAN' ||
        statusSlot.childElementCount != 0 ||
        summarySlot.childElementCount != 0 ||
        statusSlot.textContent != initial.view.statusText ||
        summarySlot.textContent != initial.view.summaryText ||
        progress.tagName != 'DIV' ||
        progress.getAttribute('role') != 'progressbar' ||
        progress.getAttribute('aria-label') != labels[2] ||
        progress.getAttribute('aria-valuemin') != '0' ||
        progress.getAttribute('aria-valuemax') != '${checked.length}' ||
        progress.getAttribute('aria-valuenow') != '$checkedCount' ||
        progressTexts.length != 1 ||
        itemList.tagName != 'UL' ||
        !itemList.classList.contains('esen-seo-approval-checklist-items') ||
        itemList.children.length != checked.length ||
        announcement.tagName != 'SPAN' ||
        announcement.childElementCount != 0 ||
        announcement.textContent != '' ||
        announcement.getAttribute('aria-live') != 'polite' ||
        announcement.getAttribute('aria-atomic') != 'true' ||
        !announcement.classList
            .contains('esen-seo-approval-checklist-announcement')) {
      return null;
    }
    final progressText = progressTexts.item(0)! as web.HTMLElement;
    if (progressText.tagName != 'SPAN' ||
        progressText.childElementCount != 0 ||
        progressText.textContent != '$checkedCount / ${checked.length}') {
      return null;
    }

    final items = <_ChecklistItemEntry>[];
    final itemLabels = <String>{};
    for (var index = 0; index < checked.length; index++) {
      final item = itemList.children.item(index);
      final heading = item?.children.item(0);
      final labelId = '$id-item-$index-label';
      if (item == null ||
          item.tagName != 'LI' ||
          item.getAttribute('data-esen-checklist-item') != '$index' ||
          item.getAttribute('data-esen-initial-checked') !=
              (checked[index] ? 'true' : 'false') ||
          heading == null ||
          !_headingTag.hasMatch(heading.tagName) ||
          heading.id != labelId ||
          _idCount(document, labelId) != 1 ||
          heading.getAttribute('data-esen-checklist-item-label') != '' ||
          heading.childElementCount != 0) {
        return null;
      }
      final label = canonicalizeSeoConfiguratorText(
        heading.textContent ?? '',
        maxLength: seoApprovalChecklistMaxLabelTextLength,
      );
      if (label == null ||
          label != heading.textContent ||
          !itemLabels.add(label)) {
        return null;
      }
      items.add(_ChecklistItemEntry(label: label, labelId: labelId));
    }
    final aggregateLabels = labels.whereType<String>().fold<int>(
              0,
              (sum, label) => sum + label.length,
            ) +
        itemLabels.fold<int>(0, (sum, label) => sum + label.length);
    if (aggregateLabels > seoApprovalChecklistMaxAggregateLabelTextLength ||
        !_validPlaceholder(placeholder, checked, items)) {
      return null;
    }
    for (var index = 0; index < checked.length; index++) {
      if (_idCount(document, '$id-item-$index-control') != 0) return null;
    }
    if (_idCount(document, '$id-controls') != 0) return null;

    return _ChecklistPlan(
      root: root as web.HTMLElement,
      id: id,
      interactionLabel: labels[0]!,
      statusLabel: labels[1]!,
      progressLabel: labels[2]!,
      initial: initial,
      items: List.unmodifiable(items),
      statusSlot: statusSlot,
      summarySlot: summarySlot,
      progress: progress,
      progressText: progressText,
      itemList: itemList,
      announcement: announcement,
      placeholder: placeholder,
    );
  }

  static bool _validSlotParagraph(
    web.Element? paragraph,
    web.Node? slot, {
    bool strong = false,
  }) {
    if (paragraph == null || paragraph.tagName != 'P') return false;
    if (strong) {
      return paragraph.children.length == 2 &&
          paragraph.children.item(0)?.tagName == 'STRONG' &&
          paragraph.children.item(1) == slot;
    }
    return paragraph.children.length == 1 && paragraph.children.item(0) == slot;
  }

  static bool _validPlaceholder(
    web.HTMLElement placeholder,
    List<bool> checked,
    List<_ChecklistItemEntry> items,
  ) {
    if (placeholder.tagName != 'DIV' ||
        !placeholder.classList
            .contains('esen-seo-approval-checklist-controls') ||
        !placeholder.hasAttribute('hidden') ||
        placeholder.getAttribute('aria-hidden') != 'true' ||
        placeholder.children.length != checked.length) {
      return false;
    }
    for (var index = 0; index < checked.length; index++) {
      final item = placeholder.children.item(index);
      if (item == null ||
          item.tagName != 'SPAN' ||
          item.childElementCount != 0 ||
          !item.classList
              .contains('esen-seo-approval-checklist-control-placeholder') ||
          item.textContent != items[index].label ||
          item.getAttribute('data-esen-placeholder-checked') !=
              (checked[index] ? 'true' : 'false')) {
        return false;
      }
    }
    return true;
  }

  void mount(_ChecklistEventSink dispatch) {
    final controls = document.createElement('div') as web.HTMLElement;
    controls.id = '${plan.id}-controls';
    controls.className = 'esen-seo-approval-checklist-controls';
    controls.setAttribute('role', 'group');
    controls.setAttribute('aria-label', plan.interactionLabel);
    for (var index = 0; index < plan.items.length; index++) {
      final item = plan.items[index];
      final button = document.createElement('button') as web.HTMLElement;
      button.id = '${plan.id}-item-$index-control';
      button.setAttribute('type', 'button');
      button.setAttribute('role', 'checkbox');
      button.setAttribute(
        'aria-checked',
        plan.initial.state.checked[index] ? 'true' : 'false',
      );
      button.setAttribute('aria-labelledby', item.labelId);
      button.setAttribute('data-esen-checklist-control', '$index');
      button.textContent = item.label;
      button.addEventListener(
        'click',
        ((web.Event _) {
          final checked = button.getAttribute('aria-checked') == 'true';
          dispatch(SeoApprovalChecklistSetItem(index, !checked), button);
        }).toJS,
      );
      _controls.add(button);
      controls.appendChild(button);
    }
    plan.root.replaceChild(controls, plan.placeholder);
    plan.root.setAttribute('role', 'region');
    plan.root.setAttribute('aria-label', plan.interactionLabel);
    plan.root.setAttribute('data-esen-enhanced', 'true');
    _controlsRoot = controls;
  }

  bool state(
    SeoApprovalChecklistEvaluation current,
    SeoApprovalChecklistEvaluation next, {
    required web.HTMLElement source,
  }) {
    if (!_matchesCurrent(current) || !_controls.contains(source)) return false;
    final checkedCount = seoApprovalChecklistCheckedCount(next.state);
    plan.statusSlot.textContent = next.view.statusText;
    plan.summarySlot.textContent = next.view.summaryText;
    plan.progress.setAttribute('aria-valuenow', '$checkedCount');
    plan.progressText.textContent = '$checkedCount / ${plan.items.length}';
    for (var index = 0; index < _controls.length; index++) {
      _controls[index].setAttribute(
        'aria-checked',
        next.state.checked[index] ? 'true' : 'false',
      );
    }
    plan.root.setAttribute('data-esen-checklist-changed', 'true');
    plan.announcement.textContent = next.view.announcementText;
    _announcementText = next.view.announcementText;
    return true;
  }

  bool _matchesCurrent(SeoApprovalChecklistEvaluation current) {
    final checkedCount = seoApprovalChecklistCheckedCount(current.state);
    final controlsRoot = _controlsRoot;
    final children = plan.root.children;
    final changed = plan.root.getAttribute('data-esen-checklist-changed');
    if (controlsRoot == null ||
        plan.root.tagName != 'SECTION' ||
        plan.root.getAttribute('class') != 'esen-seo-approval-checklist' ||
        plan.root.getAttribute('data-esen-component') != 'approval-checklist' ||
        plan.root.getAttribute('data-esen-layout-stable') != 'true' ||
        plan.root.getAttribute('data-esen-label') != plan.interactionLabel ||
        plan.root.getAttribute('data-esen-status-label') != plan.statusLabel ||
        plan.root.getAttribute('data-esen-progress-label') !=
            plan.progressLabel ||
        plan.root.getAttribute('data-esen-initial-checked') !=
            plan.initial.state.checked
                .map((checked) => checked ? '1' : '0')
                .join(',') ||
        plan.root.getAttribute('data-esen-enhanced') != 'true' ||
        plan.root.getAttribute('role') != 'region' ||
        plan.root.getAttribute('aria-label') != plan.interactionLabel ||
        changed != null && changed != 'true' ||
        children.length != 7 ||
        children.item(1) != controlsRoot ||
        children.item(4) != plan.progress ||
        children.item(5) != plan.itemList ||
        children.item(6) != plan.announcement ||
        plan.statusSlot.parentElement != children.item(2) ||
        plan.summarySlot.parentElement != children.item(3) ||
        controlsRoot.parentElement != plan.root ||
        controlsRoot.id != '${plan.id}-controls' ||
        _idCount(document, controlsRoot.id) != 1 ||
        controlsRoot.getAttribute('class') !=
            'esen-seo-approval-checklist-controls' ||
        controlsRoot.getAttribute('role') != 'group' ||
        controlsRoot.getAttribute('aria-label') != plan.interactionLabel ||
        controlsRoot.children.length != _controls.length ||
        plan.statusSlot.tagName != 'SPAN' ||
        plan.statusSlot.getAttribute('data-esen-checklist-status-text') != '' ||
        plan.statusSlot.childElementCount != 0 ||
        plan.statusSlot.textContent != current.view.statusText ||
        plan.summarySlot.tagName != 'SPAN' ||
        plan.summarySlot.getAttribute('data-esen-checklist-summary') != '' ||
        plan.summarySlot.childElementCount != 0 ||
        plan.summarySlot.textContent != current.view.summaryText ||
        plan.progress.tagName != 'DIV' ||
        plan.progress.getAttribute('class') !=
            'esen-seo-approval-checklist-progress' ||
        plan.progress.getAttribute('data-esen-checklist-progress') != '' ||
        plan.progress.getAttribute('role') != 'progressbar' ||
        plan.progress.getAttribute('aria-label') != plan.progressLabel ||
        plan.progress.getAttribute('aria-valuemin') != '0' ||
        plan.progress.getAttribute('aria-valuemax') != '${plan.items.length}' ||
        plan.progress.getAttribute('aria-valuenow') != '$checkedCount' ||
        plan.progress.children.length != 1 ||
        plan.progress.children.item(0) != plan.progressText ||
        plan.progressText.tagName != 'SPAN' ||
        plan.progressText.getAttribute('data-esen-checklist-progress-text') !=
            '' ||
        plan.progressText.childElementCount != 0 ||
        plan.progressText.textContent !=
            '$checkedCount / ${plan.items.length}' ||
        plan.itemList.tagName != 'UL' ||
        plan.itemList.getAttribute('class') !=
            'esen-seo-approval-checklist-items' ||
        plan.itemList.children.length != plan.items.length ||
        plan.announcement.tagName != 'SPAN' ||
        plan.announcement.getAttribute('class') !=
            'esen-seo-approval-checklist-announcement' ||
        plan.announcement.getAttribute('aria-live') != 'polite' ||
        plan.announcement.getAttribute('aria-atomic') != 'true' ||
        plan.announcement.getAttribute('data-esen-checklist-announcement') !=
            '' ||
        plan.announcement.childElementCount != 0 ||
        plan.announcement.textContent != _announcementText ||
        _controls.length != current.state.checked.length) {
      return false;
    }
    for (var index = 0; index < _controls.length; index++) {
      final control = _controls[index];
      final item = plan.itemList.children.item(index);
      final heading = item?.children.item(0);
      if (controlsRoot.children.item(index) != control ||
          control.parentElement != controlsRoot ||
          control.id != '${plan.id}-item-$index-control' ||
          _idCount(document, control.id) != 1 ||
          control.tagName != 'BUTTON' ||
          control.getAttribute('type') != 'button' ||
          control.childElementCount != 0 ||
          control.getAttribute('data-esen-checklist-control') != '$index' ||
          control.getAttribute('role') != 'checkbox' ||
          control.getAttribute('aria-checked') !=
              (current.state.checked[index] ? 'true' : 'false') ||
          control.getAttribute('aria-labelledby') !=
              plan.items[index].labelId ||
          control.textContent != plan.items[index].label ||
          item?.getAttribute('data-esen-checklist-item') != '$index' ||
          item?.getAttribute('data-esen-initial-checked') !=
              (plan.initial.state.checked[index] ? 'true' : 'false') ||
          heading?.id != plan.items[index].labelId ||
          _idCount(document, plan.items[index].labelId) != 1 ||
          heading?.getAttribute('data-esen-checklist-item-label') != '' ||
          heading?.childElementCount != 0 ||
          heading?.textContent != plan.items[index].label) {
        return false;
      }
    }
    return true;
  }

  static String? _fixedLabel(web.Element root, String name) {
    final raw = root.getAttribute(name);
    if (raw == null) return null;
    final value = canonicalizeSeoConfiguratorText(
      raw,
      maxLength: seoApprovalChecklistMaxLabelTextLength,
    );
    return value == raw ? value : null;
  }

  static List<bool>? _strictChecked(String? raw) {
    if (raw == null || !_checkedFlags.hasMatch(raw)) return null;
    final checked = raw.split(',').map((value) => value == '1').toList();
    return checked.length <= seoApprovalChecklistMaxItems
        ? List.unmodifiable(checked)
        : null;
  }

  static bool _hiddenByAncestor(web.Element root, web.Element container) {
    web.Element? current = root;
    while (current != null) {
      final ariaHidden = current.getAttribute('aria-hidden');
      if (current.hasAttribute('inert') ||
          (ariaHidden != null && ariaHidden.trim().toLowerCase() == 'true')) {
        return true;
      }
      if (current == container) return false;
      current = current.parentElement;
    }
    return true;
  }

  static int _idCount(web.Document document, String id) {
    if (id.isEmpty) return 0;
    final elements = document.querySelectorAll('[id]');
    var count = 0;
    for (var index = 0; index < elements.length; index++) {
      final element = elements.item(index);
      if (element != null && (element as web.Element).id == id) count++;
    }
    return count;
  }
}

final RegExp _checkedFlags = RegExp(r'^[01](,[01]){0,31}$');
final RegExp _headingTag = RegExp(r'^H[1-6]$');
