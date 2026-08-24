import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../components/seo_component_format.dart';
import '../components/seo_configurator_component.dart'
    show seoConfiguratorMaxAggregateLabelTextLength;
import '../components/seo_configurator_transition.dart';
import 'seo_container.dart';

/// Enhances admitted configurators through one closed application transition.
///
/// The complete static component, its initial projection and every generated
/// id are validated before the first mutation. Application code supplies only
/// state transitions and bounded fixed-slot values; this adapter owns every
/// element, attribute, event and focus decision.
void enhanceSeoDomFirstConfigurators({
  required Set<String> interactionIds,
  required SeoConfiguratorTransition transition,
  required SeoConfiguratorViewProjection project,
}) {
  if (interactionIds.isEmpty ||
      interactionIds.any((id) => !isValidSeoInteractionId(id))) {
    return;
  }
  for (final apply in _ConfiguratorApplyBoundary.discover(
    web.document,
    interactionIds,
    project,
  )) {
    _enhanceConfigurator(apply, transition, project);
  }
}

void _enhanceConfigurator(
  _ConfiguratorApplyBoundary apply,
  SeoConfiguratorTransition transition,
  SeoConfiguratorViewProjection project,
) {
  var current = apply.initial;
  var active = true;

  void dispatch(
    SeoConfiguratorAction action,
    web.HTMLElement source, {
    required bool moveChoiceFocus,
  }) {
    if (!active) return;
    final result = evaluateSeoConfiguratorAction(
      transition: transition,
      project: project,
      current: current,
      action: action,
      constraints: apply.constraints,
    );
    if (result == null) {
      active = false;
      return;
    }
    if (!result.accepted) return;
    apply.state(
      result,
      source: source,
      moveChoiceFocus: moveChoiceFocus,
    );
    current = result;
  }

  apply.mount(dispatch);
}

typedef _ConfiguratorEventSink = void Function(
  SeoConfiguratorAction action,
  web.HTMLElement source, {
  required bool moveChoiceFocus,
});

final class _ConfiguratorChoiceEntry {
  const _ConfiguratorChoiceEntry({
    required this.region,
    required this.label,
  });

  final web.HTMLElement region;
  final String label;
}

final class _ConfiguratorPlan {
  const _ConfiguratorPlan({
    required this.root,
    required this.id,
    required this.interactionLabel,
    required this.choiceLabel,
    required this.quantityLabel,
    required this.optionLabel,
    required this.decrementLabel,
    required this.incrementLabel,
    required this.constraints,
    required this.initial,
    required this.choices,
    required this.optionRegion,
    required this.priceSlot,
    required this.summarySlot,
    required this.status,
    required this.placeholder,
    required this.rtl,
  });

  final web.HTMLElement root;
  final String id;
  final String interactionLabel;
  final String choiceLabel;
  final String quantityLabel;
  final String optionLabel;
  final String decrementLabel;
  final String incrementLabel;
  final SeoConfiguratorConstraints constraints;
  final SeoConfiguratorEvaluation initial;
  final List<_ConfiguratorChoiceEntry> choices;
  final web.HTMLElement optionRegion;
  final web.HTMLElement priceSlot;
  final web.HTMLElement summarySlot;
  final web.HTMLElement status;
  final web.HTMLElement placeholder;
  final bool rtl;
}

final class _ConfiguratorApplyBoundary {
  _ConfiguratorApplyBoundary(this.document, this.plan);

  final web.Document document;
  final _ConfiguratorPlan plan;
  final List<web.HTMLElement> _choiceControls = [];
  late final web.HTMLElement _decrement;
  late final web.HTMLElement _increment;
  late final web.HTMLElement _quantityValue;
  late final web.HTMLElement _option;

  SeoConfiguratorConstraints get constraints => plan.constraints;
  SeoConfiguratorEvaluation get initial => plan.initial;

  static List<_ConfiguratorApplyBoundary> discover(
    web.Document document,
    Set<String> interactionIds,
    SeoConfiguratorViewProjection project,
  ) {
    final container = document.getElementById(seoContainerId);
    if (container == null ||
        container.getAttribute(seoDomFirstAttribute) != 'true' ||
        _idCount(document, seoContainerId) != 1) {
      return const [];
    }

    final boundaries = <_ConfiguratorApplyBoundary>[];
    final roots =
        container.querySelectorAll('[data-esen-component="configurator"]');
    for (var index = 0; index < roots.length; index++) {
      final raw = roots.item(index);
      if (raw == null) continue;
      final root = raw as web.Element;
      if (!interactionIds.contains(root.id)) continue;
      final plan = _validate(document, container, root, project);
      if (plan != null) {
        boundaries.add(_ConfiguratorApplyBoundary(document, plan));
      }
    }
    return boundaries;
  }

  static _ConfiguratorPlan? _validate(
    web.Document document,
    web.Element container,
    web.Element rawRoot,
    SeoConfiguratorViewProjection project,
  ) {
    if (rawRoot.tagName != 'SECTION' ||
        !rawRoot.classList.contains('esen-seo-configurator') ||
        rawRoot.getAttribute('data-esen-layout-stable') != 'true' ||
        rawRoot.getAttribute('data-esen-enhanced') == 'true' ||
        _hiddenByAncestor(rawRoot, container)) {
      return null;
    }
    final id = rawRoot.id;
    if (!isValidSeoInteractionId(id) || _idCount(document, id) != 1) {
      return null;
    }

    final interactionLabel = _fixedLabel(rawRoot, 'data-esen-label');
    final choiceLabel = _fixedLabel(rawRoot, 'data-esen-choice-label');
    final quantityLabel = _fixedLabel(rawRoot, 'data-esen-quantity-label');
    final optionLabel = _fixedLabel(rawRoot, 'data-esen-option-label');
    final decrementLabel = _fixedLabel(rawRoot, 'data-esen-decrement-label');
    final incrementLabel = _fixedLabel(rawRoot, 'data-esen-increment-label');
    if (interactionLabel == null ||
        choiceLabel == null ||
        quantityLabel == null ||
        optionLabel == null ||
        decrementLabel == null ||
        incrementLabel == null) {
      return null;
    }
    final fixedLabelLength = interactionLabel.length +
        choiceLabel.length +
        quantityLabel.length +
        optionLabel.length +
        decrementLabel.length +
        incrementLabel.length;

    final minQuantity = _strictDecimalAttribute(
      rawRoot,
      'data-esen-min-quantity',
    );
    final maxQuantity = _strictDecimalAttribute(
      rawRoot,
      'data-esen-max-quantity',
    );
    final initialChoice = _strictDecimalAttribute(
      rawRoot,
      'data-esen-initial-choice',
    );
    final initialQuantity = _strictDecimalAttribute(
      rawRoot,
      'data-esen-initial-quantity',
    );
    final initialOption =
        switch (rawRoot.getAttribute('data-esen-initial-option')) {
      'true' => true,
      'false' => false,
      _ => null,
    };
    if (minQuantity == null ||
        maxQuantity == null ||
        initialChoice == null ||
        initialQuantity == null ||
        initialOption == null) {
      return null;
    }

    final placeholderMatches = rawRoot.querySelectorAll(
      ':scope > [data-esen-prepaint-placeholder="configurator"]',
    );
    final priceMatches =
        rawRoot.querySelectorAll(':scope > p > [data-esen-configurator-price]');
    final summaryMatches = rawRoot
        .querySelectorAll(':scope > p > [data-esen-configurator-summary]');
    final statusMatches =
        rawRoot.querySelectorAll(':scope > [data-esen-configurator-status]');
    final choiceRegions = rawRoot.querySelectorAll(
      ':scope > section[data-esen-configurator-choice-region]',
    );
    final optionMatches = rawRoot.querySelectorAll(
      ':scope > section[data-esen-configurator-option-region]',
    );
    if (placeholderMatches.length != 1 ||
        priceMatches.length != 1 ||
        summaryMatches.length != 1 ||
        statusMatches.length != 1 ||
        optionMatches.length != 1 ||
        choiceRegions.length < 1 ||
        choiceRegions.length > seoConfiguratorMaxChoices) {
      return null;
    }
    final directChildren = rawRoot.children;
    final priceParagraph = directChildren.item(2);
    final summaryParagraph = directChildren.item(3);
    if (directChildren.length != choiceRegions.length + 7 ||
        directChildren.item(1) != placeholderMatches.item(0) ||
        priceParagraph?.tagName != 'P' ||
        priceParagraph?.children.length != 2 ||
        priceParagraph?.children.item(0)?.tagName != 'STRONG' ||
        priceParagraph?.children.item(1) != priceMatches.item(0) ||
        summaryParagraph?.tagName != 'P' ||
        summaryParagraph?.children.length != 1 ||
        summaryParagraph?.children.item(0) != summaryMatches.item(0) ||
        directChildren.item(5 + choiceRegions.length) !=
            optionMatches.item(0) ||
        directChildren.item(6 + choiceRegions.length) !=
            statusMatches.item(0) ||
        !_headingTag.hasMatch(directChildren.item(0)?.tagName ?? '') ||
        !_headingTag.hasMatch(directChildren.item(4)?.tagName ?? '')) {
      return null;
    }
    for (var index = 0; index < choiceRegions.length; index++) {
      if (directChildren.item(5 + index) != choiceRegions.item(index)) {
        return null;
      }
    }

    final constraints = SeoConfiguratorConstraints(
      choiceCount: choiceRegions.length,
      minQuantity: minQuantity,
      maxQuantity: maxQuantity,
    );
    final state = SeoConfiguratorState(
      choiceIndex: initialChoice,
      quantity: initialQuantity,
      optionEnabled: initialOption,
    );
    final initial = evaluateInitialSeoConfiguratorView(
      project,
      state,
      constraints,
    );
    if (initial == null) return null;

    final priceSlot = priceMatches.item(0)! as web.Element;
    final summarySlot = summaryMatches.item(0)! as web.Element;
    final status = statusMatches.item(0)! as web.Element;
    final optionRegion = optionMatches.item(0)! as web.Element;
    final placeholder = placeholderMatches.item(0)! as web.Element;
    if (priceSlot.tagName != 'SPAN' ||
        summarySlot.tagName != 'SPAN' ||
        status.tagName != 'SPAN' ||
        optionRegion.tagName != 'SECTION' ||
        placeholder.tagName != 'DIV' ||
        priceSlot.childElementCount != 0 ||
        summarySlot.childElementCount != 0 ||
        status.childElementCount != 0 ||
        priceSlot.textContent != initial.view.priceText ||
        summarySlot.textContent != initial.view.summaryText ||
        status.textContent != '' ||
        status.getAttribute('aria-live') != 'polite' ||
        status.getAttribute('aria-atomic') != 'true' ||
        !status.classList.contains('esen-seo-configurator-status') ||
        optionRegion.id != '$id-option' ||
        _idCount(document, optionRegion.id) != 1 ||
        optionRegion.getAttribute('data-esen-initial-visible') !=
            (initialOption ? 'true' : null) ||
        !_validPlaceholder(
          placeholder as web.HTMLElement,
          choiceCount: choiceRegions.length,
          choiceLabels: [
            for (var index = 0; index < choiceRegions.length; index++)
              _choiceLabel(choiceRegions.item(index), index, id),
          ],
          choiceIndex: initialChoice,
          quantity: initialQuantity,
          minQuantity: minQuantity,
          maxQuantity: maxQuantity,
          decrementLabel: decrementLabel,
          incrementLabel: incrementLabel,
          optionLabel: optionLabel,
          optionEnabled: initialOption,
        )) {
      return null;
    }

    final choices = <_ConfiguratorChoiceEntry>[];
    final labels = <String>{};
    for (var index = 0; index < choiceRegions.length; index++) {
      final region = choiceRegions.item(index)! as web.Element;
      final label = _choiceLabel(region, index, id);
      if (label == null ||
          !labels.add(label) ||
          region.getAttribute('data-esen-initial-active') !=
              (index == initialChoice ? 'true' : null) ||
          _idCount(document, region.id) != 1) {
        return null;
      }
      choices.add(_ConfiguratorChoiceEntry(
        region: region as web.HTMLElement,
        label: label,
      ));
    }
    final aggregateLabelLength = fixedLabelLength +
        choices.fold<int>(0, (total, choice) => total + choice.label.length);
    if (aggregateLabelLength > seoConfiguratorMaxAggregateLabelTextLength) {
      return null;
    }
    final optionHeading = optionRegion.children.item(0);
    if (optionHeading == null ||
        !_headingTag.hasMatch(optionHeading.tagName) ||
        optionHeading.textContent != optionLabel ||
        optionHeading.childElementCount != 0) {
      return null;
    }

    for (final suffix in [
      'choices',
      'quantity',
      'decrement',
      'quantity-value',
      'increment',
      'option-control',
      for (var index = 0; index < choices.length; index++)
        'choice-control-$index',
    ]) {
      if (_idCount(document, '$id-$suffix') != 0) return null;
    }

    return _ConfiguratorPlan(
      root: rawRoot as web.HTMLElement,
      id: id,
      interactionLabel: interactionLabel,
      choiceLabel: choiceLabel,
      quantityLabel: quantityLabel,
      optionLabel: optionLabel,
      decrementLabel: decrementLabel,
      incrementLabel: incrementLabel,
      constraints: constraints,
      initial: initial,
      choices: List.unmodifiable(choices),
      optionRegion: optionRegion as web.HTMLElement,
      priceSlot: priceSlot as web.HTMLElement,
      summarySlot: summarySlot as web.HTMLElement,
      status: status as web.HTMLElement,
      placeholder: placeholder,
      rtl: web.window.getComputedStyle(rawRoot).direction == 'rtl',
    );
  }

  static String? _fixedLabel(web.Element root, String name) {
    final raw = root.getAttribute(name);
    if (raw == null) return null;
    final canonical = canonicalizeSeoConfiguratorText(raw, maxLength: 128);
    if (canonical == null || canonical != raw) return null;
    return canonical;
  }

  static int? _strictDecimalAttribute(web.Element root, String name) {
    final raw = root.getAttribute(name);
    if (raw == null || !_decimal.hasMatch(raw)) return null;
    return int.tryParse(raw);
  }

  static String? _choiceLabel(web.Node? rawNode, int index, String id) {
    if (rawNode == null) return null;
    final raw = rawNode as web.Element;
    if (raw.tagName != 'SECTION' ||
        raw.id != '$id-choice-$index' ||
        raw.getAttribute('data-esen-configurator-choice-region') != '$index') {
      return null;
    }
    final names = raw.querySelectorAll(
      ':scope > [data-esen-configurator-choice-name]',
    );
    if (names.length != 1) return null;
    final name = names.item(0) as web.Element?;
    if (name == null || !_headingTag.hasMatch(name.tagName)) return null;
    final rawLabel = name.textContent ?? '';
    final label = canonicalizeSeoConfiguratorText(rawLabel, maxLength: 128);
    return name.childElementCount == 0 && label == rawLabel ? label : null;
  }

  static bool _validPlaceholder(
    web.HTMLElement placeholder, {
    required int choiceCount,
    required List<String?> choiceLabels,
    required int choiceIndex,
    required int quantity,
    required int minQuantity,
    required int maxQuantity,
    required String decrementLabel,
    required String incrementLabel,
    required String optionLabel,
    required bool optionEnabled,
  }) {
    if (placeholder.getAttribute('data-esen-layout-stable') != null ||
        !placeholder.classList.contains('esen-seo-configurator-controls') ||
        !placeholder.hasAttribute('hidden') ||
        placeholder.getAttribute('aria-hidden') != 'true' ||
        placeholder.children.length != 3 ||
        choiceLabels.any((label) => label == null)) {
      return false;
    }
    final choices = placeholder.children.item(0);
    final quantityGroup = placeholder.children.item(1);
    final option = placeholder.children.item(2);
    if (choices == null ||
        quantityGroup == null ||
        option == null ||
        choices.tagName != 'DIV' ||
        quantityGroup.tagName != 'DIV' ||
        option.tagName != 'SPAN' ||
        !choices.classList.contains('esen-seo-configurator-choices') ||
        !quantityGroup.classList.contains('esen-seo-configurator-quantity') ||
        !option.classList
            .contains('esen-seo-configurator-control-placeholder') ||
        choices.children.length != choiceCount ||
        quantityGroup.children.length != 3 ||
        option.textContent != optionLabel ||
        option.getAttribute('data-esen-placeholder-selected') !=
            (optionEnabled ? 'true' : null)) {
      return false;
    }
    for (var index = 0; index < choiceCount; index++) {
      final choice = choices.children.item(index);
      if (choice == null ||
          choice.tagName != 'SPAN' ||
          !choice.classList
              .contains('esen-seo-configurator-control-placeholder') ||
          choice.textContent != choiceLabels[index] ||
          choice.childElementCount != 0 ||
          choice.getAttribute('data-esen-placeholder-selected') !=
              (index == choiceIndex ? 'true' : null)) {
        return false;
      }
    }
    final decrement = quantityGroup.children.item(0);
    final value = quantityGroup.children.item(1);
    final increment = quantityGroup.children.item(2);
    return decrement != null &&
        value != null &&
        increment != null &&
        decrement.tagName == 'SPAN' &&
        value.tagName == 'SPAN' &&
        increment.tagName == 'SPAN' &&
        decrement.textContent == decrementLabel &&
        value.textContent == '$quantity' &&
        increment.textContent == incrementLabel &&
        decrement.childElementCount == 0 &&
        value.childElementCount == 0 &&
        increment.childElementCount == 0 &&
        decrement.classList
            .contains('esen-seo-configurator-control-placeholder') &&
        value.classList.contains('esen-seo-configurator-quantity-value') &&
        increment.classList
            .contains('esen-seo-configurator-control-placeholder') &&
        decrement.getAttribute('data-esen-placeholder-disabled') ==
            (quantity == minQuantity ? 'true' : null) &&
        increment.getAttribute('data-esen-placeholder-disabled') ==
            (quantity == maxQuantity ? 'true' : null);
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

  void mount(_ConfiguratorEventSink dispatch) {
    final controls = document.createElement('div') as web.HTMLElement;
    controls.className = 'esen-seo-configurator-controls';
    controls.setAttribute('data-esen-configurator-controls', '');

    final choiceGroup = document.createElement('div') as web.HTMLElement;
    choiceGroup.id = '${plan.id}-choices';
    choiceGroup.className = 'esen-seo-configurator-choices';
    choiceGroup.setAttribute('role', 'radiogroup');
    choiceGroup.setAttribute('aria-label', plan.choiceLabel);
    for (var index = 0; index < plan.choices.length; index++) {
      final control = document.createElement('button') as web.HTMLElement;
      control.id = '${plan.id}-choice-control-$index';
      control.setAttribute('type', 'button');
      control.setAttribute('role', 'radio');
      control.setAttribute('data-esen-configurator-choice-control', '$index');
      control.textContent = plan.choices[index].label;
      control.addEventListener(
        'click',
        ((web.Event _) => dispatch(
              SeoConfiguratorSelectChoice(index),
              control,
              moveChoiceFocus: false,
            )).toJS,
      );
      control.addEventListener(
        'keydown',
        ((web.Event rawEvent) {
          final event = rawEvent as web.KeyboardEvent;
          if (event.repeat) return;
          final current = _selectedChoiceIndex();
          final focusedIndex = _choiceControls.indexOf(control);
          final target = switch (event.key) {
            'ArrowDown' => (focusedIndex + 1) % plan.choices.length,
            'ArrowUp' =>
              (focusedIndex - 1 + plan.choices.length) % plan.choices.length,
            'ArrowRight' => plan.rtl
                ? (focusedIndex - 1 + plan.choices.length) % plan.choices.length
                : (focusedIndex + 1) % plan.choices.length,
            'ArrowLeft' => plan.rtl
                ? (focusedIndex + 1) % plan.choices.length
                : (focusedIndex - 1 + plan.choices.length) %
                    plan.choices.length,
            'Home' => 0,
            'End' => plan.choices.length - 1,
            _ => current,
          };
          if (target == current &&
              !const {
                'ArrowDown',
                'ArrowUp',
                'ArrowRight',
                'ArrowLeft',
                'Home',
                'End'
              }.contains(event.key)) {
            return;
          }
          event.preventDefault();
          dispatch(
            SeoConfiguratorSelectChoice(target),
            control,
            moveChoiceFocus: true,
          );
          final selected = _selectedChoiceIndex();
          if (selected >= 0) _choiceControls[selected].focus();
        }).toJS,
      );
      _choiceControls.add(control);
      choiceGroup.appendChild(control);
    }

    final quantityGroup = document.createElement('div') as web.HTMLElement;
    quantityGroup.id = '${plan.id}-quantity';
    quantityGroup.className = 'esen-seo-configurator-quantity';
    quantityGroup.setAttribute('role', 'group');
    quantityGroup.setAttribute('aria-label', plan.quantityLabel);
    _decrement = _button(
      id: '${plan.id}-decrement',
      label: plan.decrementLabel,
      marker: 'data-esen-configurator-decrement',
      action: const SeoConfiguratorDecrementQuantity(),
      dispatch: dispatch,
    );
    _quantityValue = document.createElement('span') as web.HTMLElement;
    _quantityValue.id = '${plan.id}-quantity-value';
    _quantityValue.className = 'esen-seo-configurator-quantity-value';
    _quantityValue.setAttribute('data-esen-configurator-quantity-value', '');
    _quantityValue.setAttribute('aria-label', plan.quantityLabel);
    _increment = _button(
      id: '${plan.id}-increment',
      label: plan.incrementLabel,
      marker: 'data-esen-configurator-increment',
      action: const SeoConfiguratorIncrementQuantity(),
      dispatch: dispatch,
    );
    quantityGroup.appendChild(_decrement);
    quantityGroup.appendChild(_quantityValue);
    quantityGroup.appendChild(_increment);

    _option = document.createElement('button') as web.HTMLElement;
    _option.id = '${plan.id}-option-control';
    _option.setAttribute('type', 'button');
    _option.setAttribute('data-esen-configurator-option-control', '');
    _option.textContent = plan.optionLabel;
    _option.addEventListener(
      'click',
      ((web.Event _) => dispatch(
            SeoConfiguratorSetOption(
              _option.getAttribute('aria-pressed') != 'true',
            ),
            _option,
            moveChoiceFocus: false,
          )).toJS,
    );

    controls.appendChild(choiceGroup);
    controls.appendChild(quantityGroup);
    controls.appendChild(_option);
    plan.root.replaceChild(controls, plan.placeholder);
    plan.root.setAttribute('role', 'region');
    plan.root.setAttribute('aria-label', plan.interactionLabel);
    _controlState(plan.initial);
    plan.root.setAttribute('data-esen-enhanced', 'true');
  }

  web.HTMLElement _button({
    required String id,
    required String label,
    required String marker,
    required SeoConfiguratorAction action,
    required _ConfiguratorEventSink dispatch,
  }) {
    final button = document.createElement('button') as web.HTMLElement;
    button.id = id;
    button.setAttribute('type', 'button');
    button.setAttribute(marker, '');
    button.textContent = label;
    button.addEventListener(
      'click',
      ((web.Event _) => dispatch(
            action,
            button,
            moveChoiceFocus: false,
          )).toJS,
    );
    return button;
  }

  void state(
    SeoConfiguratorEvaluation evaluation, {
    required web.HTMLElement source,
    required bool moveChoiceFocus,
  }) {
    final activeElement = document.activeElement;
    final activeWillHide = _containsFocusedNode(
      activeElement,
      evaluation.view,
    );

    plan.priceSlot.textContent = evaluation.view.priceText;
    plan.summarySlot.textContent = evaluation.view.summaryText;
    for (var index = 0; index < plan.choices.length; index++) {
      plan.choices[index].region.toggleAttribute(
        'hidden',
        index != evaluation.view.activeChoiceRegion,
      );
    }
    plan.optionRegion.toggleAttribute(
      'hidden',
      !evaluation.view.optionRegionVisible,
    );
    _controlState(evaluation);
    plan.root.setAttribute('data-esen-configurator-changed', 'true');
    plan.status.textContent = evaluation.view.announcementText;

    if (moveChoiceFocus) {
      _choiceControls[evaluation.state.choiceIndex].focus();
    } else if (activeWillHide) {
      source.focus();
    }
  }

  void _controlState(SeoConfiguratorEvaluation evaluation) {
    final state = evaluation.state;
    for (var index = 0; index < _choiceControls.length; index++) {
      final selected = index == state.choiceIndex;
      _choiceControls[index].setAttribute(
        'aria-checked',
        selected ? 'true' : 'false',
      );
      _choiceControls[index].setAttribute('tabindex', selected ? '0' : '-1');
    }
    _decrement.toggleAttribute(
      'disabled',
      state.quantity == plan.constraints.minQuantity,
    );
    _increment.toggleAttribute(
      'disabled',
      state.quantity == plan.constraints.maxQuantity,
    );
    _quantityValue.textContent = '${state.quantity}';
    _option.setAttribute(
      'aria-pressed',
      state.optionEnabled ? 'true' : 'false',
    );
  }

  int _selectedChoiceIndex() {
    for (var index = 0; index < _choiceControls.length; index++) {
      if (_choiceControls[index].getAttribute('aria-checked') == 'true') {
        return index;
      }
    }
    return -1;
  }

  bool _containsFocusedNode(
    web.Element? activeElement,
    SeoConfiguratorView view,
  ) {
    if (activeElement == null) return false;
    for (var index = 0; index < plan.choices.length; index++) {
      if (index != view.activeChoiceRegion &&
          plan.choices[index].region.contains(activeElement)) {
        return true;
      }
    }
    return !view.optionRegionVisible &&
        plan.optionRegion.contains(activeElement);
  }
}

final RegExp _decimal = RegExp(r'^(0|[1-9][0-9]*)$');
final RegExp _headingTag = RegExp(r'^H[1-6]$');
