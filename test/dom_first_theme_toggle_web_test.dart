@TestOn('browser')
library;

import 'package:esen_seo/src/components/seo_theme_transition.dart';
import 'package:esen_seo/src/renderer/seo_dom_first_theme_toggle_runtime.g.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;

void main() {
  late web.HTMLElement fixture;

  setUp(() {
    web.window.localStorage.removeItem(seoThemePreferenceStorageKey);
    web.document.documentElement?.removeAttribute('data-esen-theme');
    fixture = web.document.createElement('div') as web.HTMLElement;
    fixture.id = 'theme-fixture';
    web.document.body?.appendChild(fixture);
  });

  tearDown(() {
    fixture.remove();
    web.window.localStorage.removeItem(seoThemePreferenceStorageKey);
    web.document.documentElement?.removeAttribute('data-esen-theme');
  });

  test('generated control restores, toggles and persists a preference', () {
    web.window.localStorage.setItem(seoThemePreferenceStorageKey, 'dark');
    final root = _themeToggle(_container(fixture));

    _runGeneratedCandidate();

    final button = root.querySelector('button')! as web.HTMLElement;
    expect(root.hasAttribute('hidden'), isFalse);
    expect(root.getAttribute('data-esen-enhanced'), 'true');
    expect(button.textContent, contains('Hell'));
    expect(button.getAttribute('aria-label'), 'Hellen Modus aktivieren');
    expect(button.getAttribute('data-esen-dark'), 'true');
    expect(button.children.length, 0);
    expect(
      web.document.documentElement?.getAttribute('data-esen-theme'),
      'dark',
    );

    button.dispatchEvent(
      web.MouseEvent('click', web.MouseEventInit(bubbles: true)),
    );

    expect(button.textContent, contains('Dunkel'));
    expect(button.getAttribute('aria-label'), 'Dunklen Modus aktivieren');
    expect(button.getAttribute('data-esen-dark'), 'false');
    expect(
      web.document.documentElement?.getAttribute('data-esen-theme'),
      'light',
    );
    expect(
      web.window.localStorage.getItem(seoThemePreferenceStorageKey),
      'light',
    );

    web.window.dispatchEvent(
      web.StorageEvent(
        'storage',
        web.StorageEventInit(
          key: seoThemePreferenceStorageKey,
          newValue: 'dark',
        ),
      ),
    );
    expect(button.textContent, contains('Hell'));
    expect(
      web.document.documentElement?.getAttribute('data-esen-theme'),
      'dark',
    );

    web.window.dispatchEvent(
      web.StorageEvent('storage', web.StorageEventInit()),
    );
    expect(
      web.document.documentElement?.hasAttribute('data-esen-theme'),
      isFalse,
    );
  });

  test('multiple controls remain hidden and entirely unmodified', () {
    final container = _container(fixture);
    final first = _themeToggle(container);
    final second = _themeToggle(container);

    _runGeneratedCandidate();

    for (final root in [first, second]) {
      expect(root.hasAttribute('hidden'), isTrue);
      expect(root.querySelectorAll('button').length, 0);
      expect(root.hasAttribute('data-esen-enhanced'), isFalse);
    }
  });

  test('a missing label leaves the single control inert', () {
    final root = _themeToggle(_container(fixture))
      ..removeAttribute('data-esen-dark-label');

    _runGeneratedCandidate();

    expect(root.hasAttribute('hidden'), isTrue);
    expect(root.querySelectorAll('button').length, 0);
    expect(root.hasAttribute('data-esen-enhanced'), isFalse);
  });

  test('unexpected children leave the single control inert', () {
    final root = _themeToggle(_container(fixture))
      ..appendChild(web.document.createElement('span'));

    _runGeneratedCandidate();

    expect(root.hasAttribute('hidden'), isTrue);
    expect(root.querySelectorAll('button').length, 0);
    expect(root.hasAttribute('data-esen-enhanced'), isFalse);
  });

  test('a hidden ancestor keeps the prepared control out of view', () {
    final container = _container(fixture);
    final hiddenParent = web.document.createElement('div')
      ..setAttribute('hidden', '');
    container.appendChild(hiddenParent);
    final root = _themeToggle(hiddenParent);

    _runGeneratedCandidate();

    expect(hiddenParent.hasAttribute('hidden'), isTrue);
    expect(root.hasAttribute('hidden'), isFalse);
    expect(root.querySelectorAll('button').length, 1);
    expect(root.hasAttribute('data-esen-enhanced'), isTrue);
  });

  test('hostile-looking labels are copied only through text content', () {
    final root = _themeToggle(_container(fixture))
      ..setAttribute('data-esen-dark-label', '<img src=x onerror=alert(1)>')
      ..setAttribute(
        'data-esen-dark-semantic-label',
        '<svg onload=alert(1)>',
      );

    _runGeneratedCandidate();

    final button = root.querySelector('button')! as web.HTMLElement;
    expect(button.textContent, contains('<img src=x onerror=alert(1)>'));
    expect(button.getAttribute('aria-label'), '<svg onload=alert(1)>');
    expect(button.querySelectorAll('img,svg').length, 0);
    expect(root.querySelectorAll('[onerror],[onload]').length, 0);
  });
}

web.HTMLElement _container(web.HTMLElement fixture) {
  final container = web.document.createElement('div') as web.HTMLElement
    ..id = 'esen-seo-content'
    ..setAttribute('data-esen-seo-dom-first', 'true');
  fixture.appendChild(container);
  return container;
}

web.HTMLElement _themeToggle(web.Element parent) {
  final root = web.document.createElement('span') as web.HTMLElement
    ..className = 'esen-seo-theme-toggle'
    ..setAttribute('hidden', '')
    ..setAttribute('data-esen-component', 'theme-toggle')
    ..setAttribute('data-esen-light-label', 'Hell')
    ..setAttribute('data-esen-dark-label', 'Dunkel')
    ..setAttribute('data-esen-light-semantic-label', 'Hellen Modus aktivieren')
    ..setAttribute('data-esen-dark-semantic-label', 'Dunklen Modus aktivieren');
  parent.appendChild(root);
  return root;
}

void _runGeneratedCandidate() {
  final script = web.document.createElement('script')
    ..textContent = seoDomFirstThemeToggleRuntime;
  web.document.body?.appendChild(script);
  script.remove();
}
