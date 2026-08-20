@TestOn('browser')
library;

import 'dart:async';
import 'dart:js_interop';

import 'package:esen_seo/src/renderer/seo_dom_first_collection_runtime.g.dart';
import 'package:esen_seo/src/renderer/dom_first_collection_adapter_web.dart';
import 'package:esen_seo/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;

void main() {
  late web.HTMLElement fixture;
  late String originalHref;

  setUp(() {
    originalHref = web.window.location.href;
    fixture = web.document.createElement('div') as web.HTMLElement;
    fixture.id = 'collection-fixture';
    web.document.body?.appendChild(fixture);
  });

  tearDown(() {
    fixture.remove();
    web.window.history.replaceState(null, '', originalHref);
  });

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

  test('application transition drives the validated browser adapter', () {
    final root = _collection(_container(fixture), 'application-collection');

    enhanceSeoDomFirstCollections(
      transition: _titleWhileSearching,
      enableUrlSynchronization: false,
    );
    final search = root.querySelector('input')! as web.HTMLInputElement;
    search.value = 'flutter';
    search.dispatchEvent(web.Event('input'));

    expect(_visibleItems(root).map((item) => item.textContent), [
      'Alpha',
      'Über Flutter',
    ]);
    final sorts = root.querySelectorAll('[data-esen-collection-sort]');
    expect(
      (sorts.item(2) as web.Element).getAttribute('aria-pressed'),
      'true',
    );
  });

  test('invalid application output leaves DOM and URL state unchanged', () {
    final root = _collection(
      _container(fixture),
      'rejected-application-collection',
    );
    final before = web.window.location.href;

    enhanceSeoDomFirstCollections(
      transition: (
        state,
        action, {
        required records,
        required categoryCount,
        required pageSize,
      }) =>
          const SeoCollectionState(categoryIndex: 999, page: 999),
      enableUrlSynchronization: false,
    );
    final search = root.querySelector('input')! as web.HTMLInputElement;
    search.value = 'flutter';
    search.dispatchEvent(web.Event('input'));

    expect(search.value, '');
    expect(_visibleItems(root).map((item) => item.textContent), [
      'Über Flutter',
      'CMS',
    ]);
    expect(web.window.location.href, before);
  });

  test('application mode rejects URL synchronization before mutation', () {
    final root = _collection(
      _container(fixture),
      'application-url-collection',
      synchronizeUrl: true,
    );

    enhanceSeoDomFirstCollections(
      transition: _titleWhileSearching,
      enableUrlSynchronization: false,
    );

    expect(root.hasAttribute('data-esen-enhanced'), isFalse);
    expect(root.querySelectorAll('input,button').length, 0);
    expect(_visibleItems(root), hasLength(4));
  });

  test('combined feature script enhances collection and theme together', () {
    final container = _container(fixture);
    final collection = _collection(container, 'combined-collection');
    final theme = web.document.createElement('span') as web.HTMLElement
      ..setAttribute('hidden', '')
      ..setAttribute('data-esen-component', 'theme-toggle')
      ..setAttribute('data-esen-light-label', 'Light')
      ..setAttribute('data-esen-dark-label', 'Dark')
      ..setAttribute('data-esen-light-semantic-label', 'Use light theme')
      ..setAttribute('data-esen-dark-semantic-label', 'Use dark theme');
    container.appendChild(theme);
    final html = seoDomFirstFeatureScriptHtml(const {
      SeoDomFirstFeature.collection,
      SeoDomFirstFeature.themeToggle,
    });
    final runtime =
        RegExp(r'<script[^>]*>([\s\S]*?)</script>').firstMatch(html)!.group(1)!;

    _runJavaScript(runtime);

    expect(collection.querySelectorAll('input').length, 1);
    expect(theme.querySelectorAll('button').length, 1);
    expect(theme.hasAttribute('hidden'), isFalse);
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
    final malformedUrlMarker = _collection(container, 'malformed-url-marker')
      ..setAttribute('data-esen-synchronize-url', 'yes');
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
      malformedUrlMarker,
    ]) {
      expect(root.querySelectorAll('input').length, 0);
      expect(root.querySelectorAll('button').length, 0);
      expect(root.hasAttribute('data-esen-enhanced'), isFalse);
      expect(_visibleItems(root), hasLength(4));
    }
    expect(hiddenParent.hasAttribute('hidden'), isTrue);
    expect(hiddenRoot.querySelectorAll('input').length, 1);
    expect(hiddenRoot.hasAttribute('data-esen-enhanced'), isTrue);
  });

  test('switching sort modes preserves source-order tie breaking', () {
    final root = _collection(
      _container(fixture),
      'stable-order-collection',
      initialSort: SeoCollectionSort.title,
    );
    final items = root.querySelectorAll('[data-esen-collection-item]');
    for (var index = 0; index < items.length; index++) {
      (items.item(index) as web.Element?)
          ?.setAttribute('data-esen-item-sort-key', '1');
    }

    _runCompiledCandidate();
    final sorts = root.querySelectorAll('[data-esen-collection-sort]');
    (sorts.item(0)! as web.HTMLElement).dispatchEvent(web.MouseEvent('click'));

    expect(_visibleItems(root).map((item) => item.textContent), [
      'Über Flutter',
      'CMS',
    ]);
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

  test('URL state is canonical, shareable and follows browser history',
      () async {
    final codec = SeoCollectionUrlCodec(
      interactionId: 'url-collection',
      categoryLabels: const ['Flutter', 'CMS', 'JavaScript'],
    );
    final initialUrl = web.URL(web.window.location.href);
    for (final name in _parameterNames(codec)) {
      initialUrl.searchParams.delete(name);
    }
    initialUrl.searchParams
      ..set('esen-test-keep', 'yes')
      ..set(codec.queryParameter, 'flutter')
      ..set(codec.categoryParameter, 'FLUTTER')
      ..set(codec.sortParameter, 'oldest')
      ..set(codec.pageParameter, '2');
    initialUrl.hash = 'results';
    web.window.history.replaceState(null, '', initialUrl.href);

    final root = _collection(
      _container(fixture),
      'url-collection',
      synchronizeUrl: true,
      pageSize: 1,
    );
    _runCompiledCandidate();

    final search = root.querySelector('input')! as web.HTMLInputElement;
    final categories = root.querySelectorAll(
      '[data-esen-collection-category]',
    );
    expect(search.value, 'flutter');
    expect(_visibleItems(root).map((item) => item.textContent), [
      'Über Flutter',
    ]);
    var current = web.URL(web.window.location.href);
    expect(current.searchParams.get(codec.categoryParameter), 'flutter');
    expect(current.searchParams.get('esen-test-keep'), 'yes');
    expect(current.hash, '#results');

    final historyBeforeSearch = web.window.history.length;
    search.value = '';
    search.dispatchEvent(web.Event('input'));
    expect(web.window.history.length, historyBeforeSearch);
    current = web.URL(web.window.location.href);
    expect(current.searchParams.get(codec.queryParameter), isNull);
    expect(current.searchParams.get(codec.pageParameter), isNull);
    expect(_visibleItems(root).map((item) => item.textContent), ['Alpha']);

    final historyBeforeCategory = web.window.history.length;
    (categories.item(0)! as web.HTMLElement)
        .dispatchEvent(web.MouseEvent('click'));
    expect(web.window.history.length, historyBeforeCategory + 1);
    final firstPageUrl = web.window.location.href;
    expect(_visibleItems(root).map((item) => item.textContent), [
      'Alpha',
    ]);

    final historyBeforePage = web.window.history.length;
    (root.querySelector('[data-esen-collection-next]')! as web.HTMLElement)
        .dispatchEvent(web.MouseEvent('click'));
    expect(web.window.history.length, historyBeforePage + 1);
    final secondPageUrl = web.window.location.href;
    expect(secondPageUrl, isNot(firstPageUrl));
    expect(_visibleItems(root).map((item) => item.textContent), [
      'Adapter',
    ]);

    await _navigateHistory(() => web.window.history.back());
    expect(web.window.location.href, firstPageUrl);
    expect(_visibleItems(root).map((item) => item.textContent), [
      'Alpha',
    ]);

    await _navigateHistory(() => web.window.history.forward());
    expect(web.window.location.href, secondPageUrl);
    expect(_visibleItems(root).map((item) => item.textContent), [
      'Adapter',
    ]);
  });

  test('malformed URL values fall back and are removed canonically', () {
    final codec = SeoCollectionUrlCodec(
      interactionId: 'malformed-url-collection',
      categoryLabels: const ['Flutter', 'CMS', 'JavaScript'],
    );
    final url = web.URL(web.window.location.href);
    for (final name in _parameterNames(codec)) {
      url.searchParams.delete(name);
    }
    url.searchParams
      ..set('esen-test-keep', 'yes')
      ..append(codec.queryParameter, 'first')
      ..append(codec.queryParameter, 'second')
      ..set(codec.categoryParameter, 'missing')
      ..set(codec.sortParameter, 'sideways')
      ..set(codec.pageParameter, '0002');
    web.window.history.replaceState(null, '', url.href);

    final root = _collection(
      _container(fixture),
      'malformed-url-collection',
      synchronizeUrl: true,
    );
    _runCompiledCandidate();

    final current = web.URL(web.window.location.href);
    for (final name in _parameterNames(codec)) {
      expect(current.searchParams.get(name), isNull);
    }
    expect(current.searchParams.get('esen-test-keep'), 'yes');
    expect((root.querySelector('input')! as web.HTMLInputElement).value, '');
    expect(_visibleItems(root).map((item) => item.textContent), [
      'Über Flutter',
      'CMS',
    ]);
  });

  test('URL-shaped parameters are inert without the explicit marker', () {
    final codec = SeoCollectionUrlCodec(
      interactionId: 'local-collection',
      categoryLabels: const ['Flutter', 'CMS', 'JavaScript'],
    );
    final url = web.URL(web.window.location.href)
      ..searchParams.set(codec.queryParameter, 'adapter');
    web.window.history.replaceState(null, '', url.href);
    final before = web.window.location.href;

    final root = _collection(_container(fixture), 'local-collection');
    _runCompiledCandidate();

    expect(web.window.location.href, before);
    expect((root.querySelector('input')! as web.HTMLInputElement).value, '');
    expect(_visibleItems(root).map((item) => item.textContent), [
      'Über Flutter',
      'CMS',
    ]);
  });

  test('multiple URL-synchronized collections keep independent state', () {
    final firstCodec = SeoCollectionUrlCodec(
      interactionId: 'first-collection',
      categoryLabels: const ['Flutter', 'CMS', 'JavaScript'],
    );
    final secondCodec = SeoCollectionUrlCodec(
      interactionId: 'second-collection',
      categoryLabels: const ['Flutter', 'CMS', 'JavaScript'],
    );
    final url = web.URL(web.window.location.href)
      ..searchParams.set(firstCodec.queryParameter, 'flutter')
      ..searchParams.set(secondCodec.queryParameter, 'adapter');
    web.window.history.replaceState(null, '', url.href);

    final container = _container(fixture);
    final first = _collection(
      container,
      'first-collection',
      synchronizeUrl: true,
    );
    final second = _collection(
      container,
      'second-collection',
      synchronizeUrl: true,
    );
    _runCompiledCandidate();

    expect(_visibleItems(first).map((item) => item.textContent), [
      'Über Flutter',
      'Alpha',
    ]);
    expect(_visibleItems(second).map((item) => item.textContent), ['Adapter']);

    final firstSearch = first.querySelector('input')! as web.HTMLInputElement;
    firstSearch.value = 'cms';
    firstSearch.dispatchEvent(web.Event('input'));
    final current = web.URL(web.window.location.href);
    expect(current.searchParams.get(firstCodec.queryParameter), 'cms');
    expect(current.searchParams.get(secondCodec.queryParameter), 'adapter');
    expect(_visibleItems(first).map((item) => item.textContent), ['CMS']);
    expect(_visibleItems(second).map((item) => item.textContent), ['Adapter']);
  });
}

SeoCollectionState _titleWhileSearching(
  SeoCollectionState state,
  SeoCollectionAction action, {
  required List<SeoCollectionRecord> records,
  required int categoryCount,
  required int pageSize,
}) {
  final next = transitionSeoCollection(
    state,
    action,
    records: records,
    categoryCount: categoryCount,
    pageSize: pageSize,
  );
  if (action is! SeoCollectionSetQuery || next.query.isEmpty) return next;
  return transitionSeoCollection(
    next,
    const SeoCollectionSetSort(SeoCollectionSort.title),
    records: records,
    categoryCount: categoryCount,
    pageSize: pageSize,
  );
}

web.HTMLElement _container(web.HTMLElement fixture) {
  final container = web.document.createElement('div') as web.HTMLElement
    ..id = 'esen-seo-content'
    ..setAttribute('data-esen-seo-dom-first', 'true');
  fixture.appendChild(container);
  return container;
}

web.HTMLElement _collection(
  web.Element parent,
  String id, {
  bool synchronizeUrl = false,
  int pageSize = 2,
  SeoCollectionSort initialSort = SeoCollectionSort.newest,
}) {
  final root = web.document.createElement('section') as web.HTMLElement
    ..id = id
    ..setAttribute('data-esen-component', 'collection')
    ..setAttribute('data-esen-label', 'Blogartikel')
    ..setAttribute('data-esen-page-size', '$pageSize')
    ..setAttribute(
      'data-esen-initial-sort',
      seoCollectionSortMarker(initialSort),
    )
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
  if (synchronizeUrl) {
    root.setAttribute('data-esen-synchronize-url', 'true');
  }
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
  const sourceData = [
    ('ueber flutter', 'ueber flutter seo html', '0', 40, 'Über Flutter'),
    ('cms', 'cms git publishing', '1', 30, 'CMS'),
    ('adapter', 'adapter javascript', '2', 20, 'Adapter'),
    ('alpha', 'alpha flutter basics', '0', 10, 'Alpha'),
  ];
  final data = sourceData.indexed.toList()
    ..sort((left, right) {
      final compared = switch (initialSort) {
        SeoCollectionSort.newest => right.$2.$4.compareTo(left.$2.$4),
        SeoCollectionSort.oldest => left.$2.$4.compareTo(right.$2.$4),
        SeoCollectionSort.title => left.$2.$1.compareTo(right.$2.$1),
      };
      return compared == 0 ? left.$1.compareTo(right.$1) : compared;
    });
  for (final (outputIndex, indexedEntry) in data.indexed) {
    final (sourceIndex, entry) = indexedEntry;
    items.appendChild(
      web.document.createElement('article')
        ..id = '$id-item-$outputIndex'
        ..setAttribute('data-esen-collection-item', '')
        ..setAttribute('data-esen-item-order', '$sourceIndex')
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
  _runJavaScript(seoDomFirstCollectionRuntime);
}

void _runJavaScript(String source) {
  final script = web.document.createElement('script')..textContent = source;
  web.document.body?.appendChild(script);
  script.remove();
}

Future<void> _navigateHistory(void Function() navigate) {
  final completer = Completer<void>();
  late JSFunction listener;
  listener = ((web.Event _) {
    web.window.removeEventListener('popstate', listener);
    completer.complete();
  }).toJS;
  web.window.addEventListener('popstate', listener);
  navigate();
  return completer.future.timeout(const Duration(seconds: 5));
}

List<String> _parameterNames(SeoCollectionUrlCodec codec) => [
      codec.queryParameter,
      codec.categoryParameter,
      codec.sortParameter,
      codec.pageParameter,
    ];
