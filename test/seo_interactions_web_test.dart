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

  test('nav progressively enhances disclosures and preserves links', () {
    final shell = web.document.createElement('div')
      ..id = 'esen-seo-content'
      ..setAttribute('data-esen-seo-shell', 'visible');
    fixture.appendChild(shell);
    final root = _appendNav(shell, 'primary-nav');

    final malformed = _appendNav(shell, 'malformed-nav');
    malformed
        .querySelector('[data-esen-nav-branch]')
        ?.appendChild(web.document.createElement('div'));
    final duplicate = _appendNav(shell, 'duplicate-nav');
    shell.appendChild(
      web.document.createElement('div')..id = 'duplicate-nav-submenu-0',
    );
    final emptyLabel = _appendNav(shell, 'empty-label-nav');
    emptyLabel.querySelector('a')?.textContent = '   ';
    final outside = _appendNav(fixture, 'outside-nav');

    expect(root.querySelectorAll('button').length, 0);
    expect(root.querySelectorAll('[hidden]').length, 0);
    expect(root.querySelectorAll('a').length, 3);

    final script = web.document.createElement('script')
      ..textContent = seoInteractionRuntime;
    web.document.body?.appendChild(script);

    final toggles = root.querySelectorAll('[data-esen-nav-toggle]');
    final submenus = root.querySelectorAll('[data-esen-nav-submenu]');
    final productToggle = toggles.item(0)! as web.Element;
    final moreToggle = toggles.item(1)! as web.Element;
    final productSubmenu = submenus.item(0)! as web.Element;
    final moreSubmenu = submenus.item(1)! as web.Element;
    final productLink = root.querySelector('a[href="/products"]')!;
    final deepLink = root.querySelector('a[href="/consulting"]')!;

    expect(toggles.length, 2);
    expect(productLink.textContent, 'Products');
    expect(productLink.getAttribute('href'), '/products');
    expect(productToggle.getAttribute('aria-label'), 'Products');
    expect(productToggle.getAttribute('aria-expanded'), 'false');
    expect(
      productToggle.getAttribute('aria-controls'),
      productSubmenu.id,
    );
    expect(productSubmenu.hasAttribute('hidden'), isTrue);
    expect(moreSubmenu.hasAttribute('hidden'), isTrue);
    expect(root.querySelector('span[hidden]')?.textContent, 'More');
    expect(moreToggle.textContent, contains('More'));

    productToggle.dispatchEvent(
      web.MouseEvent('click', web.MouseEventInit(bubbles: true)),
    );
    expect(productToggle.getAttribute('aria-expanded'), 'true');
    expect(productSubmenu.hasAttribute('hidden'), isFalse);

    productToggle.dispatchEvent(
      web.KeyboardEvent(
        'keydown',
        web.KeyboardEventInit(key: 'Enter', bubbles: true),
      ),
    );
    expect(productToggle.getAttribute('aria-expanded'), 'false');
    productToggle.dispatchEvent(
      web.KeyboardEvent(
        'keydown',
        web.KeyboardEventInit(key: ' ', bubbles: true),
      ),
    );
    expect(productToggle.getAttribute('aria-expanded'), 'true');
    productToggle.dispatchEvent(
      web.KeyboardEvent(
        'keydown',
        web.KeyboardEventInit(key: ' ', repeat: true, bubbles: true),
      ),
    );
    expect(productToggle.getAttribute('aria-expanded'), 'true');

    moreToggle.dispatchEvent(
      web.MouseEvent('click', web.MouseEventInit(bubbles: true)),
    );
    expect(moreToggle.getAttribute('aria-expanded'), 'true');
    expect(moreSubmenu.hasAttribute('hidden'), isFalse);

    moreToggle.dispatchEvent(
      web.KeyboardEvent(
        'keydown',
        web.KeyboardEventInit(key: 'Escape', bubbles: true),
      ),
    );
    expect(moreToggle.getAttribute('aria-expanded'), 'false');
    expect(moreSubmenu.hasAttribute('hidden'), isTrue);
    expect(web.document.activeElement?.id, moreToggle.id);

    moreToggle.dispatchEvent(
      web.MouseEvent('click', web.MouseEventInit(bubbles: true)),
    );

    deepLink.dispatchEvent(
      web.KeyboardEvent(
        'keydown',
        web.KeyboardEventInit(key: 'Escape', bubbles: true),
      ),
    );
    expect(moreToggle.getAttribute('aria-expanded'), 'false');
    expect(moreSubmenu.hasAttribute('hidden'), isTrue);
    expect(web.document.activeElement?.id, moreToggle.id);
    expect(productToggle.getAttribute('aria-expanded'), 'true');

    expect(malformed.querySelectorAll('button').length, 0);
    expect(duplicate.querySelectorAll('button').length, 0);
    expect(emptyLabel.querySelectorAll('button').length, 0);
    expect(outside.querySelectorAll('button').length, 0);
    script.remove();
  });

  test('carousel enhances complete slides and rejects malformed roots', () {
    final shell = web.document.createElement('div')
      ..id = 'esen-seo-content'
      ..setAttribute('data-esen-seo-shell', 'visible');
    fixture.appendChild(shell);
    final root = _appendCarousel(shell, 'product-carousel');

    final malformed = _appendCarousel(shell, 'malformed-carousel');
    malformed.appendChild(web.document.createElement('div'));
    final duplicate = _appendCarousel(shell, 'duplicate-carousel');
    shell.appendChild(
      web.document.createElement('div')..id = 'duplicate-carousel-slide-0',
    );
    final emptyHeading = _appendCarousel(shell, 'empty-heading-carousel');
    emptyHeading.querySelector('h3')?.textContent = '   ';
    final emptyControl = _appendCarousel(shell, 'empty-control-carousel');
    emptyControl.setAttribute('data-esen-next-label', '   ');
    final invalidInitial = _appendCarousel(shell, 'invalid-initial-carousel');
    invalidInitial.setAttribute('data-esen-initial-index', '1oops');
    final collision = _appendCarousel(shell, 'collision-carousel');
    shell.appendChild(
      web.document.createElement('div')..id = 'collision-carousel-previous',
    );
    final single = _appendCarousel(shell, 'single-carousel', count: 1);
    final outside = _appendCarousel(fixture, 'outside-carousel');
    final rtl = _appendCarousel(shell, 'rtl-carousel')
      ..setAttribute('dir', 'rtl');

    expect(root.querySelectorAll('button').length, 0);
    expect(root.querySelectorAll('[hidden]').length, 0);
    expect(root.querySelectorAll('a').length, 3);
    expect(root.textContent, contains('Slide 1 content'));
    expect(root.textContent, contains('Slide 3 content'));

    final script = web.document.createElement('script')
      ..textContent = seoInteractionRuntime;
    web.document.body?.appendChild(script);

    final slides = root.querySelectorAll('[data-esen-carousel-slide]');
    final controls = root.querySelectorAll('[data-esen-carousel-control]');
    final previous = controls.item(0)! as web.Element;
    final next = controls.item(1)! as web.Element;
    final status = root.querySelector('[data-esen-carousel-status]')!;

    expect(root.getAttribute('role'), 'region');
    expect(root.getAttribute('aria-label'), 'Product carousel');
    expect(controls.length, 2);
    expect(previous.getAttribute('aria-label'), 'Previous slide');
    expect(next.getAttribute('aria-label'), 'Next slide');
    expect(status.getAttribute('aria-live'), 'polite');
    expect(status.textContent, '2 / 3');
    expect((slides.item(0)! as web.Element).hasAttribute('hidden'), isTrue);
    expect((slides.item(1)! as web.Element).hasAttribute('hidden'), isFalse);
    expect((slides.item(2)! as web.Element).hasAttribute('hidden'), isTrue);
    expect(root.querySelector('a[href="/slide/2"]')?.textContent, 'Slide 3');

    next.dispatchEvent(
      web.MouseEvent('click', web.MouseEventInit(bubbles: true)),
    );
    expect(status.textContent, '3 / 3');
    expect(next.getAttribute('aria-disabled'), 'true');
    next.dispatchEvent(
      web.MouseEvent('click', web.MouseEventInit(bubbles: true)),
    );
    expect(status.textContent, '3 / 3');

    _keydown(next, 'Home');
    expect(status.textContent, '1 / 3');
    _keydown(next, 'ArrowRight');
    expect(status.textContent, '2 / 3');
    _keydown(next, ' ');
    expect(status.textContent, '3 / 3');
    next.dispatchEvent(
      web.KeyboardEvent(
        'keydown',
        web.KeyboardEventInit(key: ' ', repeat: true, bubbles: true),
      ),
    );
    expect(status.textContent, '3 / 3');
    _keydown(next, 'ArrowLeft');
    expect(status.textContent, '2 / 3');

    final rtlControls = rtl.querySelectorAll('[data-esen-carousel-control]');
    final rtlPrevious = rtlControls.item(0)! as web.Element;
    final rtlNext = rtlControls.item(1)! as web.Element;
    final rtlStatus = rtl.querySelector('[data-esen-carousel-status]')!;
    expect(rtlPrevious.textContent, '\u203a');
    expect(rtlNext.textContent, '\u2039');
    _keydown(rtlNext, 'ArrowLeft');
    expect(rtlStatus.textContent, '3 / 3');

    for (final rejected in [
      malformed,
      duplicate,
      emptyHeading,
      emptyControl,
      invalidInitial,
      collision,
      single,
      outside,
    ]) {
      expect(rejected.querySelectorAll('button').length, 0);
      expect(rejected.querySelectorAll('[hidden]').length, 0);
    }
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

web.Element _appendCarousel(
  web.Element parent,
  String id, {
  int count = 3,
  int initialIndex = 1,
}) {
  final root = web.document.createElement('div')
    ..id = id
    ..setAttribute('data-esen-component', 'carousel')
    ..setAttribute('data-esen-label', 'Product carousel')
    ..setAttribute('data-esen-previous-label', 'Previous slide')
    ..setAttribute('data-esen-next-label', 'Next slide')
    ..setAttribute('data-esen-initial-index', '$initialIndex');
  for (var index = 0; index < count; index += 1) {
    final slide = web.document.createElement('section')
      ..id = '$id-slide-$index'
      ..setAttribute('data-esen-carousel-slide', '');
    slide.appendChild(
      web.document.createElement('h3')..textContent = 'Slide ${index + 1}',
    );
    slide.appendChild(web.document.createElement('p')
      ..textContent = 'Slide ${index + 1} content');
    slide.appendChild(web.document.createElement('a')
      ..setAttribute('href', '/slide/$index')
      ..textContent = 'Slide ${index + 1}');
    root.appendChild(slide);
  }
  parent.appendChild(root);
  return root;
}

web.Element _appendNav(web.Element parent, String id) {
  final root = web.document.createElement('nav')
    ..id = id
    ..setAttribute('data-esen-component', 'nav-menu')
    ..setAttribute('aria-label', 'Primary navigation');
  final rootList = web.document.createElement('ul')
    ..setAttribute('data-esen-nav-root-list', '');
  final products = web.document.createElement('li')
    ..setAttribute('data-esen-nav-branch', '');
  products.appendChild(web.document.createElement('a')
    ..setAttribute('href', '/products')
    ..textContent = 'Products');

  final productSubmenu = web.document.createElement('ul')
    ..id = '$id-submenu-0'
    ..setAttribute('data-esen-nav-submenu', '');
  final apps = web.document.createElement('li');
  apps.appendChild(web.document.createElement('a')
    ..setAttribute('href', '/apps')
    ..textContent = 'Apps');
  productSubmenu.appendChild(apps);

  final more = web.document.createElement('li')
    ..setAttribute('data-esen-nav-branch', '');
  more.appendChild(web.document.createElement('span')..textContent = 'More');
  final moreSubmenu = web.document.createElement('ul')
    ..id = '$id-submenu-0-1'
    ..setAttribute('data-esen-nav-submenu', '');
  final consulting = web.document.createElement('li');
  consulting.appendChild(web.document.createElement('a')
    ..setAttribute('href', '/consulting')
    ..textContent = 'Consulting');
  moreSubmenu.appendChild(consulting);
  more.appendChild(moreSubmenu);
  productSubmenu.appendChild(more);

  products.appendChild(productSubmenu);
  rootList.appendChild(products);
  root.appendChild(rootList);
  parent.appendChild(root);
  return root;
}
