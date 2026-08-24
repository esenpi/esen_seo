@TestOn('browser')
library;

import 'dart:js_interop';

import 'package:esen_seo/src/components/seo_configurator_component.dart';
import 'package:esen_seo/src/components/seo_configurator_transition.dart';
import 'package:esen_seo/src/renderer/dom_first_configurator_adapter_web.dart';
import 'package:esen_seo/src/renderer/html_renderer.dart';
import 'package:esen_seo/src/renderer/seo_node.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;

const _constraints = SeoConfiguratorConstraints(
  choiceCount: 3,
  minQuantity: 1,
  maxQuantity: 20,
);

void main() {
  late web.HTMLElement fixture;

  setUp(() {
    fixture = web.document.createElement('div') as web.HTMLElement;
    fixture.id = 'dom-first-configurator-fixture';
    web.document.body?.appendChild(fixture);
  });

  tearDown(() => fixture.remove());

  test('executes the frozen pricing sequence through package controls', () {
    final root = _configurator(fixture);

    enhanceSeoDomFirstConfigurators(
      interactionIds: const {'pricing-configurator'},
      transition: transitionSeoConfigurator,
      project: _pricingView,
    );

    expect(root.getAttribute('data-esen-enhanced'), 'true');
    expect(root.querySelectorAll('[role="radio"]').length, 3);
    expect(root.querySelectorAll('[aria-live="polite"]').length, 1);
    expect(_price(root), '€19.00');
    expect(_summary(root), 'Solo · 1 page · no support');
    expect(_status(root), '');
    expect(
      root.querySelectorAll('[data-esen-configurator-choice-region][hidden]'),
      isEmpty,
    );
    expect(
      root
          .querySelector('[data-esen-configurator-option-region]')
          ?.hasAttribute('hidden'),
      isFalse,
    );

    _choice(root, 1).click();
    expect(_price(root), '€49.00');
    _increment(root).click();
    _increment(root).click();
    expect(_price(root), '€63.00');
    _option(root).click();
    expect(_price(root), '€78.00');
    _choice(root, 2).click();
    expect(_price(root), '€124.00');
    _decrement(root).click();
    expect(_price(root), '€119.00');
    expect(_status(root), 'Agency, 2 pages, support included, €119.00');
    expect(
      root.querySelector('#pricing-configurator-choice-2')?.hasAttribute(
            'hidden',
          ),
      isFalse,
    );
    expect(
      root.querySelector('#pricing-configurator-choice-0')?.hasAttribute(
            'hidden',
          ),
      isTrue,
    );
  });

  test('initial activation leaves every content slot and region untouched', () {
    final root = _configurator(fixture);
    final price = _price(root);
    final summary = _summary(root);
    final status = _status(root);
    final regionAttributes = [
      for (final region in _regions(root)) region.outerHTML,
    ];

    enhanceSeoDomFirstConfigurators(
      interactionIds: const {'pricing-configurator'},
      transition: transitionSeoConfigurator,
      project: _pricingView,
    );

    expect(_price(root), price);
    expect(_summary(root), summary);
    expect(_status(root), status);
    expect(
      [for (final region in _regions(root)) region.outerHTML],
      regionAttributes,
    );
  });

  test('unadmitted and tampered components remain complete static HTML', () {
    final container = _container(fixture);
    final unadmitted = _configurator(container, id: 'unadmitted-configurator');
    final mismatched = _configurator(container, id: 'mismatched-configurator');
    mismatched.querySelector('[data-esen-configurator-price]')?.textContent =
        'borrowed value';
    final duplicateStatus =
        _configurator(container, id: 'duplicate-status-configurator');
    duplicateStatus.appendChild(
      web.document.createElement('span')
        ..setAttribute('data-esen-configurator-status', '')
        ..setAttribute('aria-live', 'polite'),
    );
    final duplicateId =
        _configurator(container, id: 'duplicate-id-configurator');
    fixture.appendChild(
      web.document.createElement('div')
        ..id = 'duplicate-id-configurator-option',
    );
    final nestedSlot = _configurator(container, id: 'nested-slot-configurator');
    nestedSlot
        .querySelector('[data-esen-configurator-price]')
        ?.appendChild(web.document.createElement('em'));
    final extraChild = _configurator(container, id: 'extra-child-configurator');
    extraChild.appendChild(web.document.createElement('p'));
    final visibleStatus =
        _configurator(container, id: 'visible-status-configurator');
    visibleStatus
        .querySelector('[data-esen-configurator-status]')
        ?.removeAttribute('class');

    enhanceSeoDomFirstConfigurators(
      interactionIds: const {
        'mismatched-configurator',
        'duplicate-status-configurator',
        'duplicate-id-configurator',
        'nested-slot-configurator',
        'extra-child-configurator',
        'visible-status-configurator',
      },
      transition: transitionSeoConfigurator,
      project: _pricingView,
    );

    for (final root in [
      unadmitted,
      mismatched,
      duplicateStatus,
      duplicateId,
      nestedSlot,
      extraChild,
      visibleStatus,
    ]) {
      expect(root.hasAttribute('data-esen-enhanced'), isFalse);
      expect(root.querySelectorAll('button'), isEmpty);
      expect(root.textContent, contains('Solo details'));
      expect(root.textContent, contains('Agency details'));
    }
  });

  test('invalid admission fails closed before discovery', () {
    final root = _configurator(fixture);

    enhanceSeoDomFirstConfigurators(
      interactionIds: const {'pricing-configurator', 'Invalid ID'},
      transition: transitionSeoConfigurator,
      project: _pricingView,
    );

    expect(root.hasAttribute('data-esen-enhanced'), isFalse);
    expect(root.querySelectorAll('button'), isEmpty);
  });

  test('invalid application output never partially mutates the DOM', () {
    final root = _configurator(fixture);
    var projectCalls = 0;
    SeoConfiguratorView project(SeoConfiguratorState state) {
      projectCalls++;
      if (state.quantity > 1) throw StateError('refuse candidate');
      return _pricingView(state);
    }

    enhanceSeoDomFirstConfigurators(
      interactionIds: const {'pricing-configurator'},
      transition: transitionSeoConfigurator,
      project: project,
    );
    final before = root.outerHTML;
    _increment(root).click();

    expect(projectCalls, 2);
    expect(root.outerHTML, before);
  });

  test('application text is written as text and cannot create markup', () {
    final root = _configurator(fixture);
    const payload = '<img src=x onerror=alert(1)>';

    enhanceSeoDomFirstConfigurators(
      interactionIds: const {'pricing-configurator'},
      transition: transitionSeoConfigurator,
      project: (state) {
        final base = _pricingView(state);
        return SeoConfiguratorView(
          priceText: state.quantity == 1 ? base.priceText : payload,
          summaryText: base.summaryText,
          announcementText: base.announcementText,
          activeChoiceRegion: base.activeChoiceRegion,
          optionRegionVisible: base.optionRegionVisible,
        );
      },
    );
    _increment(root).click();

    expect(_price(root), payload);
    expect(root.querySelectorAll('img'), isEmpty);
    expect(root.querySelectorAll('[onerror]'), isEmpty);
  });

  test('focus returns to the package control when a region is hidden', () {
    final root = _configurator(fixture, includeFocusableContent: true);
    enhanceSeoDomFirstConfigurators(
      interactionIds: const {'pricing-configurator'},
      transition: transitionSeoConfigurator,
      project: _pricingView,
    );
    final link = root.querySelector('#pricing-configurator-choice-0 a')!
        as web.HTMLElement;
    link.focus();
    expect(web.document.activeElement, link);

    final team = _choice(root, 1);
    team.dispatchEvent(
      web.MouseEvent('click', web.MouseEventInit(bubbles: true)),
    );

    expect(web.document.activeElement, team);
    expect(
      root.querySelector('#pricing-configurator-choice-0')?.hasAttribute(
            'hidden',
          ),
      isTrue,
    );
  });

  test('keyboard choice navigation is bounded, roving and repeat-safe', () {
    final root = _configurator(fixture);
    enhanceSeoDomFirstConfigurators(
      interactionIds: const {'pricing-configurator'},
      transition: transitionSeoConfigurator,
      project: _pricingView,
    );
    final first = _choice(root, 0);
    final second = _choice(root, 1);
    final third = _choice(root, 2);

    _keydown(first, 'ArrowRight');
    expect(web.document.activeElement, second);
    expect(second.getAttribute('aria-checked'), 'true');
    _keydown(second, 'End');
    expect(web.document.activeElement, third);
    _keydown(third, 'ArrowRight', repeat: true);
    expect(web.document.activeElement, third);
    _keydown(third, 'ArrowRight');
    expect(web.document.activeElement, first);
  });
}

SeoConfiguratorView _pricingView(SeoConfiguratorState state) {
  const names = ['Solo', 'Team', 'Agency'];
  const base = [1900, 4900, 9900];
  const perPage = [900, 700, 500];
  final cents = base[state.choiceIndex] +
      (state.quantity - 1) * perPage[state.choiceIndex] +
      (state.optionEnabled ? 1500 : 0);
  final price = '€${(cents / 100).toStringAsFixed(2)}';
  final pages = state.quantity == 1 ? '1 page' : '${state.quantity} pages';
  final support = state.optionEnabled ? 'support included' : 'no support';
  return SeoConfiguratorView(
    priceText: price,
    summaryText: '${names[state.choiceIndex]} · $pages · $support',
    announcementText: '${names[state.choiceIndex]}, $pages, $support, $price',
    activeChoiceRegion: state.choiceIndex,
    optionRegionVisible: state.optionEnabled,
  );
}

web.HTMLElement _configurator(
  web.Element parent, {
  String id = 'pricing-configurator',
  bool includeFocusableContent = false,
}) {
  final container =
      parent.id == 'esen-seo-content' ? parent : _container(parent);
  final nodes = buildSeoConfiguratorNodes(
    choices: [
      for (final name in const ['Solo', 'Team', 'Agency'])
        (
          label: name,
          nodes: [
            SeoNode(
              tag: 'p',
              children: [
                SeoNode(tag: 'span', text: '$name details'),
                if (includeFocusableContent && name == 'Solo')
                  SeoNode(
                    tag: 'a',
                    text: 'Read Solo details',
                    attributes: {'href': '#solo'},
                  ),
              ],
            ),
          ],
        ),
    ],
    optionNodes: [SeoNode(tag: 'p', text: 'Priority support details')],
    constraints: _constraints,
    initialState: const SeoConfiguratorState(
      choiceIndex: 0,
      quantity: 1,
      optionEnabled: false,
    ),
    project: _pricingView,
    interactionId: id,
    heading: 'Plan calculator',
    interactionLabel: 'Pricing calculator',
    choiceGroupLabel: 'Plan',
    quantityLabel: 'Pages',
    optionLabel: 'Priority support',
    priceLabel: 'Price',
    decrementLabel: 'Remove page',
    incrementLabel: 'Add page',
  );
  final holder = web.document.createElement('div') as web.HTMLElement;
  holder.setHTMLUnsafe(const HtmlRenderer().render(nodes).toJS);
  final root = holder.firstElementChild! as web.HTMLElement;
  container.appendChild(root);
  return root;
}

web.HTMLElement _container(web.Element parent) {
  final existing = parent.querySelector('#esen-seo-content');
  if (existing != null) return existing as web.HTMLElement;
  final container = web.document.createElement('div') as web.HTMLElement
    ..id = 'esen-seo-content'
    ..setAttribute('data-esen-seo-dom-first', 'true');
  parent.appendChild(container);
  return container;
}

List<web.Element> _regions(web.Element root) => [
      for (final selector in const [
        '[data-esen-configurator-choice-region]',
        '[data-esen-configurator-option-region]',
      ])
        for (var index = 0;
            index < root.querySelectorAll(selector).length;
            index++)
          root.querySelectorAll(selector).item(index)! as web.Element,
    ];

String _price(web.Element root) =>
    root.querySelector('[data-esen-configurator-price]')?.textContent ?? '';

String _summary(web.Element root) =>
    root.querySelector('[data-esen-configurator-summary]')?.textContent ?? '';

String _status(web.Element root) =>
    root.querySelector('[data-esen-configurator-status]')?.textContent ?? '';

web.HTMLElement _choice(web.Element root, int index) => root.querySelector(
      '[data-esen-configurator-choice-control="$index"]',
    )! as web.HTMLElement;

web.HTMLElement _increment(web.Element root) =>
    root.querySelector('[data-esen-configurator-increment]')!
        as web.HTMLElement;

web.HTMLElement _decrement(web.Element root) =>
    root.querySelector('[data-esen-configurator-decrement]')!
        as web.HTMLElement;

web.HTMLElement _option(web.Element root) =>
    root.querySelector('[data-esen-configurator-option-control]')!
        as web.HTMLElement;

void _keydown(
  web.HTMLElement target,
  String key, {
  bool repeat = false,
}) {
  target.dispatchEvent(
    web.KeyboardEvent(
      'keydown',
      web.KeyboardEventInit(
        key: key,
        repeat: repeat,
        bubbles: true,
      ),
    ),
  );
}
