import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../components/seo_component_format.dart';
import '../components/seo_stepper_transition.dart';
import 'dom_first_adapter_web.dart';

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

/// Enhances admitted steppers with one application dispatcher and effects.
///
/// [interactionIds] is validated before discovery and scopes the runtime before
/// the first mutation. Other steppers remain complete static HTML.
void enhanceSeoDomFirstStepperEffects({
  required Set<String> interactionIds,
  required SeoStepperEffectTransition transition,
}) {
  if (interactionIds.isEmpty ||
      interactionIds.any((id) => !isValidSeoInteractionId(id))) {
    return;
  }
  for (final apply in _StepperApplyBoundary.discover(web.document)) {
    if (interactionIds.contains(apply.id)) {
      _enhanceStepperEffects(apply, transition);
    }
  }
}

void _enhanceStepper(
  _StepperApplyBoundary apply,
  SeoStepperTransition transition,
) {
  var state = initialSeoStepperState(
    count: apply.count,
    index: apply.fragmentIndex ?? apply.initialIndex,
  );

  void render({required bool moveFocus}) {
    apply.state(
      state,
      previousEnabled: canApplySeoStepperAction(
        transition,
        state,
        const SeoStepperPrevious(),
      ),
      nextEnabled: canApplySeoStepperAction(
        transition,
        state,
        const SeoStepperNext(),
      ),
      moveFocus: moveFocus,
    );
  }

  void dispatch(SeoStepperAction action, {required bool moveFocus}) {
    state = applySeoStepperTransition(transition, state, action);
    render(moveFocus: moveFocus);
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
  render(moveFocus: false);
}

void _enhanceStepperEffects(
  _StepperApplyBoundary apply,
  SeoStepperEffectTransition transition,
) {
  final context = SeoStepperEffectContext(interactionId: apply.id);
  var state = initialSeoStepperState(
    count: apply.count,
    index: apply.initialIndex,
  );

  void render({required bool moveFocus}) {
    apply.state(
      state,
      previousEnabled: canApplySeoStepperEffectAction(
        transition,
        state,
        const SeoStepperPrevious(),
        context,
      ),
      nextEnabled: canApplySeoStepperEffectAction(
        transition,
        state,
        const SeoStepperNext(),
        context,
      ),
      moveFocus: moveFocus,
    );
  }

  void dispatch(SeoStepperAction action, {required bool moveFocus}) {
    final result = applySeoStepperEffectTransition(
      transition,
      state,
      action,
      context,
    );
    if (result.state == state) return;
    state = result.state;
    render(moveFocus: moveFocus);
    apply.effects(
      state,
      result.effects,
      preserveControlFocus: moveFocus,
    );
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
  render(moveFocus: false);
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
    required this.buttonPlaceholder,
  });

  final web.HTMLElement step;
  final web.HTMLElement heading;
  final web.HTMLElement panel;
  final String buttonId;
  final web.Element? buttonPlaceholder;
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
    required this.placeholder,
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
  final web.Element? placeholder;
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
  String get id => plan.id;

  int? get fragmentIndex {
    final target = domFirstFragmentTarget(document, plan.root);
    if (target == null) return null;
    for (var index = 0; index < plan.entries.length; index++) {
      final panel = plan.entries[index].panel;
      if (panel == target || panel.contains(target)) return index;
    }
    return null;
  }

  static List<_StepperApplyBoundary> discover(web.Document document) {
    final container = domFirstContainer(document);
    if (container == null) return const [];

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
    if (domFirstHiddenByAncestor(root, container)) return null;
    final id = root.id;
    if (!isValidSeoInteractionId(id) || domFirstIdCount(document, id) != 1) {
      return null;
    }

    final rootChildren = root.children;
    final firstChild = rootChildren.item(0);
    final placeholder = firstChild != null &&
            firstChild.hasAttribute('data-esen-prepaint-placeholder')
        ? firstChild
        : null;
    final listOffset = placeholder == null ? 0 : 1;
    if (rootChildren.length != listOffset + 1) return null;
    final list = rootChildren.item(listOffset);
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

    final entries = <_StepperEntry>[];
    final ids = <String>{};
    final steps = list.children;
    if (steps.length < 2) return null;
    for (var index = 0; index < steps.length; index++) {
      final step = steps.item(index);
      final stepFirstChild = step?.children.item(0);
      final buttonPlaceholder = stepFirstChild != null &&
              stepFirstChild.hasAttribute('data-esen-prepaint-placeholder')
          ? stepFirstChild
          : null;
      final entryOffset = buttonPlaceholder == null ? 0 : 1;
      if (step == null ||
          step.tagName != 'LI' ||
          !step.hasAttribute('data-esen-step') ||
          step.children.length != entryOffset + 2) {
        return null;
      }
      final heading = step.children.item(entryOffset);
      final panel = step.children.item(entryOffset + 1);
      final expectedStepId = '$id-step-$index';
      final expectedPanelId = '$id-panel-$index';
      final buttonId = '$id-step-button-$index';
      if (heading == null ||
          panel == null ||
          step.id != expectedStepId ||
          panel.id != expectedPanelId ||
          !ids.add(step.id) ||
          !ids.add(panel.id) ||
          domFirstIdCount(document, step.id) != 1 ||
          domFirstIdCount(document, panel.id) != 1 ||
          domFirstIdCount(document, buttonId) != 0 ||
          !domFirstHeadingTag.hasMatch(heading.tagName) ||
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
        buttonPlaceholder: buttonPlaceholder,
      ));
    }
    final initialIndex = domFirstInitialIndex(root, entries.length);
    if (initialIndex == null) return null;
    if (!_validStableLayout(
      root: root,
      placeholder: placeholder,
      entries: entries,
      previousLabel: previousLabel,
      nextLabel: nextLabel,
      positionLabel: positionLabel,
      initialIndex: initialIndex,
    )) {
      return null;
    }

    for (final suffix in const ['previous', 'next', 'status']) {
      if (domFirstIdCount(document, '$id-$suffix') != 0) return null;
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
      placeholder: placeholder,
    );
  }

  static bool _validStableLayout({
    required web.Element root,
    required web.Element? placeholder,
    required List<_StepperEntry> entries,
    required String previousLabel,
    required String nextLabel,
    required String positionLabel,
    required int initialIndex,
  }) {
    final stable = root.getAttribute('data-esen-layout-stable') == 'true';
    if (!stable) {
      return placeholder == null &&
          entries.every((entry) => entry.buttonPlaceholder == null);
    }
    if (placeholder == null ||
        placeholder.tagName != 'DIV' ||
        placeholder.getAttribute('data-esen-prepaint-placeholder') !=
            'stepper' ||
        !placeholder.classList.contains('esen-seo-stepper-controls') ||
        !placeholder.hasAttribute('hidden') ||
        placeholder.getAttribute('aria-hidden') != 'true' ||
        placeholder.children.length != 3) {
      return false;
    }
    final previous = placeholder.children.item(0);
    final status = placeholder.children.item(1);
    final next = placeholder.children.item(2);
    if (previous == null ||
        status == null ||
        next == null ||
        previous.tagName != 'SPAN' ||
        status.tagName != 'SPAN' ||
        next.tagName != 'SPAN' ||
        !previous.classList.contains('esen-seo-stepper-control-placeholder') ||
        !status.classList.contains('esen-seo-stepper-status') ||
        !next.classList.contains('esen-seo-stepper-control-placeholder') ||
        previous.textContent != previousLabel ||
        status.textContent !=
            '$positionLabel ${initialIndex + 1} / ${entries.length}' ||
        next.textContent != nextLabel ||
        previous.getAttribute('data-esen-placeholder-disabled') !=
            (initialIndex == 0 ? 'true' : null) ||
        next.getAttribute('data-esen-placeholder-disabled') !=
            (initialIndex == entries.length - 1 ? 'true' : null)) {
      return false;
    }
    for (var index = 0; index < entries.length; index++) {
      final entry = entries[index];
      final button = entry.buttonPlaceholder;
      if (button == null ||
          button.tagName != 'SPAN' ||
          button.getAttribute('data-esen-prepaint-placeholder') !=
              'stepper-button' ||
          !button.classList.contains('esen-seo-step-button') ||
          !button.hasAttribute('hidden') ||
          button.getAttribute('aria-hidden') != 'true' ||
          button.textContent != entry.heading.textContent ||
          !entry.heading.hasAttribute('data-esen-step-heading') ||
          entry.panel.getAttribute('data-esen-initial-active') !=
              (index == initialIndex ? 'true' : null)) {
        return false;
      }
    }
    return true;
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
      final placeholder = entry.buttonPlaceholder;
      if (placeholder == null) {
        entry.step.insertBefore(button, entry.heading);
      } else {
        entry.step.replaceChild(button, placeholder);
      }
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

    final placeholder = plan.placeholder;
    if (placeholder == null) {
      plan.root.insertBefore(controls, plan.root.firstChild);
    } else {
      plan.root.replaceChild(controls, placeholder);
    }
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

  void state(
    SeoStepperState state, {
    required bool previousEnabled,
    required bool nextEnabled,
    required bool moveFocus,
  }) {
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
      previousEnabled ? 'false' : 'true',
    );
    _next.setAttribute(
      'aria-disabled',
      nextEnabled ? 'false' : 'true',
    );
    _previous.toggleAttribute('disabled', !previousEnabled);
    _next.toggleAttribute('disabled', !nextEnabled);
    _status.textContent =
        '${plan.positionLabel} ${state.index + 1} / ${state.count}';
    if (moveFocus) _buttons[state.index].focus();
  }

  void effects(
    SeoStepperState state,
    List<SeoStepperEffect> effects, {
    required bool preserveControlFocus,
  }) {
    for (final entry in plan.entries) {
      entry.panel.removeAttribute('tabindex');
    }
    for (final effect in effects) {
      switch (effect) {
        case SeoStepperFocusActivePanel():
          if (preserveControlFocus) continue;
          final panel = plan.entries[state.index].panel;
          panel.setAttribute('tabindex', '-1');
          panel.focus();
      }
    }
  }
}
