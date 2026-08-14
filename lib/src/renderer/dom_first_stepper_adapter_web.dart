import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../components/seo_component_format.dart';
import '../components/seo_stepper_transition.dart';
import 'seo_container.dart';

/// Enhances every valid stepper in the package-owned DOM-first container.
///
/// The complete control is validated before [_StepperApplyBoundary] performs
/// the first mutation. Invalid or ambiguous markup remains complete, readable
/// HTML instead of becoming a partially initialized control.
void enhanceSeoDomFirstSteppers({
  SeoStepperTransition transition = transitionSeoStepper,
}) {
  for (final apply in _StepperApplyBoundary.discover(web.document)) {
    _enhanceStepper(apply, transition);
  }
}

void _enhanceStepper(
  _StepperApplyBoundary apply,
  SeoStepperTransition transition,
) {
  var state = initialSeoStepperState(
    count: apply.count,
    index: apply.initialIndex,
  );

  void dispatch(SeoStepperAction action, {required bool moveFocus}) {
    state = applySeoStepperTransition(transition, state, action);
    apply.state(state, moveFocus: moveFocus);
  }

  apply.mount((index, event, moveFocus) {
    final action = switch (event) {
      _StepperControlEvent.select => SeoStepperSelect(index),
      _StepperControlEvent.next => const SeoStepperNext(),
      _StepperControlEvent.previous => const SeoStepperPrevious(),
      _StepperControlEvent.first => const SeoStepperFirst(),
      _StepperControlEvent.last => const SeoStepperLast(),
    };
    dispatch(action, moveFocus: moveFocus);
  });
  apply.state(state, moveFocus: false);
}

enum _StepperControlEvent { select, next, previous, first, last }

typedef _StepperEventSink = void Function(
  int index,
  _StepperControlEvent event,
  bool moveFocus,
);

final class _StepperEntry {
  const _StepperEntry({
    required this.step,
    required this.heading,
    required this.panel,
    required this.buttonId,
  });

  final web.HTMLElement step;
  final web.HTMLElement heading;
  final web.HTMLElement panel;
  final String buttonId;
}

final class _StepperPlan {
  const _StepperPlan({
    required this.root,
    required this.id,
    required this.label,
    required this.previousLabel,
    required this.nextLabel,
    required this.positionLabel,
    required this.initialIndex,
    required this.entries,
    required this.rtl,
  });

  final web.Element root;
  final String id;
  final String label;
  final String previousLabel;
  final String nextLabel;
  final String positionLabel;
  final int initialIndex;
  final List<_StepperEntry> entries;
  final bool rtl;
}

final class _StepperApplyBoundary {
  _StepperApplyBoundary(this.document, this.plan);

  final web.Document document;
  final _StepperPlan plan;
  final List<web.HTMLElement> _buttons = [];
  late final web.HTMLElement _previous;
  late final web.HTMLElement _next;
  late final web.HTMLElement _status;

  int get count => plan.entries.length;
  int get initialIndex => plan.initialIndex;

  static List<_StepperApplyBoundary> discover(web.Document document) {
    final container = document.getElementById(seoContainerId);
    if (container == null ||
        container.getAttribute(seoDomFirstAttribute) != 'true' ||
        _idCount(document, seoContainerId) != 1) {
      return const [];
    }

    final boundaries = <_StepperApplyBoundary>[];
    final roots = container.querySelectorAll('[data-esen-component="stepper"]');
    for (var index = 0; index < roots.length; index++) {
      final node = roots.item(index);
      if (node == null) continue;
      final plan = _validate(document, container, node as web.Element);
      if (plan != null) {
        boundaries.add(_StepperApplyBoundary(document, plan));
      }
    }
    return boundaries;
  }

  static _StepperPlan? _validate(
    web.Document document,
    web.Element container,
    web.Element root,
  ) {
    if (root.getAttribute('data-esen-enhanced') == 'true') return null;
    if (_hiddenByAncestor(root, container)) return null;
    final id = root.id;
    if (!isValidSeoInteractionId(id) || _idCount(document, id) != 1) {
      return null;
    }

    final rootChildren = root.children;
    if (rootChildren.length != 1) return null;
    final list = rootChildren.item(0);
    if (list == null ||
        list.tagName != 'OL' ||
        !list.hasAttribute('data-esen-step-list')) {
      return null;
    }

    final label = root.getAttribute('data-esen-label') ?? '';
    final previousLabel = root.getAttribute('data-esen-previous-label') ?? '';
    final nextLabel = root.getAttribute('data-esen-next-label') ?? '';
    final positionLabel = root.getAttribute('data-esen-position-label') ?? '';
    if (label.trim().isEmpty ||
        previousLabel.trim().isEmpty ||
        nextLabel.trim().isEmpty ||
        positionLabel.trim().isEmpty) {
      return null;
    }

    final initial = root.getAttribute('data-esen-initial-index');
    if (initial == null || !_decimalIndex.hasMatch(initial)) return null;
    final initialIndex = int.tryParse(initial);

    final entries = <_StepperEntry>[];
    final ids = <String>{};
    final steps = list.children;
    if (steps.length < 2) return null;
    for (var index = 0; index < steps.length; index++) {
      final step = steps.item(index);
      if (step == null ||
          step.tagName != 'LI' ||
          !step.hasAttribute('data-esen-step') ||
          step.children.length != 2) {
        return null;
      }
      final heading = step.children.item(0);
      final panel = step.children.item(1);
      final expectedStepId = '$id-step-$index';
      final expectedPanelId = '$id-panel-$index';
      final buttonId = '$id-step-button-$index';
      if (heading == null ||
          panel == null ||
          step.id != expectedStepId ||
          panel.id != expectedPanelId ||
          !ids.add(step.id) ||
          !ids.add(panel.id) ||
          _idCount(document, step.id) != 1 ||
          _idCount(document, panel.id) != 1 ||
          _idCount(document, buttonId) != 0 ||
          !_headingTag.hasMatch(heading.tagName) ||
          (heading.textContent ?? '').trim().isEmpty ||
          panel.tagName != 'DIV' ||
          !panel.hasAttribute('data-esen-step-panel')) {
        return null;
      }
      entries.add(_StepperEntry(
        step: step as web.HTMLElement,
        heading: heading as web.HTMLElement,
        panel: panel as web.HTMLElement,
        buttonId: buttonId,
      ));
    }
    if (initialIndex == null ||
        initialIndex < 0 ||
        initialIndex >= entries.length) {
      return null;
    }

    for (final suffix in const ['previous', 'next', 'status']) {
      if (_idCount(document, '$id-$suffix') != 0) return null;
    }

    return _StepperPlan(
      root: root,
      id: id,
      label: label,
      previousLabel: previousLabel,
      nextLabel: nextLabel,
      positionLabel: positionLabel,
      initialIndex: initialIndex,
      entries: entries,
      rtl: web.window.getComputedStyle(root).direction == 'rtl',
    );
  }

  static bool _hiddenByAncestor(
    web.Element root,
    web.Element container,
  ) {
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

  void mount(_StepperEventSink dispatch) {
    for (var index = 0; index < plan.entries.length; index++) {
      final entry = plan.entries[index];
      final button = document.createElement('button') as web.HTMLElement;
      button.setAttribute('type', 'button');
      button.id = entry.buttonId;
      button.className = 'esen-seo-step-button';
      button.setAttribute('data-esen-step-button', '');
      button.setAttribute('aria-controls', entry.panel.id);
      button.textContent = entry.heading.textContent ?? '';
      button.addEventListener(
        'click',
        ((web.Event _) => dispatch(index, _StepperControlEvent.select, false))
            .toJS,
      );
      button.addEventListener(
        'keydown',
        ((web.Event rawEvent) {
          final event = rawEvent as web.KeyboardEvent;
          if (event.repeat) return;
          final action = switch (event.key) {
            'ArrowDown' => _StepperControlEvent.next,
            'ArrowUp' => _StepperControlEvent.previous,
            'ArrowRight' => plan.rtl
                ? _StepperControlEvent.previous
                : _StepperControlEvent.next,
            'ArrowLeft' => plan.rtl
                ? _StepperControlEvent.next
                : _StepperControlEvent.previous,
            'Home' => _StepperControlEvent.first,
            'End' => _StepperControlEvent.last,
            _ => null,
          };
          if (action == null) return;
          event.preventDefault();
          dispatch(index, action, true);
        }).toJS,
      );
      entry.step.insertBefore(button, entry.heading);
      entry.panel.setAttribute('role', 'region');
      entry.panel.setAttribute('aria-labelledby', button.id);
      entry.heading.setAttribute('hidden', '');
      _buttons.add(button);
    }

    final controls = document.createElement('div') as web.HTMLElement;
    controls.className = 'esen-seo-stepper-controls';
    controls.setAttribute('data-esen-stepper-controls', '');

    _previous = _control(
      '${plan.id}-previous',
      plan.previousLabel,
      _StepperControlEvent.previous,
      dispatch,
    );
    _next = _control(
      '${plan.id}-next',
      plan.nextLabel,
      _StepperControlEvent.next,
      dispatch,
    );
    _status = document.createElement('span') as web.HTMLElement;
    _status.id = '${plan.id}-status';
    _status.className = 'esen-seo-stepper-status';
    _status.setAttribute('data-esen-stepper-status', '');
    _status.setAttribute('aria-live', 'polite');
    _status.setAttribute('aria-atomic', 'true');
    controls.appendChild(_previous);
    controls.appendChild(_status);
    controls.appendChild(_next);

    plan.root.insertBefore(controls, plan.root.firstChild);
    plan.root.setAttribute('role', 'region');
    plan.root.setAttribute('aria-label', plan.label);
    plan.root.setAttribute('data-esen-enhanced', 'true');
  }

  web.HTMLElement _control(
    String id,
    String label,
    _StepperControlEvent event,
    _StepperEventSink dispatch,
  ) {
    final button = document.createElement('button') as web.HTMLElement;
    button.setAttribute('type', 'button');
    button.id = id;
    button.setAttribute('data-esen-stepper-control', '');
    button.textContent = label;
    button.addEventListener(
      'click',
      ((web.Event _) => dispatch(0, event, false)).toJS,
    );
    return button;
  }

  void state(SeoStepperState state, {required bool moveFocus}) {
    for (var index = 0; index < _buttons.length; index++) {
      final selected = index == state.index;
      final button = _buttons[index];
      final panel = plan.entries[index].panel;
      if (selected) {
        button.setAttribute('aria-current', 'step');
        panel.removeAttribute('hidden');
      } else {
        button.removeAttribute('aria-current');
        panel.setAttribute('hidden', '');
      }
      button.setAttribute('aria-expanded', selected ? 'true' : 'false');
      button.setAttribute('tabindex', selected ? '0' : '-1');
    }
    _previous.setAttribute(
      'aria-disabled',
      state.index == 0 ? 'true' : 'false',
    );
    _next.setAttribute(
      'aria-disabled',
      state.index == state.count - 1 ? 'true' : 'false',
    );
    _status.textContent =
        '${plan.positionLabel} ${state.index + 1} / ${state.count}';
    if (moveFocus) _buttons[state.index].focus();
  }
}

final RegExp _headingTag = RegExp(r'^H[1-6]$');
final RegExp _decimalIndex = RegExp(r'^(0|[1-9][0-9]*)$');
