@TestOn('browser')
library;

import 'package:esen_seo/src/components/seo_stepper_transition.dart';
import 'package:esen_seo/src/renderer/dom_first_stepper_adapter_web.dart';
import 'package:esen_seo/src/renderer/seo_dom_first_stepper_runtime.g.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;

void main() {
  late web.HTMLElement fixture;

  setUp(() {
    fixture = web.document.createElement('div') as web.HTMLElement;
    fixture.id = 'dom-first-stepper-fixture';
    web.document.body?.appendChild(fixture);
  });

  tearDown(() => fixture.remove());

  test('compiled stepper uses the shared transition for every control', () {
    final container = _container(fixture);
    final root = _stepper(container, 'compiled-stepper', initialIndex: 1);

    expect(root.textContent, contains('Account content'));
    expect(root.textContent, contains('Review content'));
    expect(root.querySelectorAll('button').length, 0);
    _runCompiledCandidate();

    final buttons = root.querySelectorAll('[data-esen-step-button]');
    final panels = root.querySelectorAll('[data-esen-step-panel]');
    final controls = root.querySelectorAll('[data-esen-stepper-control]');
    final first = buttons.item(0)! as web.HTMLElement;
    final second = buttons.item(1)! as web.HTMLElement;
    final third = buttons.item(2)! as web.HTMLElement;
    final previous = controls.item(0)! as web.HTMLElement;
    final next = controls.item(1)! as web.HTMLElement;
    final status = root.querySelector('[data-esen-stepper-status]')!;

    expect(root.getAttribute('role'), 'region');
    expect(root.getAttribute('aria-label'), 'Publishing flow');
    expect(buttons.length, 3);
    expect(controls.length, 2);
    expect(root.querySelectorAll('h3[hidden]').length, 3);
    expect(second.getAttribute('aria-current'), 'step');
    expect(second.getAttribute('aria-expanded'), 'true');
    expect(second.getAttribute('tabindex'), '0');
    expect(first.getAttribute('tabindex'), '-1');
    expect((panels.item(0)! as web.Element).hasAttribute('hidden'), isTrue);
    expect((panels.item(1)! as web.Element).hasAttribute('hidden'), isFalse);
    expect(status.textContent, 'Step 2 / 3');
    expect(status.getAttribute('aria-live'), 'polite');

    third.dispatchEvent(
      web.MouseEvent('click', web.MouseEventInit(bubbles: true)),
    );
    expect(status.textContent, 'Step 3 / 3');
    expect(next.getAttribute('aria-disabled'), 'true');
    next.dispatchEvent(
      web.MouseEvent('click', web.MouseEventInit(bubbles: true)),
    );
    expect(status.textContent, 'Step 3 / 3');

    previous.dispatchEvent(
      web.MouseEvent('click', web.MouseEventInit(bubbles: true)),
    );
    expect(status.textContent, 'Step 2 / 3');
    _keydown(second, 'Home');
    expect(status.textContent, 'Step 1 / 3');
    expect(web.document.activeElement?.id, first.id);
    _keydown(first, 'ArrowDown');
    expect(status.textContent, 'Step 2 / 3');
    _keydown(second, 'End');
    expect(status.textContent, 'Step 3 / 3');
    _keydown(third, 'ArrowUp', repeat: true);
    expect(status.textContent, 'Step 3 / 3');

    _runCompiledCandidate();
    expect(root.querySelectorAll('[data-esen-stepper-controls]').length, 1);
    expect(root.querySelectorAll('[data-esen-step-button]').length, 3);
  });

  test('invalid or ambiguous steppers remain entirely unmodified', () {
    final container = _container(fixture);
    final duplicateA = _stepper(container, 'duplicate-stepper');
    final duplicateB = _stepper(container, 'duplicate-stepper');
    final collision = _stepper(container, 'collision-stepper');
    container.appendChild(
      web.document.createElement('div')..id = 'collision-stepper-step-button-0',
    );
    final wrongPanel = _stepper(container, 'wrong-panel-stepper');
    wrongPanel.querySelector('[data-esen-step-panel]')?.id = 'borrowed-panel';
    final malformed = _stepper(container, 'malformed-stepper');
    malformed.querySelector('li')?.appendChild(web.document.createElement('p'));
    final emptyHeading = _stepper(container, 'empty-heading-stepper');
    emptyHeading.querySelector('h3')?.textContent = '   ';
    final emptyLabel = _stepper(container, 'empty-label-stepper');
    emptyLabel.setAttribute('data-esen-next-label', '   ');
    final badIndex = _stepper(container, 'bad-index-stepper');
    badIndex.setAttribute('data-esen-initial-index', '01');
    final single = _stepper(container, 'single-stepper', count: 1);
    final inertParent = web.document.createElement('div')
      ..setAttribute('inert', '');
    container.appendChild(inertParent);
    final inert = _stepper(inertParent, 'inert-stepper');
    final ariaHiddenParent = web.document.createElement('div')
      ..setAttribute('aria-hidden', ' TRUE ');
    container.appendChild(ariaHiddenParent);
    final ariaHidden = _stepper(ariaHiddenParent, 'aria-hidden-stepper');
    final hiddenParent = web.document.createElement('div')
      ..setAttribute('hidden', '');
    container.appendChild(hiddenParent);
    final hidden = _stepper(hiddenParent, 'hidden-stepper');
    final outside = _stepper(fixture, 'outside-stepper');

    _runCompiledCandidate();

    for (final root in [
      duplicateA,
      duplicateB,
      collision,
      wrongPanel,
      malformed,
      emptyHeading,
      emptyLabel,
      badIndex,
      single,
      inert,
      ariaHidden,
      outside,
    ]) {
      expect(root.querySelectorAll('button').length, 0);
      expect(root.querySelectorAll('[hidden]').length, 0);
      expect(root.querySelectorAll('[role]').length, 0);
      expect(root.hasAttribute('data-esen-enhanced'), isFalse);
      expect(root.textContent, contains('Account content'));
    }
    expect(hiddenParent.hasAttribute('hidden'), isTrue);
    expect(hidden.hasAttribute('data-esen-enhanced'), isTrue);
    expect(hidden.querySelectorAll('[data-esen-step-button]').length, 3);
  });

  test('requires one unambiguous package-owned DOM-first container', () {
    final first = _container(fixture);
    final root = _stepper(first, 'container-stepper');
    final second = web.document.createElement('div')
      ..id = 'esen-seo-content'
      ..setAttribute('data-esen-seo-dom-first', 'true');
    fixture.appendChild(second);

    _runCompiledCandidate();

    expect(root.querySelectorAll('button').length, 0);
    expect(root.querySelectorAll('[hidden]').length, 0);
  });

  test('copies hostile-looking labels only through text content', () {
    final container = _container(fixture);
    final root = _stepper(container, 'text-stepper');
    root.querySelector('h3')?.textContent = '<img src=x onerror=alert(1)>';

    _runCompiledCandidate();

    final button =
        root.querySelector('[data-esen-step-button]')! as web.HTMLElement;
    expect(button.textContent, '<img src=x onerror=alert(1)>');
    expect(button.querySelectorAll('img').length, 0);
    expect(root.querySelectorAll('[onerror]').length, 0);
  });

  test('adapter executes an application transition instead of the default', () {
    final container = _container(fixture);
    final root = _stepper(container, 'application-stepper', initialIndex: 0);

    SeoStepperState skipMiddle(
      SeoStepperState state,
      SeoStepperAction action,
    ) {
      if (action is SeoStepperNext && state.index == 0) {
        return SeoStepperState(index: 2, count: state.count);
      }
      return transitionSeoStepper(state, action);
    }

    enhanceSeoDomFirstSteppers(transition: skipMiddle);
    final next = root.querySelectorAll('[data-esen-stepper-control]').item(1)!
        as web.HTMLElement;
    next.dispatchEvent(
      web.MouseEvent('click', web.MouseEventInit(bubbles: true)),
    );
    final third = root.querySelectorAll('[data-esen-step-button]').item(2)!
        as web.Element;

    expect(
      root.querySelector('[data-esen-stepper-status]')?.textContent,
      'Step 3 / 3',
    );
    expect(third.getAttribute('aria-current'), 'step');
  });

  test('application transition owns boundary control availability', () {
    final container = _container(fixture);
    final root = _stepper(container, 'wrapping-stepper', initialIndex: 0);

    SeoStepperState wrap(
      SeoStepperState state,
      SeoStepperAction action,
    ) {
      if (action is SeoStepperPrevious && state.index == 0) {
        return SeoStepperState(index: state.count - 1, count: state.count);
      }
      return transitionSeoStepper(state, action);
    }

    enhanceSeoDomFirstSteppers(transition: wrap);
    final previous = root
        .querySelectorAll('[data-esen-stepper-control]')
        .item(0)! as web.HTMLElement;
    expect(previous.getAttribute('aria-disabled'), 'false');
    expect(previous.hasAttribute('disabled'), isFalse);

    previous.dispatchEvent(
      web.MouseEvent('click', web.MouseEventInit(bubbles: true)),
    );

    expect(
      root.querySelector('[data-esen-stepper-status]')?.textContent,
      'Step 3 / 3',
    );
  });

  test('application effect focuses only the active panel after state', () {
    final container = _container(fixture);
    final root = _stepper(container, 'effect-stepper', initialIndex: 0);

    SeoStepperEffectResult focusAfterChange(
      SeoStepperState state,
      SeoStepperAction action,
    ) {
      final next = transitionSeoStepper(state, action);
      return SeoStepperEffectResult(
        state: next,
        effect: next == state ? null : const SeoStepperFocusActivePanel(),
      );
    }

    enhanceSeoDomFirstStepperEffects(transition: focusAfterChange);
    final firstPanel = root.querySelector('#effect-stepper-panel-0')!;
    final secondPanel = root.querySelector('#effect-stepper-panel-1')!;
    expect(firstPanel.hasAttribute('tabindex'), isFalse);
    expect(secondPanel.hasAttribute('tabindex'), isFalse);
    expect(web.document.activeElement, isNot(firstPanel));

    final next = root.querySelectorAll('[data-esen-stepper-control]').item(1)!
        as web.HTMLElement;
    next.dispatchEvent(
      web.MouseEvent('click', web.MouseEventInit(bubbles: true)),
    );

    expect(secondPanel.getAttribute('tabindex'), '-1');
    expect(secondPanel.hasAttribute('hidden'), isFalse);
    expect(web.document.activeElement, secondPanel);
    expect(firstPanel.hasAttribute('tabindex'), isFalse);

    final previous = root
        .querySelectorAll('[data-esen-stepper-control]')
        .item(0)! as web.HTMLElement;
    previous.dispatchEvent(
      web.MouseEvent('click', web.MouseEventInit(bubbles: true)),
    );

    expect(firstPanel.getAttribute('tabindex'), '-1');
    expect(web.document.activeElement, firstPanel);
    expect(secondPanel.hasAttribute('tabindex'), isFalse);
  });

  test('invalid effect result keeps DOM and focus unchanged', () {
    final container = _container(fixture);
    final root = _stepper(container, 'invalid-effect-stepper', initialIndex: 0);

    enhanceSeoDomFirstStepperEffects(
      transition: (state, action) => SeoStepperEffectResult(
        state: SeoStepperState(index: state.count, count: state.count),
        effect: const SeoStepperFocusActivePanel(),
      ),
    );
    final firstButton =
        root.querySelector('[data-esen-step-button]')! as web.HTMLElement;
    firstButton.focus();
    final next = root.querySelectorAll('[data-esen-stepper-control]').item(1)!
        as web.HTMLElement;
    next.dispatchEvent(
      web.MouseEvent('click', web.MouseEventInit(bubbles: true)),
    );

    expect(
      root.querySelector('[data-esen-stepper-status]')?.textContent,
      'Step 1 / 3',
    );
    expect(root.querySelectorAll('[data-esen-step-panel][tabindex]').length, 0);
    expect(web.document.activeElement, firstButton);
  });

  test('RTL horizontal arrows follow visual direction', () {
    final container = _container(fixture);
    final root = _stepper(container, 'rtl-stepper', initialIndex: 1)
      ..setAttribute('dir', 'rtl');

    enhanceSeoDomFirstSteppers();
    final second = root.querySelectorAll('[data-esen-step-button]').item(1)!
        as web.HTMLElement;
    _keydown(second, 'ArrowRight');

    expect(
      root.querySelector('[data-esen-stepper-status]')?.textContent,
      'Step 1 / 3',
    );
  });
}

web.HTMLElement _container(web.HTMLElement fixture) {
  final container = web.document.createElement('div') as web.HTMLElement
    ..id = 'esen-seo-content'
    ..setAttribute('data-esen-seo-dom-first', 'true');
  fixture.appendChild(container);
  return container;
}

web.HTMLElement _stepper(
  web.Element parent,
  String id, {
  int count = 3,
  int initialIndex = 1,
}) {
  final root = web.document.createElement('div') as web.HTMLElement
    ..id = id
    ..className = 'esen-seo-stepper'
    ..setAttribute('data-esen-component', 'stepper')
    ..setAttribute('data-esen-label', 'Publishing flow')
    ..setAttribute('data-esen-previous-label', 'Back')
    ..setAttribute('data-esen-next-label', 'Next')
    ..setAttribute('data-esen-position-label', 'Step')
    ..setAttribute('data-esen-initial-index', '$initialIndex');
  final list = web.document.createElement('ol')
    ..setAttribute('data-esen-step-list', '');
  const labels = ['Account', 'Address', 'Review'];
  for (var index = 0; index < count; index++) {
    final step = web.document.createElement('li')
      ..id = '$id-step-$index'
      ..setAttribute('data-esen-step', '');
    step.appendChild(
      web.document.createElement('h3')..textContent = labels[index],
    );
    final panel = web.document.createElement('div')
      ..id = '$id-panel-$index'
      ..setAttribute('data-esen-step-panel', '');
    panel.appendChild(
      web.document.createElement('p')..textContent = '${labels[index]} content',
    );
    step.appendChild(panel);
    list.appendChild(step);
  }
  root.appendChild(list);
  parent.appendChild(root);
  return root;
}

void _runCompiledCandidate() {
  final script = web.document.createElement('script')
    ..textContent = seoDomFirstStepperRuntime;
  web.document.body?.appendChild(script);
  script.remove();
}

void _keydown(web.Element element, String key, {bool repeat = false}) {
  element.dispatchEvent(
    web.KeyboardEvent(
      'keydown',
      web.KeyboardEventInit(key: key, repeat: repeat, bubbles: true),
    ),
  );
}
