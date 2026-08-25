import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../components/seo_component_format.dart';
import '../components/seo_configurator_transition.dart'
    show canonicalizeSeoConfiguratorText;
import '../components/seo_editorial_workflow_component.dart';
import '../components/seo_editorial_workflow_transition.dart';
import 'seo_container.dart';

void enhanceSeoDomFirstEditorialWorkflows({
  required Set<String> interactionIds,
  required SeoEditorialWorkflowTransition transition,
  required SeoEditorialWorkflowViewProjection project,
}) {
  if (interactionIds.isEmpty ||
      interactionIds.any((id) => !isValidSeoInteractionId(id))) {
    return;
  }
  for (final apply in _WorkflowApplyBoundary.discover(
    web.document,
    interactionIds,
    project,
  )) {
    _enhanceWorkflow(apply, transition, project);
  }
}

void _enhanceWorkflow(
  _WorkflowApplyBoundary apply,
  SeoEditorialWorkflowTransition transition,
  SeoEditorialWorkflowViewProjection project,
) {
  var current = apply.initial;
  var active = true;

  void dispatch(
    SeoEditorialWorkflowAction action,
    web.HTMLElement source,
  ) {
    if (!active) return;
    final result = evaluateSeoEditorialWorkflowAction(
      transition: transition,
      project: project,
      current: current,
      action: action,
    );
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

typedef _WorkflowEventSink = void Function(
  SeoEditorialWorkflowAction action,
  web.HTMLElement source,
);

final class _WorkflowStageEntry {
  const _WorkflowStageEntry({
    required this.label,
    required this.region,
    required this.progress,
  });

  final String label;
  final web.HTMLElement region;
  final web.HTMLElement progress;
}

final class _WorkflowPlan {
  const _WorkflowPlan({
    required this.root,
    required this.id,
    required this.interactionLabel,
    required this.statusLabel,
    required this.submitLabel,
    required this.approveLabel,
    required this.rejectLabel,
    required this.publishLabel,
    required this.initial,
    required this.stages,
    required this.statusSlot,
    required this.summarySlot,
    required this.history,
    required this.announcement,
    required this.placeholder,
  });

  final web.HTMLElement root;
  final String id;
  final String interactionLabel;
  final String statusLabel;
  final String submitLabel;
  final String approveLabel;
  final String rejectLabel;
  final String publishLabel;
  final SeoEditorialWorkflowEvaluation initial;
  final List<_WorkflowStageEntry> stages;
  final web.HTMLElement statusSlot;
  final web.HTMLElement summarySlot;
  final web.HTMLElement history;
  final web.HTMLElement announcement;
  final web.HTMLElement placeholder;
}

final class _WorkflowApplyBoundary {
  _WorkflowApplyBoundary(this.document, this.plan);

  final web.Document document;
  final _WorkflowPlan plan;
  final List<web.HTMLElement> _controls = [];
  var _announcementText = '';

  SeoEditorialWorkflowEvaluation get initial => plan.initial;

  static List<_WorkflowApplyBoundary> discover(
    web.Document document,
    Set<String> interactionIds,
    SeoEditorialWorkflowViewProjection project,
  ) {
    final container = document.getElementById(seoContainerId);
    if (container == null ||
        container.getAttribute(seoDomFirstAttribute) != 'true' ||
        _idCount(document, seoContainerId) != 1) {
      return const [];
    }
    final boundaries = <_WorkflowApplyBoundary>[];
    final roots = container
        .querySelectorAll('[data-esen-component="editorial-workflow"]');
    for (var index = 0; index < roots.length; index++) {
      final raw = roots.item(index);
      if (raw == null || !interactionIds.contains((raw as web.Element).id)) {
        continue;
      }
      final plan = _validate(document, container, raw, project);
      if (plan != null) boundaries.add(_WorkflowApplyBoundary(document, plan));
    }
    return boundaries;
  }

  static _WorkflowPlan? _validate(
    web.Document document,
    web.Element container,
    web.Element root,
    SeoEditorialWorkflowViewProjection project,
  ) {
    if (root.tagName != 'SECTION' ||
        !root.classList.contains('esen-seo-editorial-workflow') ||
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
      _fixedLabel(root, 'data-esen-history-label'),
      _fixedLabel(root, 'data-esen-submit-label'),
      _fixedLabel(root, 'data-esen-approve-label'),
      _fixedLabel(root, 'data-esen-reject-label'),
      _fixedLabel(root, 'data-esen-publish-label'),
    ];
    if (labels.any((label) => label == null)) return null;

    final initialStage =
        _strictStage(root.getAttribute('data-esen-initial-stage'));
    final initialHistory =
        _strictHistory(root.getAttribute('data-esen-initial-history'));
    if (initialStage == null || initialHistory == null) return null;
    final state = SeoEditorialWorkflowState(
      stage: initialStage,
      history: initialHistory,
    );
    final initial = evaluateInitialSeoEditorialWorkflowView(project, state);
    if (initial == null) return null;

    final placeholders = root.querySelectorAll(
      ':scope > [data-esen-prepaint-placeholder="editorial-workflow"]',
    );
    final statusSlots =
        root.querySelectorAll(':scope > p > [data-esen-workflow-status-text]');
    final summarySlots =
        root.querySelectorAll(':scope > p > [data-esen-workflow-summary]');
    final progressLists =
        root.querySelectorAll(':scope > [data-esen-workflow-progress]');
    final regions = root.querySelectorAll(
      ':scope > section[data-esen-workflow-stage-region]',
    );
    final histories =
        root.querySelectorAll(':scope > [data-esen-workflow-history]');
    final announcements =
        root.querySelectorAll(':scope > [data-esen-workflow-announcement]');
    if (placeholders.length != 1 ||
        statusSlots.length != 1 ||
        summarySlots.length != 1 ||
        progressLists.length != 1 ||
        regions.length != SeoEditorialWorkflowStage.values.length ||
        histories.length != 1 ||
        announcements.length != 1) {
      return null;
    }

    final children = root.children;
    final statusStrong = children.item(2)?.children.item(0);
    final historyHeading = children.item(9);
    if (children.length != 12 ||
        !_headingTag.hasMatch(children.item(0)?.tagName ?? '') ||
        children.item(1) != placeholders.item(0) ||
        !_validSlotParagraph(children.item(2), statusSlots.item(0),
            strong: true) ||
        !_validSlotParagraph(children.item(3), summarySlots.item(0)) ||
        children.item(4) != progressLists.item(0) ||
        !_headingTag.hasMatch(historyHeading?.tagName ?? '') ||
        historyHeading?.childElementCount != 0 ||
        historyHeading?.textContent != labels[3] ||
        children.item(10) != histories.item(0) ||
        children.item(11) != announcements.item(0) ||
        statusStrong?.childElementCount != 0 ||
        statusStrong?.textContent != '${labels[1]}: ') {
      return null;
    }
    for (var index = 0; index < regions.length; index++) {
      if (children.item(5 + index) != regions.item(index)) return null;
    }

    final placeholder = placeholders.item(0)! as web.HTMLElement;
    final statusSlot = statusSlots.item(0)! as web.HTMLElement;
    final summarySlot = summarySlots.item(0)! as web.HTMLElement;
    final progress = progressLists.item(0)! as web.HTMLElement;
    final history = histories.item(0)! as web.HTMLElement;
    final announcement = announcements.item(0)! as web.HTMLElement;
    if (statusSlot.tagName != 'SPAN' ||
        summarySlot.tagName != 'SPAN' ||
        statusSlot.childElementCount != 0 ||
        summarySlot.childElementCount != 0 ||
        statusSlot.textContent != initial.view.statusText ||
        summarySlot.textContent != initial.view.summaryText ||
        progress.tagName != 'OL' ||
        progress.getAttribute('aria-label') != labels[2] ||
        history.tagName != 'OL' ||
        announcement.tagName != 'SPAN' ||
        announcement.childElementCount != 0 ||
        announcement.textContent != '' ||
        announcement.getAttribute('aria-live') != 'polite' ||
        announcement.getAttribute('aria-atomic') != 'true' ||
        !announcement.classList
            .contains('esen-seo-editorial-workflow-announcement')) {
      return null;
    }

    final stageEntries = <_WorkflowStageEntry>[];
    final stageLabels = <String>{};
    if (progress.children.length != SeoEditorialWorkflowStage.values.length) {
      return null;
    }
    for (final stage in SeoEditorialWorkflowStage.values) {
      final region = regions.item(stage.index)! as web.HTMLElement;
      final progressItem = progress.children.item(stage.index);
      final heading = region.children.item(0);
      if (region.id != '$id-stage-${stage.index}' ||
          _idCount(document, region.id) != 1 ||
          region.getAttribute('data-esen-workflow-stage-region') !=
              '${stage.index}' ||
          region.getAttribute('data-esen-initial-active') !=
              (stage == state.stage ? 'true' : null) ||
          heading == null ||
          !_headingTag.hasMatch(heading.tagName) ||
          heading.getAttribute('data-esen-workflow-stage-name') != '' ||
          heading.childElementCount != 0 ||
          progressItem == null ||
          progressItem.tagName != 'LI' ||
          progressItem.childElementCount != 0 ||
          progressItem.getAttribute('data-esen-workflow-progress-stage') !=
              '${stage.index}' ||
          progressItem.getAttribute('aria-current') !=
              (stage == state.stage ? 'step' : null) ||
          progressItem.getAttribute('data-esen-initial-current') !=
              (stage == state.stage ? 'true' : null)) {
        return null;
      }
      final label = canonicalizeSeoConfiguratorText(
        heading.textContent ?? '',
        maxLength: seoEditorialWorkflowMaxLabelTextLength,
      );
      if (label == null ||
          label != heading.textContent ||
          label != progressItem.textContent ||
          !stageLabels.add(label)) {
        return null;
      }
      stageEntries.add(_WorkflowStageEntry(
        label: label,
        region: region,
        progress: progressItem as web.HTMLElement,
      ));
    }
    final aggregateLabels = labels.whereType<String>().fold<int>(
              0,
              (sum, label) => sum + label.length,
            ) +
        stageLabels.fold<int>(0, (sum, label) => sum + label.length);
    if (aggregateLabels > seoEditorialWorkflowMaxAggregateLabelTextLength ||
        !_validHistory(history, initial.state.history, stageEntries) ||
        !_validPlaceholder(
          placeholder,
          initial.state,
          [labels[4]!, labels[5]!, labels[6]!, labels[7]!],
        )) {
      return null;
    }

    for (final suffix in [
      'controls',
      'submit',
      'approve',
      'reject',
      'publish',
    ]) {
      if (_idCount(document, '$id-$suffix') != 0) return null;
    }

    return _WorkflowPlan(
      root: root as web.HTMLElement,
      id: id,
      interactionLabel: labels[0]!,
      statusLabel: labels[1]!,
      submitLabel: labels[4]!,
      approveLabel: labels[5]!,
      rejectLabel: labels[6]!,
      publishLabel: labels[7]!,
      initial: initial,
      stages: List.unmodifiable(stageEntries),
      statusSlot: statusSlot,
      summarySlot: summarySlot,
      history: history,
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

  static bool _validHistory(
    web.HTMLElement history,
    List<SeoEditorialWorkflowStage> stages,
    List<_WorkflowStageEntry> entries,
  ) {
    if (history.children.length != stages.length) return false;
    for (var index = 0; index < stages.length; index++) {
      final item = history.children.item(index);
      final stage = stages[index];
      if (item == null ||
          item.tagName != 'LI' ||
          item.childElementCount != 0 ||
          item.getAttribute('data-esen-workflow-history-stage') !=
              '${stage.index}' ||
          item.textContent != entries[stage.index].label) {
        return false;
      }
    }
    return true;
  }

  static bool _validPlaceholder(
    web.HTMLElement placeholder,
    SeoEditorialWorkflowState state,
    List<String> labels,
  ) {
    if (placeholder.tagName != 'DIV' ||
        !placeholder.classList
            .contains('esen-seo-editorial-workflow-controls') ||
        !placeholder.hasAttribute('hidden') ||
        placeholder.getAttribute('aria-hidden') != 'true' ||
        placeholder.children.length != 4) {
      return false;
    }
    const actions = <SeoEditorialWorkflowAction>[
      SeoEditorialWorkflowSubmit(),
      SeoEditorialWorkflowApprove(),
      SeoEditorialWorkflowReject(),
      SeoEditorialWorkflowPublish(),
    ];
    for (var index = 0; index < actions.length; index++) {
      final item = placeholder.children.item(index);
      if (item == null ||
          item.tagName != 'SPAN' ||
          item.childElementCount != 0 ||
          !item.classList
              .contains('esen-seo-editorial-workflow-control-placeholder') ||
          item.textContent != labels[index] ||
          item.getAttribute('data-esen-placeholder-disabled') !=
              (isSeoEditorialWorkflowActionEnabled(state, actions[index])
                  ? null
                  : 'true')) {
        return false;
      }
    }
    return true;
  }

  void mount(_WorkflowEventSink dispatch) {
    final controls = document.createElement('div') as web.HTMLElement;
    controls.id = '${plan.id}-controls';
    controls.className = 'esen-seo-editorial-workflow-controls';
    controls.setAttribute('role', 'group');
    controls.setAttribute('aria-label', plan.interactionLabel);
    for (final entry in <({
      String suffix,
      String label,
      SeoEditorialWorkflowAction action,
    })>[
      (
        suffix: 'submit',
        label: plan.submitLabel,
        action: const SeoEditorialWorkflowSubmit(),
      ),
      (
        suffix: 'approve',
        label: plan.approveLabel,
        action: const SeoEditorialWorkflowApprove(),
      ),
      (
        suffix: 'reject',
        label: plan.rejectLabel,
        action: const SeoEditorialWorkflowReject(),
      ),
      (
        suffix: 'publish',
        label: plan.publishLabel,
        action: const SeoEditorialWorkflowPublish(),
      ),
    ]) {
      final button = document.createElement('button') as web.HTMLElement;
      button.id = '${plan.id}-${entry.suffix}';
      button.setAttribute('type', 'button');
      button.setAttribute('data-esen-workflow-${entry.suffix}', '');
      button.textContent = entry.label;
      button.addEventListener(
        'click',
        ((web.Event _) => dispatch(entry.action, button)).toJS,
      );
      _controls.add(button);
      controls.appendChild(button);
    }
    plan.root.replaceChild(controls, plan.placeholder);
    plan.root.setAttribute('role', 'region');
    plan.root.setAttribute('aria-label', plan.interactionLabel);
    plan.root.setAttribute('tabindex', '-1');
    _controlState(plan.initial.state);
    plan.root.setAttribute('data-esen-enhanced', 'true');
  }

  bool state(
    SeoEditorialWorkflowEvaluation current,
    SeoEditorialWorkflowEvaluation next, {
    required web.HTMLElement source,
  }) {
    if (!_matchesCurrent(current)) return false;
    final historyItem = document.createElement('li') as web.HTMLElement;
    historyItem.setAttribute(
      'data-esen-workflow-history-stage',
      '${next.state.stage.index}',
    );
    historyItem.textContent = plan.stages[next.state.stage.index].label;

    plan.statusSlot.textContent = next.view.statusText;
    plan.summarySlot.textContent = next.view.summaryText;
    for (final stage in SeoEditorialWorkflowStage.values) {
      final active = stage.index == next.view.activeStageRegion;
      plan.stages[stage.index].region.toggleAttribute('hidden', !active);
      if (active) {
        plan.stages[stage.index].progress.setAttribute('aria-current', 'step');
      } else {
        plan.stages[stage.index].progress.removeAttribute('aria-current');
      }
    }
    plan.history.appendChild(historyItem);
    _controlState(next.state);
    plan.root.setAttribute('data-esen-workflow-changed', 'true');
    plan.announcement.textContent = next.view.announcementText;
    _announcementText = next.view.announcementText;

    final nextControl = _firstEnabledControl();
    if (source.hasAttribute('disabled')) {
      (nextControl ?? plan.root).focus();
    }
    return true;
  }

  bool _matchesCurrent(SeoEditorialWorkflowEvaluation current) {
    if (plan.root.getAttribute('data-esen-enhanced') != 'true' ||
        plan.statusSlot.textContent != current.view.statusText ||
        plan.summarySlot.textContent != current.view.summaryText ||
        plan.announcement.textContent != _announcementText ||
        !_validHistory(plan.history, current.state.history, plan.stages)) {
      return false;
    }
    final changed =
        plan.root.getAttribute('data-esen-workflow-changed') == 'true';
    for (final stage in SeoEditorialWorkflowStage.values) {
      final active = stage == current.state.stage;
      final region = plan.stages[stage.index].region;
      final regionMatches = changed
          ? region.hasAttribute('hidden') != active
          : !region.hasAttribute('hidden') &&
              region.getAttribute('data-esen-initial-active') ==
                  (active ? 'true' : null);
      if (!regionMatches ||
          plan.stages[stage.index].progress.getAttribute('aria-current') !=
              (active ? 'step' : null)) {
        return false;
      }
    }
    const actions = <SeoEditorialWorkflowAction>[
      SeoEditorialWorkflowSubmit(),
      SeoEditorialWorkflowApprove(),
      SeoEditorialWorkflowReject(),
      SeoEditorialWorkflowPublish(),
    ];
    for (var index = 0; index < actions.length; index++) {
      if (_controls[index].hasAttribute('disabled') ==
          isSeoEditorialWorkflowActionEnabled(current.state, actions[index])) {
        return false;
      }
    }
    return true;
  }

  void _controlState(SeoEditorialWorkflowState state) {
    const actions = <SeoEditorialWorkflowAction>[
      SeoEditorialWorkflowSubmit(),
      SeoEditorialWorkflowApprove(),
      SeoEditorialWorkflowReject(),
      SeoEditorialWorkflowPublish(),
    ];
    for (var index = 0; index < actions.length; index++) {
      _controls[index].toggleAttribute(
        'disabled',
        !isSeoEditorialWorkflowActionEnabled(state, actions[index]),
      );
    }
  }

  web.HTMLElement? _firstEnabledControl() {
    for (final control in _controls) {
      if (!control.hasAttribute('disabled')) return control;
    }
    return null;
  }

  static String? _fixedLabel(web.Element root, String name) {
    final raw = root.getAttribute(name);
    if (raw == null) return null;
    final value = canonicalizeSeoConfiguratorText(
      raw,
      maxLength: seoEditorialWorkflowMaxLabelTextLength,
    );
    return value == raw ? value : null;
  }

  static SeoEditorialWorkflowStage? _strictStage(String? raw) {
    if (raw == null || !_stageIndex.hasMatch(raw)) return null;
    return SeoEditorialWorkflowStage.values[int.parse(raw)];
  }

  static List<SeoEditorialWorkflowStage>? _strictHistory(String? raw) {
    if (raw == null || !_history.hasMatch(raw)) return null;
    final stages = [
      for (final value in raw.split(','))
        SeoEditorialWorkflowStage.values[int.parse(value)],
    ];
    return stages.length <= seoEditorialWorkflowMaxHistoryEntries
        ? List.unmodifiable(stages)
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

final RegExp _stageIndex = RegExp(r'^[0-3]$');
final RegExp _history = RegExp(r'^[0-3](,[0-3]){0,31}$');
final RegExp _headingTag = RegExp(r'^H[1-6]$');
