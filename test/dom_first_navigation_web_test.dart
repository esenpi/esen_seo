@TestOn('browser')
library;

import 'dart:convert';
import 'dart:js_interop';

import 'package:esen_seo/src/renderer/seo_dom_first_navigation_runtime.g.dart';
import 'package:esen_seo/src/renderer/seo_dom_first_tabs_carousel_runtime.g.dart';
import 'package:esen_seo/src/renderer/seo_dom_first_theme_toggle_runtime.g.dart';
import 'package:esen_seo/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;

const _profile = 'carousel.navigation.tabs.themeToggle';

void main() {
  test('navigates compatible documents and leaves other links native',
      () async {
    _removeAll('title');
    _removeAll('[$seoDomFirstNavigationHeadAttribute]');
    _removeAll('script[$seoDomFirstNavigationManifestAttribute]');
    _removeAll('script[data-esen-seo-dom-first-runtime]');
    _removeAll('#esen-seo-content');

    final originalHref = web.window.location.href;
    addTearDown(
      () => web.window.history.replaceState(null, '', originalHref),
    );
    web.window.history.replaceState(null, '', '/repo%252Fname/');
    final initialSearch = web.window.location.search;
    final manifest = jsonEncode({
      'schema': seoDomFirstNavigationManifestSchema,
      'base': '/repo%2Fname',
      'profile': _profile,
      'routes': [
        ['/', _profile],
        ['/incompatible', null],
        ['/:page', _profile],
      ],
    });
    final initialDocument = _document(
      title: 'Initial page',
      description: 'Initial description',
      body: _body(
        'Initial page',
        '?esen-nav-target=1#target-carousel-slide-2',
        tabsId: 'initial-tabs',
        initialTab: 0,
        carouselId: 'initial-carousel',
        initialSlide: 0,
      ),
      manifest: manifest,
    );
    final targetDocument = _document(
      title: 'Target page',
      description: 'Target description',
      body: _body(
        'Target page',
        '?esen-nav-second=1',
        tabsId: 'target-tabs',
        initialTab: 1,
        carouselId: 'target-carousel',
        initialSlide: 1,
      ),
      manifest: manifest,
    );

    final title = web.document.createElement('title')
      ..setAttribute(seoDomFirstNavigationHeadAttribute, '')
      ..textContent = 'Initial page';
    final description = web.document.createElement('meta')
      ..setAttribute(seoDomFirstNavigationHeadAttribute, '')
      ..setAttribute('name', 'description')
      ..setAttribute('content', 'Initial description');
    final manifestNode = web.document.createElement('script')
      ..setAttribute('type', 'application/json')
      ..setAttribute(seoDomFirstNavigationManifestAttribute, '')
      ..setAttribute('data-esen-navigation-profile', _profile)
      ..textContent = manifest;
    web.document.head
      ?..appendChild(title)
      ..appendChild(description)
      ..appendChild(manifestNode);

    final initial = _content(
      'Initial page',
      '?esen-nav-target=1#target-carousel-slide-2',
      tabsId: 'initial-tabs',
      initialTab: 0,
      carouselId: 'initial-carousel',
      initialSlide: 0,
    );
    web.document.body?.appendChild(initial);
    _mockFetch(initialDocument, targetDocument);

    final runtime = web.document.createElement('script')
      ..setAttribute('data-esen-seo-dom-first-runtime', '')
      ..textContent = '$seoDomFirstNavigationRuntime;'
          '$seoDomFirstTabsCarouselRuntime;'
          '$seoDomFirstThemeToggleRuntime';
    web.document.body?.appendChild(runtime);

    final firstToggle = initial.querySelector(
      '[data-esen-component="theme-toggle"]',
    )!;
    expect(firstToggle.querySelectorAll('button').length, 1);
    expect(initial.querySelectorAll('[role="tablist"]').length, 1);
    expect(
      initial.querySelector('[data-esen-carousel-status]')?.textContent,
      '1 / 3',
    );
    expect(
      (initial.querySelectorAll('[role="tab"]').item(0)! as web.Element)
          .getAttribute(
        'aria-selected',
      ),
      'true',
    );

    final link = initial.querySelector('a')! as web.HTMLElement;
    final click = web.MouseEvent(
      'click',
      web.MouseEventInit(bubbles: true, cancelable: true),
    );
    link.dispatchEvent(click);
    await _waitFor(
      () =>
          web.window.location.search == '?esen-nav-target=1' &&
          web.document.title == 'Target page',
    );

    expect(click.defaultPrevented, isTrue);
    expect(web.window.location.search, '?esen-nav-target=1');
    expect(web.document.title, 'Target page');
    expect(
      web.document
          .querySelector('meta[name="description"]')
          ?.getAttribute('content'),
      'Target description',
    );
    expect(initial.isConnected, isFalse);
    final target = web.document.querySelector('#esen-seo-content')!;
    expect(target.textContent, contains('Target page'));
    expect(target.getAttribute('aria-busy'), isNull);
    expect(
      target
          .querySelector('[data-esen-component="theme-toggle"]')
          ?.querySelectorAll('button')
          .length,
      1,
    );
    expect(target.querySelectorAll('[role="tablist"]').length, 1);
    expect(target.querySelectorAll('[role="tab"]').length, 2);
    expect(
      (target.querySelectorAll('[role="tab"]').item(1)! as web.Element)
          .getAttribute(
        'aria-selected',
      ),
      'true',
    );
    expect(
      target.querySelectorAll('[data-esen-carousel-controls]').length,
      1,
    );
    expect(
      target.querySelector('[data-esen-carousel-status]')?.textContent,
      '3 / 3',
    );
    expect(
      (target.querySelectorAll('[data-esen-carousel-slide]').item(2)!
              as web.Element)
          .hasAttribute('hidden'),
      isFalse,
    );
    (target.querySelectorAll('[role="tab"]').item(0)! as web.HTMLElement)
        .click();
    expect(
      (target.querySelectorAll('[role="tab"]').item(0)! as web.Element)
          .getAttribute(
        'aria-selected',
      ),
      'true',
    );
    expect(web.document.activeElement?.textContent, contains('Target page'));
    expect(
      web.document.documentElement?.getAttribute('data-mock-fetch-count'),
      '1',
    );
    expect(
      web.document.documentElement?.getAttribute('data-mock-fetch-accept'),
      'text/html',
    );
    expect(
      web.document.documentElement?.getAttribute('data-mock-fetch-credentials'),
      'same-origin',
    );

    final incompatible = web.document.createElement('a')
      ..setAttribute('href', '/repo%252Fname/incompatible')
      ..textContent = 'Incompatible';
    target.appendChild(incompatible);
    expect(_dispatchWithoutNavigation(incompatible), isFalse);

    final external = web.document.createElement('a')
      ..setAttribute('href', 'https://example.invalid/')
      ..textContent = 'External';
    target.appendChild(external);
    expect(_dispatchWithoutNavigation(external), isFalse);

    final asset = web.document.createElement('a')
      ..setAttribute('href', '/repo%252Fname/manual.pdf')
      ..textContent = 'PDF';
    target.appendChild(asset);
    expect(_dispatchWithoutNavigation(asset), isFalse);

    final modified = web.document.createElement('a')
      ..setAttribute('href', '?esen-nav-modified=1')
      ..textContent = 'Modified';
    target.appendChild(modified);
    expect(_dispatchWithoutNavigation(modified, control: true), isFalse);
    expect(
      web.document.documentElement?.getAttribute('data-mock-fetch-count'),
      '1',
    );

    web.window.history.back();
    await _waitFor(
      () =>
          web.window.location.search == initialSearch &&
          web.document.title == 'Initial page',
    );

    expect(web.window.location.search, initialSearch);
    expect(web.document.title, 'Initial page');
    expect(
      web.document.querySelector('#esen-seo-content')?.textContent,
      contains('Initial page'),
    );
    final restored = web.document.querySelector('#esen-seo-content')!;
    expect(restored.querySelectorAll('[role="tablist"]').length, 1);
    expect(restored.querySelectorAll('[role="tab"]').length, 2);
    expect(
      (restored.querySelectorAll('[role="tab"]').item(0)! as web.Element)
          .getAttribute(
        'aria-selected',
      ),
      'true',
    );
    expect(
      restored.querySelectorAll('[data-esen-carousel-controls]').length,
      1,
    );
    expect(
      restored.querySelector('[data-esen-carousel-status]')?.textContent,
      '1 / 3',
    );
    expect(
      web.document.documentElement?.getAttribute('data-mock-fetch-count'),
      '2',
    );

    runtime.remove();
    _removeAll('#esen-seo-content');
    _removeAll('[$seoDomFirstNavigationHeadAttribute]');
    _removeAll('script[$seoDomFirstNavigationManifestAttribute]');
    final malformedTitle = web.document.createElement('title')
      ..setAttribute(seoDomFirstNavigationHeadAttribute, '')
      ..textContent = 'Malformed';
    final malformedManifest = web.document.createElement('script')
      ..setAttribute('type', 'application/json')
      ..setAttribute(seoDomFirstNavigationManifestAttribute, '')
      ..setAttribute('data-esen-navigation-profile', _profile)
      ..textContent = manifest;
    web.document.head
      ?..appendChild(malformedTitle)
      ..appendChild(malformedManifest);
    final malformedContent = web.document.createElement('div')
      ..id = 'esen-seo-content'
      ..setAttribute('data-esen-seo-dom-first', 'true');
    final malformedMain = web.document.createElement('main');
    final malformedLink = web.document.createElement('a')
      ..setAttribute('href', '?esen-nav-rejected=1')
      ..textContent = 'Rejected';
    malformedMain
      ..appendChild(web.document.createElement('script'))
      ..appendChild(malformedLink);
    malformedContent.appendChild(malformedMain);
    web.document.body?.appendChild(malformedContent);
    final rejectedRuntime = web.document.createElement('script')
      ..setAttribute('data-esen-seo-dom-first-runtime', '')
      ..textContent = seoDomFirstNavigationRuntime;
    web.document.body?.appendChild(rejectedRuntime);

    expect(_dispatchWithoutNavigation(malformedLink), isFalse);
    expect(
      web.document.documentElement?.getAttribute('data-mock-fetch-count'),
      '2',
    );

    _runJavaScript(
      'globalThis.fetch=globalThis.__esenOriginalFetch;'
      'delete globalThis.__esenOriginalFetch',
    );
    rejectedRuntime.remove();
    _removeAll('#esen-seo-content');
    _removeAll('[$seoDomFirstNavigationHeadAttribute]');
    _removeAll('script[$seoDomFirstNavigationManifestAttribute]');
    web.document.documentElement?.removeAttribute('data-mock-fetch-count');
    web.document.documentElement?.removeAttribute('data-mock-fetch-accept');
    web.document.documentElement
        ?.removeAttribute('data-mock-fetch-credentials');
  });
}

web.HTMLElement _content(
  String heading,
  String href, {
  required String tabsId,
  required int initialTab,
  required String carouselId,
  required int initialSlide,
}) {
  final holder = web.document.createElement('div');
  holder.setHTMLUnsafe(
    _body(
      heading,
      href,
      tabsId: tabsId,
      initialTab: initialTab,
      carouselId: carouselId,
      initialSlide: initialSlide,
    ).toJS,
  );
  return holder.firstElementChild! as web.HTMLElement;
}

String _body(
  String heading,
  String href, {
  required String tabsId,
  required int initialTab,
  required String carouselId,
  required int initialSlide,
}) =>
    '<div id="esen-seo-content" data-esen-seo-dom-first="true">'
    '<main><h1>$heading</h1><a href="$href">Continue</a>'
    '${_tabs(tabsId, initialTab)}${_carousel(carouselId, initialSlide)}'
    '${_themeToggle()}</main></div>';

String _tabs(String id, int initialIndex) =>
    '<div id="$id" data-esen-component="tabs" '
    'data-esen-label="Page sections" '
    'data-esen-initial-index="$initialIndex">'
    '<section id="$id-panel-0" data-esen-tab-panel>'
    '<h2>Overview</h2><p>Overview content</p></section>'
    '<section id="$id-panel-1" data-esen-tab-panel>'
    '<h2>Details</h2><p>Details content</p></section></div>';

String _carousel(String id, int initialIndex) =>
    '<div id="$id" class="esen-seo-carousel" '
    'data-esen-component="carousel" data-esen-label="Page highlights" '
    'data-esen-previous-label="Previous slide" '
    'data-esen-next-label="Next slide" '
    'data-esen-initial-index="$initialIndex">'
    '<section id="$id-slide-0" data-esen-carousel-slide>'
    '<h2>First highlight</h2><p>First content</p></section>'
    '<section id="$id-slide-1" data-esen-carousel-slide>'
    '<h2>Second highlight</h2><p>Second content</p></section>'
    '<section id="$id-slide-2" data-esen-carousel-slide>'
    '<h2>Third highlight</h2><p>Third content</p></section></div>';

String _themeToggle() => '<span hidden data-esen-component="theme-toggle" '
    'data-esen-light-label="Light" data-esen-dark-label="Dark" '
    'data-esen-light-semantic-label="Use light mode" '
    'data-esen-dark-semantic-label="Use dark mode"></span>';

String _document({
  required String title,
  required String description,
  required String body,
  required String manifest,
}) =>
    '<!DOCTYPE html><html lang="en"><head>'
    '<title $seoDomFirstNavigationHeadAttribute>$title</title>'
    '<meta name="description" content="$description" '
    '$seoDomFirstNavigationHeadAttribute/>'
    '<script type="application/json" '
    '$seoDomFirstNavigationManifestAttribute '
    'data-esen-navigation-profile="$_profile">$manifest</script>'
    '</head><body>$body'
    '<script data-esen-seo-dom-first-runtime></script></body></html>';

void _mockFetch(String initialDocument, String targetDocument) {
  _runJavaScript(
    'globalThis.__esenOriginalFetch=globalThis.fetch;'
    'document.documentElement.dataset.mockFetchCount="0";'
    'globalThis.fetch=async function(u,o){'
    'document.documentElement.dataset.mockFetchCount=String('
    'Number(document.documentElement.dataset.mockFetchCount)+1);'
    'document.documentElement.dataset.mockFetchAccept=o.headers.Accept;'
    'document.documentElement.dataset.mockFetchCredentials=o.credentials;'
    'let body=String(u).includes("esen-nav-target=1")?'
    '${jsonEncode(targetDocument)}:${jsonEncode(initialDocument)};'
    'return new Response(body,{headers:{'
    '"content-type":"text/html; charset=utf-8"}})}',
  );
}

bool _dispatchWithoutNavigation(web.Element link, {bool control = false}) {
  web.document.documentElement?.removeAttribute('data-runtime-prevented');
  _runJavaScript(
    'window.addEventListener("click",function(e){'
    'document.documentElement.dataset.runtimePrevented=String('
    'e.defaultPrevented);e.preventDefault()},{once:true})',
  );
  link.dispatchEvent(
    web.MouseEvent(
      'click',
      web.MouseEventInit(
        bubbles: true,
        cancelable: true,
        ctrlKey: control,
      ),
    ),
  );
  return web.document.documentElement?.getAttribute('data-runtime-prevented') ==
      'true';
}

Future<void> _waitFor(bool Function() condition) async {
  for (var index = 0; index < 100; index++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('Timed out waiting for client navigation.');
}

void _removeAll(String selector) {
  final nodes = web.document.querySelectorAll(selector);
  for (var index = nodes.length - 1; index >= 0; index--) {
    final node = nodes.item(index);
    if (node != null) node.parentNode?.removeChild(node);
  }
}

void _runJavaScript(String source) {
  final script = web.document.createElement('script')..textContent = source;
  web.document.body?.appendChild(script);
  script.remove();
}
