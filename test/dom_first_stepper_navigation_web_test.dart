@TestOn('browser')
library;

import 'dart:convert';
import 'dart:js_interop';

import 'package:esen_seo/core.dart';
import 'package:esen_seo/src/renderer/seo_dom_first_navigation_runtime.g.dart';
import 'package:esen_seo/src/renderer/seo_dom_first_stepper_runtime.g.dart';
import 'package:esen_seo/src/renderer/seo_dom_first_theme_toggle_runtime.g.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;

const _profile = 'navigation.stepper.themeToggle';

void main() {
  test('navigation restores delivered step state and reveals fragments',
      () async {
    _removeAll('title');
    _removeAll('[$seoDomFirstNavigationHeadAttribute]');
    _removeAll('script[$seoDomFirstNavigationManifestAttribute]');
    _removeAll('script[data-esen-seo-dom-first-runtime]');
    _removeAll('#esen-seo-content');

    final originalHref = web.window.location.href;
    addTearDown(() {
      web.window.history.replaceState(null, '', originalHref);
      _runJavaScript(
        'if(globalThis.__esenOriginalFetch){'
        'globalThis.fetch=globalThis.__esenOriginalFetch;'
        'delete globalThis.__esenOriginalFetch}',
      );
      _removeAll('#esen-seo-content');
      _removeAll('[$seoDomFirstNavigationHeadAttribute]');
      _removeAll('script[$seoDomFirstNavigationManifestAttribute]');
      _removeAll('script[data-esen-seo-dom-first-runtime]');
    });

    web.window.history.replaceState(null, '', '/stepper-page');
    final manifest = jsonEncode({
      'schema': seoDomFirstNavigationManifestSchema,
      'base': '/',
      'profile': _profile,
      'routes': [
        ['/:page', _profile],
      ],
    });
    final initialDocument = _document(
      title: 'Initial stepper',
      body: _body(
        'Initial stepper',
        '?stepper-target=1#target-stepper-panel-2',
        stepperId: 'initial-stepper',
        initialIndex: 0,
      ),
      manifest: manifest,
    );
    final targetDocument = _document(
      title: 'Target stepper',
      body: _body(
        'Target stepper',
        '?stepper-initial=1',
        stepperId: 'target-stepper',
        initialIndex: 1,
      ),
      manifest: manifest,
    );

    web.document.head
      ?..appendChild(
        web.document.createElement('title')
          ..setAttribute(seoDomFirstNavigationHeadAttribute, '')
          ..textContent = 'Initial stepper',
      )
      ..appendChild(
        web.document.createElement('script')
          ..setAttribute('type', 'application/json')
          ..setAttribute(seoDomFirstNavigationManifestAttribute, '')
          ..setAttribute('data-esen-navigation-profile', _profile)
          ..textContent = manifest,
      );
    final initial = _content(
      'Initial stepper',
      '?stepper-target=1#target-stepper-panel-2',
      stepperId: 'initial-stepper',
      initialIndex: 0,
    );
    web.document.body?.appendChild(initial);
    _mockFetch(initialDocument, targetDocument);

    web.document.body?.appendChild(
      web.document.createElement('script')
        ..setAttribute('data-esen-seo-dom-first-runtime', '')
        ..textContent = '$seoDomFirstNavigationRuntime;'
            '$seoDomFirstStepperRuntime;'
            '$seoDomFirstThemeToggleRuntime',
    );

    expect(
      initial.querySelector('[data-esen-stepper-status]')?.textContent,
      'Step 1 / 3',
    );
    final click = web.MouseEvent(
      'click',
      web.MouseEventInit(bubbles: true, cancelable: true),
    );
    initial.querySelector('a')?.dispatchEvent(click);
    await _waitFor(
      () =>
          web.window.location.search == '?stepper-target=1' &&
          web.document.title == 'Target stepper',
    );

    expect(click.defaultPrevented, isTrue);
    final target = web.document.querySelector('#esen-seo-content')!;
    expect(target.querySelectorAll('[data-esen-stepper-controls]').length, 1);
    expect(target.querySelectorAll('[data-esen-step-button]').length, 3);
    expect(
      target.querySelector('[data-esen-stepper-status]')?.textContent,
      'Step 3 / 3',
    );
    expect(
      target.querySelector('#target-stepper-panel-2')?.hasAttribute('hidden'),
      isFalse,
    );
    web.document.documentElement?.dispatchEvent(
      web.Event('esen-seo:navigation'),
    );
    expect(target.querySelectorAll('[data-esen-stepper-controls]').length, 1);

    final previous = target
        .querySelectorAll('[data-esen-stepper-control]')
        .item(0)! as web.HTMLElement;
    previous.click();
    expect(
      target.querySelector('[data-esen-stepper-status]')?.textContent,
      'Step 2 / 3',
    );

    web.window.history.back();
    await _waitFor(
      () =>
          web.window.location.search.isEmpty &&
          web.document.title == 'Initial stepper',
    );
    final restored = web.document.querySelector('#esen-seo-content')!;
    expect(
      restored.querySelector('[data-esen-stepper-status]')?.textContent,
      'Step 1 / 3',
    );
    expect(restored.querySelectorAll('[data-esen-stepper-controls]').length, 1);

    web.window.history.forward();
    await _waitFor(
      () =>
          web.window.location.search == '?stepper-target=1' &&
          web.document.title == 'Target stepper',
    );
    final forwarded = web.document.querySelector('#esen-seo-content')!;
    expect(
      forwarded.querySelector('[data-esen-stepper-status]')?.textContent,
      'Step 3 / 3',
    );
    expect(
        forwarded.querySelectorAll('[data-esen-stepper-controls]').length, 1);
    expect(
      web.document.documentElement?.getAttribute('data-mock-fetch-count'),
      '3',
    );
  });
}

web.HTMLElement _content(
  String heading,
  String href, {
  required String stepperId,
  required int initialIndex,
}) {
  final holder = web.document.createElement('div');
  holder.setHTMLUnsafe(
    _body(
      heading,
      href,
      stepperId: stepperId,
      initialIndex: initialIndex,
    ).toJS,
  );
  return holder.firstElementChild! as web.HTMLElement;
}

String _body(
  String heading,
  String href, {
  required String stepperId,
  required int initialIndex,
}) =>
    '<div id="esen-seo-content" data-esen-seo-dom-first="true">'
    '<main><h1>$heading</h1><a href="$href">Continue</a>'
    '${_stepper(stepperId, initialIndex)}${_themeToggle()}</main></div>';

String _stepper(String id, int initialIndex) {
  final steps = <String>[];
  for (var index = 0; index < 3; index++) {
    steps.add(
      '<li id="$id-step-$index" data-esen-step>'
      '<h2>Stage ${index + 1}</h2>'
      '<div id="$id-panel-$index" data-esen-step-panel>'
      '<p>Stage ${index + 1} content</p></div></li>',
    );
  }
  return '<div id="$id" class="esen-seo-stepper" '
      'data-esen-component="stepper" data-esen-label="Publishing flow" '
      'data-esen-previous-label="Back" data-esen-next-label="Next" '
      'data-esen-position-label="Step" '
      'data-esen-initial-index="$initialIndex">'
      '<ol data-esen-step-list>${steps.join()}</ol></div>';
}

String _themeToggle() => '<span hidden data-esen-component="theme-toggle" '
    'data-esen-light-label="Light" data-esen-dark-label="Dark" '
    'data-esen-light-semantic-label="Use light mode" '
    'data-esen-dark-semantic-label="Use dark mode"></span>';

String _document({
  required String title,
  required String body,
  required String manifest,
}) =>
    '<!DOCTYPE html><html lang="en"><head>'
    '<title $seoDomFirstNavigationHeadAttribute>$title</title>'
    '<script type="application/json" '
    '$seoDomFirstNavigationManifestAttribute '
    'data-esen-navigation-profile="$_profile">$manifest</script>'
    '</head><body>$body'
    '<script data-esen-seo-dom-first-runtime></script></body></html>';

void _mockFetch(String initialDocument, String targetDocument) {
  _runJavaScript(
    'globalThis.__esenOriginalFetch=globalThis.fetch;'
    'document.documentElement.dataset.mockFetchCount="0";'
    'globalThis.fetch=async function(u){'
    'document.documentElement.dataset.mockFetchCount=String('
    'Number(document.documentElement.dataset.mockFetchCount)+1);'
    'let body=String(u).includes("stepper-target=1")?'
    '${jsonEncode(targetDocument)}:${jsonEncode(initialDocument)};'
    'return new Response(body,{headers:{'
    '"content-type":"text/html; charset=utf-8"}})}',
  );
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
    nodes.item(index)?.parentNode?.removeChild(nodes.item(index)!);
  }
}

void _runJavaScript(String source) {
  final script = web.document.createElement('script')..textContent = source;
  web.document.body?.appendChild(script);
  script.remove();
}
