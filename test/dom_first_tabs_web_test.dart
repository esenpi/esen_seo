@TestOn('browser')
library;

import 'package:esen_seo/src/renderer/seo_dom_first_tabs_runtime.g.dart';
import 'package:esen_seo/src/components/seo_tabs_transition.dart';
import 'package:esen_seo/src/renderer/dom_first_tabs_adapter_web.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;

void main() {
  late web.HTMLElement fixture;

  setUp(() {
    fixture = web.document.createElement('div') as web.HTMLElement;
    fixture.id = 'dom-first-fixture';
    web.document.body?.appendChild(fixture);
  });

  tearDown(() => fixture.remove());

  test('compiled tabs use the shared transition for pointer and keyboard', () {
    final container = _container(fixture);
    final root = _tabs(container, 'compiled-tabs', initialIndex: 1);

    expect(root.textContent, contains('Overview content'));
    expect(root.textContent, contains('Details content'));
    expect(root.querySelectorAll('button').length, 0);
    _runCompiledCandidate();

    final tabs = root.querySelectorAll('[role="tab"]');
    final panels = root.querySelectorAll('[role="tabpanel"]');
    final firstTab = tabs.item(0)! as web.HTMLElement;
    final secondTab = tabs.item(1)! as web.HTMLElement;
    final firstPanel = panels.item(0)! as web.HTMLElement;
    final secondPanel = panels.item(1)! as web.HTMLElement;

    expect(tabs.length, 2);
    expect(secondTab.getAttribute('aria-selected'), 'true');
    expect(firstPanel.hasAttribute('hidden'), isTrue);
    expect(secondPanel.hasAttribute('hidden'), isFalse);
    expect(root.querySelectorAll('h3[hidden]').length, 2);

    firstTab.dispatchEvent(
      web.MouseEvent('click', web.MouseEventInit(bubbles: true)),
    );
    expect(firstTab.getAttribute('aria-selected'), 'true');
    expect(firstPanel.hasAttribute('hidden'), isFalse);
    expect(secondPanel.hasAttribute('hidden'), isTrue);

    _keydown(firstTab, 'ArrowLeft');
    expect(secondTab.getAttribute('aria-selected'), 'true');
    expect(web.document.activeElement?.id, 'compiled-tabs-tab-1');
    _keydown(secondTab, 'ArrowRight');
    expect(firstTab.getAttribute('aria-selected'), 'true');
    _keydown(firstTab, 'End');
    expect(secondTab.getAttribute('aria-selected'), 'true');
    _keydown(secondTab, 'Home');
    expect(firstTab.getAttribute('aria-selected'), 'true');

    _runCompiledCandidate();
    expect(root.querySelectorAll('[role="tablist"]').length, 1);
    expect(root.querySelectorAll('[role="tab"]').length, 2);
  });

  test('invalid or ambiguous controls remain entirely unmodified', () {
    final container = _container(fixture);
    final duplicateA = _tabs(container, 'duplicate-tabs');
    final duplicateB = _tabs(container, 'duplicate-tabs');
    final collision = _tabs(container, 'collision-tabs');
    container.appendChild(
      web.document.createElement('div')..id = 'collision-tabs-tab-0',
    );
    final wrongPanel = _tabs(container, 'wrong-panel');
    wrongPanel.children.item(0)?.id = 'borrowed-panel-id';
    final emptyHeading = _tabs(container, 'empty-heading');
    emptyHeading.querySelector('h3')?.textContent = '   ';
    final malformedIndex = _tabs(container, 'malformed-index');
    malformedIndex.setAttribute('data-esen-initial-index', '01');
    final unexpectedChild = _tabs(container, 'unexpected-child');
    unexpectedChild.appendChild(web.document.createElement('div'));
    final invalidId = _tabs(container, 'valid-before-change');
    invalidId.id = 'starts with space';
    final inertParent = web.document.createElement('div')
      ..setAttribute('inert', '');
    container.appendChild(inertParent);
    final inertRoot = _tabs(inertParent, 'inert-tabs');
    final hiddenParent = web.document.createElement('div')
      ..setAttribute('hidden', '');
    container.appendChild(hiddenParent);
    final hiddenRoot = _tabs(hiddenParent, 'hidden-tabs');
    final ariaHiddenParent = web.document.createElement('div')
      ..setAttribute('aria-hidden', ' TRUE ');
    container.appendChild(ariaHiddenParent);
    final ariaHiddenRoot = _tabs(ariaHiddenParent, 'aria-hidden-tabs');

    _runCompiledCandidate();

    for (final root in [
      duplicateA,
      duplicateB,
      collision,
      wrongPanel,
      emptyHeading,
      malformedIndex,
      unexpectedChild,
      invalidId,
      inertRoot,
      ariaHiddenRoot,
    ]) {
      expect(root.querySelectorAll('button').length, 0);
      expect(root.querySelectorAll('[hidden]').length, 0);
      expect(root.querySelectorAll('[role]').length, 0);
      expect(root.hasAttribute('data-esen-enhanced'), isFalse);
      expect(root.textContent, contains('Overview content'));
      expect(root.textContent, contains('Details content'));
    }
    expect(hiddenParent.hasAttribute('hidden'), isTrue);
    expect(hiddenRoot.querySelectorAll('[role="tab"]').length, 2);
    expect(hiddenRoot.hasAttribute('data-esen-enhanced'), isTrue);
  });

  test('requires one unambiguous package-owned DOM-first container', () {
    final first = _container(fixture);
    final root = _tabs(first, 'container-tabs');
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
    final root = _tabs(container, 'text-tabs');
    root.querySelector('h3')?.textContent = '<img src=x onerror=alert(1)>';

    _runCompiledCandidate();

    final tab = root.querySelector('[role="tab"]')! as web.HTMLElement;
    expect(tab.textContent, '<img src=x onerror=alert(1)>');
    expect(tab.querySelectorAll('img').length, 0);
    expect(root.querySelectorAll('[onerror]').length, 0);
  });

  test('blank group labels retain a usable accessible name', () {
    final container = _container(fixture);
    final root = _tabs(container, 'blank-label-tabs');
    root.setAttribute('data-esen-label', '   ');

    _runCompiledCandidate();

    expect(
      root.querySelector('[role="tablist"]')?.getAttribute('aria-label'),
      'Tabs',
    );
  });

  test('adapter executes an application transition instead of the default', () {
    final container = _container(fixture);
    final root = _tabs(container, 'application-tabs', initialIndex: 1);

    SeoTabsState doNotWrap(SeoTabsState state, SeoTabsAction action) {
      if (action is SeoTabsNext && state.index == state.count - 1) return state;
      if (action is SeoTabsPrevious && state.index == 0) return state;
      return transitionSeoTabs(state, action);
    }

    enhanceSeoDomFirstTabs(transition: doNotWrap);
    final tabs = root.querySelectorAll('[role="tab"]');
    final first = tabs.item(0)! as web.HTMLElement;
    final last = tabs.item(1)! as web.HTMLElement;

    _keydown(last, 'ArrowRight');
    expect(last.getAttribute('aria-selected'), 'true');
    expect(first.getAttribute('aria-selected'), 'false');

    first.dispatchEvent(
      web.MouseEvent('click', web.MouseEventInit(bubbles: true)),
    );
    _keydown(first, 'ArrowLeft');
    expect(first.getAttribute('aria-selected'), 'true');
    expect(last.getAttribute('aria-selected'), 'false');
  });
}

web.HTMLElement _container(web.HTMLElement fixture) {
  final container = web.document.createElement('div') as web.HTMLElement
    ..id = 'esen-seo-content'
    ..setAttribute('data-esen-seo-dom-first', 'true');
  fixture.appendChild(container);
  return container;
}

web.HTMLElement _tabs(
  web.Element parent,
  String id, {
  int initialIndex = 0,
}) {
  final root = web.document.createElement('div') as web.HTMLElement
    ..id = id
    ..className = 'esen-seo-tabs'
    ..setAttribute('data-esen-component', 'tabs')
    ..setAttribute('data-esen-label', 'Product information')
    ..setAttribute('data-esen-initial-index', '$initialIndex');
  for (var index = 0; index < 2; index++) {
    final section = web.document.createElement('section') as web.HTMLElement
      ..id = '$id-panel-$index'
      ..setAttribute('data-esen-tab-panel', '');
    section.appendChild(
      web.document.createElement('h3')
        ..textContent = index == 0 ? 'Overview' : 'Details',
    );
    section.appendChild(
      web.document.createElement('p')
        ..textContent = index == 0 ? 'Overview content' : 'Details content',
    );
    root.appendChild(section);
  }
  parent.appendChild(root);
  return root;
}

void _runCompiledCandidate() {
  final script = web.document.createElement('script')
    ..textContent = seoDomFirstTabsRuntime;
  web.document.body?.appendChild(script);
  script.remove();
}

void _keydown(web.Element element, String key) {
  element.dispatchEvent(
    web.KeyboardEvent(
      'keydown',
      web.KeyboardEventInit(key: key, bubbles: true),
    ),
  );
}
