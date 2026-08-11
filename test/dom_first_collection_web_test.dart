@TestOn('browser')
library;

import 'package:esen_seo/src/renderer/seo_dom_first_collection_runtime.g.dart';
import 'package:esen_seo/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;

void main() {
  late web.HTMLElement fixture;

  setUp(() {
    fixture = web.document.createElement('div') as web.HTMLElement;
    fixture.id = 'collection-fixture';
    web.document.body?.appendChild(fixture);
  });

  tearDown(() => fixture.remove());

  test('compiled collection searches, filters, sorts and pages', () {
    final container = _container(fixture);
    final root = _collection(container, 'article-collection');
    final items = root.querySelector('[data-esen-collection-items]')!;

    expect(root.querySelectorAll('input').length, 0);
    expect(root.querySelectorAll('button').length, 0);
    expect(_visibleItems(root), hasLength(4));
    _runCompiledCandidate();

    final search = root.querySelector('input')! as web.HTMLInputElement;
    final sorts = root.querySelectorAll('[data-esen-collection-sort]');
    final categories = root.querySelectorAll('[data-esen-collection-category]');
    expect(categories.length, 4);
    expect(_visibleItems(root).map((item) => item.textContent), [
      'Über Flutter',
      'CMS',
    ]);
    expect(root.querySelector('.esen-seo-collection-results')?.textContent,
        '4 Artikel');
    expect(root.querySelector('.esen-seo-collection-page')?.textContent,
        'Seite 1 / 2');
    expect(root.lastElementChild?.className,
        contains('esen-seo-collection-pagination'));
    expect(search.maxLength, seoCollectionMaxSearchLength);

    search.value = 'ueber seo';
    search.dispatchEvent(web.Event('input'));
    expect(_visibleItems(root).map((item) => item.textContent), [
      'Über Flutter',
    ]);
    expect(
        root
            .querySelector('.esen-seo-collection-empty')
            ?.hasAttribute('hidden'),
        isTrue);

    search.value = '';
    search.dispatchEvent(web.Event('input'));
    (categories.item(1)! as web.HTMLElement)
        .dispatchEvent(web.MouseEvent('click'));
    expect(_visibleItems(root).map((item) => item.textContent), [
      'Über Flutter',
      'Alpha',
    ]);
    expect((categories.item(1)! as web.Element).getAttribute('aria-pressed'),
        'true');

    (categories.item(0)! as web.HTMLElement)
        .dispatchEvent(web.MouseEvent('click'));
    (sorts.item(1)! as web.HTMLElement).dispatchEvent(web.MouseEvent('click'));
    expect(_visibleItems(root).map((item) => item.textContent), [
      'Alpha',
      'Adapter',
    ]);
    expect(items.children.item(0)?.textContent, 'Alpha');
    expect(
        (sorts.item(1)! as web.Element).getAttribute('aria-pressed'), 'true');

    (root.querySelector('[data-esen-collection-next]')! as web.HTMLElement)
        .dispatchEvent(web.MouseEvent('click'));
    expect(_visibleItems(root).map((item) => item.textContent), [
      'CMS',
      'Über Flutter',
    ]);
    expect(root.querySelector('.esen-seo-collection-page')?.textContent,
        'Seite 2 / 2');

    _runCompiledCandidate();
    expect(root.querySelectorAll('input').length, 1);
    expect(root.querySelectorAll('[data-esen-collection-sort]').length, 3);
  });

  test('no-result state retains the controls that recover the collection', () {
    final root = _collection(_container(fixture), 'empty-collection');
    _runCompiledCandidate();

    final search = root.querySelector('input')! as web.HTMLInputElement;
    search.value = 'not present';
    search.dispatchEvent(web.Event('input'));

    expect(_visibleItems(root), isEmpty);
    expect(
        root
            .querySelector('.esen-seo-collection-empty')
            ?.hasAttribute('hidden'),
        isFalse);
    expect(root.querySelector('input'), isNotNull);
    expect(root.querySelectorAll('[data-esen-collection-category]').length, 4);
    expect(
        root
            .querySelector('.esen-seo-collection-pagination')
            ?.hasAttribute('hidden'),
        isTrue);
  });

  test('invalid or ambiguous roots remain entirely static', () {
    final container = _container(fixture);
    final duplicateA = _collection(container, 'duplicate-collection');
    final duplicateB = _collection(container, 'duplicate-collection');
    final collision = _collection(container, 'collision-collection');
    container.appendChild(
      web.document.createElement('div')..id = 'collision-collection-search',
    );
    final malformedCategories = _collection(container, 'malformed-categories');
    malformedCategories
        .querySelector('[data-esen-collection-item]')
        ?.setAttribute('data-esen-item-categories', '0 0');
    final unexpectedChild = _collection(container, 'unexpected-child');
    unexpectedChild.appendChild(web.document.createElement('div'));
    final unsafeSort = _collection(container, 'unsafe-sort');
    unsafeSort
        .querySelector('[data-esen-collection-item]')
        ?.setAttribute('data-esen-item-sort-key', '9007199254740992');
    final hiddenParent = web.document.createElement('div')
      ..setAttribute('hidden', '');
    container.appendChild(hiddenParent);
    final hiddenRoot = _collection(hiddenParent, 'hidden-collection');

    _runCompiledCandidate();

    for (final root in [
      duplicateA,
      duplicateB,
      collision,
      malformedCategories,
      unexpectedChild,
      unsafeSort,
      hiddenRoot,
    ]) {
      expect(root.querySelectorAll('input').length, 0);
      expect(root.querySelectorAll('button').length, 0);
      expect(root.hasAttribute('data-esen-enhanced'), isFalse);
      expect(_visibleItems(root), hasLength(4));
    }
  });

  test('hostile-looking labels remain text values', () {
    final root = _collection(_container(fixture), 'text-collection')
      ..setAttribute(
        'data-esen-search-label',
        '<img src=x onerror=alert(1)>',
      );
    root.querySelector('[data-esen-category-index="0"]')?.textContent =
        '<svg onload=alert(1)>';

    _runCompiledCandidate();

    expect(root.querySelector('.esen-seo-collection-search span')?.textContent,
        '<img src=x onerror=alert(1)>');
    expect(
      root
          .querySelectorAll('[data-esen-collection-category]')
          .item(1)
          ?.textContent,
      '<svg onload=alert(1)>',
    );
    expect(root.querySelectorAll('img,svg').length, 0);
    expect(root.querySelectorAll('[onerror],[onload]').length, 0);
  });

  test('requires one unambiguous package-owned DOM-first container', () {
    final first = _container(fixture);
    final root = _collection(first, 'container-collection');
    fixture.appendChild(
      web.document.createElement('div')
        ..id = 'esen-seo-content'
        ..setAttribute('data-esen-seo-dom-first', 'true'),
    );

    _runCompiledCandidate();

    expect(root.querySelectorAll('input').length, 0);
    expect(_visibleItems(root), hasLength(4));
  });
}

web.HTMLElement _container(web.HTMLElement fixture) {
  final container = web.document.createElement('div') as web.HTMLElement
    ..id = 'esen-seo-content'
    ..setAttribute('data-esen-seo-dom-first', 'true');
  fixture.appendChild(container);
  return container;
}

web.HTMLElement _collection(web.Element parent, String id) {
  final root = web.document.createElement('section') as web.HTMLElement
    ..id = id
    ..setAttribute('data-esen-component', 'collection')
    ..setAttribute('data-esen-label', 'Blogartikel')
    ..setAttribute('data-esen-page-size', '2')
    ..setAttribute('data-esen-initial-sort', 'newest')
    ..setAttribute('data-esen-search-label', 'Artikel suchen')
    ..setAttribute('data-esen-categories-label', 'Kategorien')
    ..setAttribute('data-esen-all-label', 'Alle')
    ..setAttribute('data-esen-sort-label', 'Sortieren')
    ..setAttribute('data-esen-newest-label', 'Neueste')
    ..setAttribute('data-esen-oldest-label', 'Älteste')
    ..setAttribute('data-esen-title-label', 'Titel')
    ..setAttribute('data-esen-previous-label', 'Zurück')
    ..setAttribute('data-esen-next-label', 'Weiter')
    ..setAttribute('data-esen-results-label', 'Artikel')
    ..setAttribute('data-esen-empty-label', 'Keine Artikel')
    ..setAttribute('data-esen-page-label', 'Seite');
  final categories = web.document.createElement('div')
    ..setAttribute('data-esen-collection-categories', '')
    ..setAttribute('hidden', '')
    ..setAttribute('aria-hidden', 'true');
  for (final (index, label) in ['Flutter', 'CMS', 'JavaScript'].indexed) {
    categories.appendChild(
      web.document.createElement('span')
        ..setAttribute('data-esen-category-index', '$index')
        ..textContent = label,
    );
  }
  final items = web.document.createElement('div')
    ..setAttribute('data-esen-collection-items', '');
  const data = [
    ('ueber flutter', 'ueber flutter seo html', '0', 40, 'Über Flutter'),
    ('cms', 'cms git publishing', '1', 30, 'CMS'),
    ('adapter', 'adapter javascript', '2', 20, 'Adapter'),
    ('alpha', 'alpha flutter basics', '0', 10, 'Alpha'),
  ];
  for (final (index, entry) in data.indexed) {
    items.appendChild(
      web.document.createElement('article')
        ..id = '$id-item-$index'
        ..setAttribute('data-esen-collection-item', '')
        ..setAttribute('data-esen-item-order', '$index')
        ..setAttribute('data-esen-item-title', entry.$1)
        ..setAttribute('data-esen-item-search', entry.$2)
        ..setAttribute('data-esen-item-categories', entry.$3)
        ..setAttribute('data-esen-item-sort-key', '${entry.$4}')
        ..textContent = entry.$5,
    );
  }
  root.appendChild(categories);
  root.appendChild(items);
  parent.appendChild(root);
  return root;
}

List<web.Element> _visibleItems(web.Element root) {
  final nodes = root.querySelectorAll('[data-esen-collection-item]');
  return [
    for (var index = 0; index < nodes.length; index++)
      if (nodes.item(index) case final web.Element item)
        if (!item.hasAttribute('hidden')) item,
  ];
}

void _runCompiledCandidate() {
  final script = web.document.createElement('script')
    ..textContent = seoDomFirstCollectionRuntime;
  web.document.body?.appendChild(script);
  script.remove();
}
