@TestOn('browser')
library;

import 'package:esen_seo/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;

void main() {
  late web.Element fixture;

  setUp(() {
    fixture = web.document.createElement('div')..id = 'interaction-fixture';
    web.document.body?.appendChild(fixture);
  });

  tearDown(() {
    fixture.remove();
  });

  test('tabs progressively enhance with pointer and keyboard controls', () {
    final shell = web.document.createElement('div')
      ..id = 'esen-seo-content'
      ..setAttribute('data-esen-seo-shell', 'visible');
    fixture.appendChild(shell);
    final root = _appendTabs(shell, 'browser-tabs');
    final inert = web.document.createElement('div')..setAttribute('inert', '');
    shell.appendChild(inert);
    final inertRoot = _appendTabs(inert, 'inert-tabs');
    final duplicateA = _appendTabs(shell, 'duplicate-tabs');
    final duplicateB = _appendTabs(shell, 'duplicate-tabs');
    final collisionRoot = _appendTabs(shell, 'collision-tabs');
    shell.appendChild(
        web.document.createElement('div')..id = 'collision-tabs-tab-0');
    final emptyLabelRoot = _appendTabs(shell, 'empty-label-tabs');
    emptyLabelRoot.querySelector('h3')?.textContent = '   ';
    final unexpectedChildRoot = _appendTabs(shell, 'unexpected-child-tabs');
    unexpectedChildRoot.appendChild(web.document.createElement('div'));
    final outsideRoot = _appendTabs(fixture, 'outside-tabs');

    expect(root.querySelectorAll('button').length, 0);
    expect(root.querySelectorAll('[hidden]').length, 0);
    expect(root.textContent, contains('Overview content'));
    expect(root.textContent, contains('Details content'));

    final script = web.document.createElement('script')
      ..textContent = seoInteractionRuntime;
    web.document.body?.appendChild(script);

    final tabs = root.querySelectorAll('[role="tab"]');
    final panels = root.querySelectorAll('[role="tabpanel"]');
    final firstTab = tabs.item(0)! as web.Element;
    final secondTab = tabs.item(1)! as web.Element;
    final firstPanel = panels.item(0)! as web.Element;
    final secondPanel = panels.item(1)! as web.Element;
    expect(tabs.length, 2);
    expect(panels.length, 2);
    expect(firstTab.getAttribute('aria-selected'), 'true');
    expect(firstTab.getAttribute('tabindex'), '0');
    expect(secondTab.getAttribute('tabindex'), '-1');
    expect(firstPanel.hasAttribute('hidden'), isFalse);
    expect(secondPanel.hasAttribute('hidden'), isTrue);
    expect(root.querySelectorAll('h3[hidden]').length, 2);

    secondTab.dispatchEvent(
      web.MouseEvent('click', web.MouseEventInit(bubbles: true)),
    );
    expect(secondTab.getAttribute('aria-selected'), 'true');
    expect(firstPanel.hasAttribute('hidden'), isTrue);
    expect(secondPanel.hasAttribute('hidden'), isFalse);

    _keydown(secondTab, 'ArrowRight');
    expect(firstTab.getAttribute('aria-selected'), 'true');
    expect(web.document.activeElement?.id, 'browser-tabs-tab-0');

    _keydown(firstTab, 'End');
    expect(secondTab.getAttribute('aria-selected'), 'true');
    _keydown(secondTab, 'Home');
    expect(firstTab.getAttribute('aria-selected'), 'true');
    _keydown(firstTab, 'ArrowLeft');
    expect(secondTab.getAttribute('aria-selected'), 'true');

    expect(inertRoot.querySelectorAll('button').length, 0);
    expect(duplicateA.querySelectorAll('button').length, 0);
    expect(duplicateB.querySelectorAll('button').length, 0);
    expect(collisionRoot.querySelectorAll('button').length, 0);
    expect(emptyLabelRoot.querySelectorAll('button').length, 0);
    expect(unexpectedChildRoot.querySelectorAll('button').length, 0);
    expect(outsideRoot.querySelectorAll('button').length, 0);
    script.remove();
  });
}

void _keydown(web.Element element, String key) {
  element.dispatchEvent(
    web.KeyboardEvent(
      'keydown',
      web.KeyboardEventInit(key: key),
    ),
  );
}

web.Element _appendTabs(web.Element parent, String id) {
  final root = web.document.createElement('div')
    ..id = id
    ..setAttribute('data-esen-component', 'tabs')
    ..setAttribute('data-esen-label', 'Product information')
    ..setAttribute('data-esen-initial-index', '0');
  for (var index = 0; index < 2; index += 1) {
    final panel = web.document.createElement('section')
      ..id = '$id-panel-$index'
      ..setAttribute('data-esen-tab-panel', '');
    panel.appendChild(web.document.createElement('h3')
      ..textContent = index == 0 ? 'Overview' : 'Details');
    panel.appendChild(web.document.createElement('p')
      ..textContent = index == 0 ? 'Overview content' : 'Details content');
    root.appendChild(panel);
  }
  parent.appendChild(root);
  return root;
}
