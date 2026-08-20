import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../components/seo_collection_transition.dart';
import '../components/seo_collection_url.dart';
import '../components/seo_component_format.dart';
import 'seo_container.dart';

/// Enhances every valid collection in the package-owned DOM-first container.
///
/// Discovery and validation are read-only. Only a complete [_CollectionPlan]
/// can cross the apply boundary and mutate the visible document.
void enhanceSeoDomFirstCollections({
  SeoCollectionTransition transition = transitionSeoCollection,
  bool enableUrlSynchronization = true,
}) {
  for (final apply in _CollectionApplyBoundary.discover(
    web.document,
    enableUrlSynchronization: enableUrlSynchronization,
  )) {
    if (enableUrlSynchronization) {
      _enhanceSynchronizedCollection(apply, transition);
    } else {
      _enhanceLocalCollection(apply, transition);
    }
  }
}

void _enhanceLocalCollection(
  _CollectionApplyBoundary apply,
  SeoCollectionTransition transition,
) {
  var state = SeoCollectionState(sort: apply.initialSort);

  void render() {
    apply.state(
      state,
      previousEnabled: canApplySeoCollectionAction(
        transition,
        state,
        const SeoCollectionPreviousPage(),
        records: apply.records,
        categoryCount: apply.categoryCount,
        pageSize: apply.pageSize,
      ),
      nextEnabled: canApplySeoCollectionAction(
        transition,
        state,
        const SeoCollectionNextPage(),
        records: apply.records,
        categoryCount: apply.categoryCount,
        pageSize: apply.pageSize,
      ),
    );
  }

  void dispatch(SeoCollectionAction action) {
    state = applySeoCollectionTransition(
      transition,
      state,
      action,
      records: apply.records,
      categoryCount: apply.categoryCount,
      pageSize: apply.pageSize,
    );
    render();
  }

  apply.mount(dispatch);
  state = selectSeoCollection(
    records: apply.records,
    categoryCount: apply.categoryCount,
    pageSize: apply.pageSize,
    state: state,
  ).state;
  render();
}

void _enhanceSynchronizedCollection(
  _CollectionApplyBoundary apply,
  SeoCollectionTransition transition,
) {
  var state = apply.stateFromUrl();

  void render() {
    apply.state(
      state,
      previousEnabled: canApplySeoCollectionAction(
        transition,
        state,
        const SeoCollectionPreviousPage(),
        records: apply.records,
        categoryCount: apply.categoryCount,
        pageSize: apply.pageSize,
      ),
      nextEnabled: canApplySeoCollectionAction(
        transition,
        state,
        const SeoCollectionNextPage(),
        records: apply.records,
        categoryCount: apply.categoryCount,
        pageSize: apply.pageSize,
      ),
    );
  }

  void dispatch(SeoCollectionAction action) {
    state = applySeoCollectionTransition(
      transition,
      state,
      action,
      records: apply.records,
      categoryCount: apply.categoryCount,
      pageSize: apply.pageSize,
    );
    render();
    apply.synchronizeUrl(
      state,
      push: action is! SeoCollectionSetQuery,
    );
  }

  apply.mount(dispatch);
  state = selectSeoCollection(
    records: apply.records,
    categoryCount: apply.categoryCount,
    pageSize: apply.pageSize,
    state: state,
  ).state;
  render();
  apply.synchronizeUrl(state, push: false);
  apply.listenToHistory((restored) {
    state = selectSeoCollection(
      records: apply.records,
      categoryCount: apply.categoryCount,
      pageSize: apply.pageSize,
      state: restored,
    ).state;
    render();
    apply.synchronizeUrl(state, push: false);
  });
}

typedef _CollectionEventSink = void Function(SeoCollectionAction action);

final class _CollectionLabels {
  const _CollectionLabels({
    required this.interaction,
    required this.search,
    required this.categories,
    required this.all,
    required this.sort,
    required this.newest,
    required this.oldest,
    required this.title,
    required this.previous,
    required this.next,
    required this.results,
    required this.empty,
    required this.page,
  });

  final String interaction;
  final String search;
  final String categories;
  final String all;
  final String sort;
  final String newest;
  final String oldest;
  final String title;
  final String previous;
  final String next;
  final String results;
  final String empty;
  final String page;
}

final class _CollectionPlan {
  const _CollectionPlan({
    required this.root,
    required this.id,
    required this.pageSize,
    required this.initialSort,
    required this.labels,
    required this.categoryNode,
    required this.categories,
    required this.itemsNode,
    required this.items,
    required this.records,
    required this.urlCodec,
  });

  final web.Element root;
  final String id;
  final int pageSize;
  final SeoCollectionSort initialSort;
  final _CollectionLabels labels;
  final web.Element categoryNode;
  final List<String> categories;
  final web.Element itemsNode;
  final List<web.HTMLElement> items;
  final List<SeoCollectionRecord> records;
  final SeoCollectionUrlCodec? urlCodec;
}

final class _CollectionApplyBoundary {
  _CollectionApplyBoundary(this.document, this.plan);

  final web.Document document;
  final _CollectionPlan plan;
  late web.HTMLInputElement _search;
  final List<web.HTMLElement> _categoryButtons = [];
  final List<web.HTMLElement> _sortButtons = [];
  late web.HTMLElement _resultStatus;
  late web.HTMLElement _emptyStatus;
  late web.HTMLElement _pagination;
  late web.HTMLElement _previous;
  late web.HTMLElement _next;
  late web.HTMLElement _pageStatus;

  int get pageSize => plan.pageSize;
  int get categoryCount => plan.categories.length;
  SeoCollectionSort get initialSort => plan.initialSort;
  List<SeoCollectionRecord> get records => plan.records;

  static List<_CollectionApplyBoundary> discover(
    web.Document document, {
    required bool enableUrlSynchronization,
  }) {
    final container = document.getElementById(seoContainerId);
    if (container == null ||
        container.getAttribute(seoDomFirstAttribute) != 'true' ||
        _idCount(document, seoContainerId) != 1) {
      return const [];
    }

    final boundaries = <_CollectionApplyBoundary>[];
    final roots =
        container.querySelectorAll('[data-esen-component="collection"]');
    for (var index = 0; index < roots.length; index++) {
      final node = roots.item(index);
      if (node == null) continue;
      final plan = _validate(
        document,
        container,
        node as web.Element,
        enableUrlSynchronization: enableUrlSynchronization,
      );
      if (plan != null) {
        boundaries.add(_CollectionApplyBoundary(document, plan));
      }
    }
    return boundaries;
  }

  static _CollectionPlan? _validate(
    web.Document document,
    web.Element container,
    web.Element root, {
    required bool enableUrlSynchronization,
  }) {
    if (root.getAttribute('data-esen-enhanced') == 'true' ||
        _hiddenByAncestor(root, container)) {
      return null;
    }
    final urlMarker = root.getAttribute('data-esen-synchronize-url');
    if ((urlMarker != null && urlMarker != 'true') ||
        (urlMarker == 'true' && !enableUrlSynchronization)) {
      return null;
    }
    final id = root.id;
    if (!isValidSeoInteractionId(id) || _idCount(document, id) != 1) {
      return null;
    }
    final children = root.children;
    if (children.length != 2) return null;
    final categoryNode = children.item(0);
    final itemsNode = children.item(1);
    if (categoryNode == null ||
        categoryNode.tagName != 'DIV' ||
        !categoryNode.hasAttribute('data-esen-collection-categories') ||
        !categoryNode.hasAttribute('hidden') ||
        categoryNode.getAttribute('aria-hidden') != 'true' ||
        itemsNode == null ||
        itemsNode.tagName != 'DIV' ||
        !itemsNode.hasAttribute('data-esen-collection-items')) {
      return null;
    }

    final pageSizeValue = root.getAttribute('data-esen-page-size');
    final pageSize =
        pageSizeValue == null || !_decimalIndex.hasMatch(pageSizeValue)
            ? null
            : int.tryParse(pageSizeValue);
    final initialSort = parseSeoCollectionSort(
      root.getAttribute('data-esen-initial-sort') ?? '',
    );
    if (pageSize == null ||
        pageSize < 1 ||
        pageSize > 100 ||
        initialSort == null) {
      return null;
    }

    String? label(String attribute) {
      final value = root.getAttribute(attribute)?.trim();
      return value == null || value.isEmpty || value.length > 200
          ? null
          : value;
    }

    final interactionLabel = label('data-esen-label');
    final searchLabel = label('data-esen-search-label');
    final categoriesLabel = label('data-esen-categories-label');
    final allLabel = label('data-esen-all-label');
    final sortLabel = label('data-esen-sort-label');
    final newestLabel = label('data-esen-newest-label');
    final oldestLabel = label('data-esen-oldest-label');
    final titleLabel = label('data-esen-title-label');
    final previousLabel = label('data-esen-previous-label');
    final nextLabel = label('data-esen-next-label');
    final resultsLabel = label('data-esen-results-label');
    final emptyLabel = label('data-esen-empty-label');
    final pageLabel = label('data-esen-page-label');
    if ([
      interactionLabel,
      searchLabel,
      categoriesLabel,
      allLabel,
      sortLabel,
      newestLabel,
      oldestLabel,
      titleLabel,
      previousLabel,
      nextLabel,
      resultsLabel,
      emptyLabel,
      pageLabel,
    ].any((value) => value == null)) {
      return null;
    }

    final categories = <String>[];
    final normalizedCategories = <String>{};
    final categoryChildren = categoryNode.children;
    if (categoryChildren.length > seoCollectionMaxCategories) return null;
    for (var index = 0; index < categoryChildren.length; index++) {
      final child = categoryChildren.item(index);
      final value = child?.textContent?.trim();
      final normalized = normalizeSeoCollectionText(value ?? '');
      if (child == null ||
          child.tagName != 'SPAN' ||
          child.getAttribute('data-esen-category-index') != '$index' ||
          value == null ||
          value.isEmpty ||
          value.length > 200 ||
          normalized.isEmpty ||
          !normalizedCategories.add(normalized)) {
        return null;
      }
      categories.add(value);
    }

    final itemChildren = itemsNode.children;
    if (itemChildren.length < 2 ||
        itemChildren.length > seoCollectionMaxItems) {
      return null;
    }
    final parsedItems = <({
      int sourceIndex,
      web.HTMLElement element,
      SeoCollectionRecord record,
    })>[];
    final sourceIndexes = <int>{};
    for (var index = 0; index < itemChildren.length; index++) {
      final child = itemChildren.item(index);
      final sourceIndexValue = child?.getAttribute('data-esen-item-order');
      final sourceIndex =
          sourceIndexValue == null || !_decimalIndex.hasMatch(sourceIndexValue)
              ? null
              : int.tryParse(sourceIndexValue);
      if (child == null ||
          child.tagName != 'ARTICLE' ||
          !child.hasAttribute('data-esen-collection-item') ||
          child.id != '$id-item-$index' ||
          _idCount(document, child.id) != 1 ||
          sourceIndex == null ||
          sourceIndex < 0 ||
          sourceIndex >= itemChildren.length ||
          !sourceIndexes.add(sourceIndex)) {
        return null;
      }
      final title = child.getAttribute('data-esen-item-title');
      final search = child.getAttribute('data-esen-item-search');
      final sortValue = child.getAttribute('data-esen-item-sort-key');
      final categoryValue = child.getAttribute('data-esen-item-categories');
      if (title == null ||
          title.isEmpty ||
          title.length > seoCollectionMaxSearchLength ||
          normalizeSeoCollectionText(title) != title ||
          search == null ||
          search.length > seoCollectionMaxSearchLength ||
          normalizeSeoCollectionText(search) != search ||
          sortValue == null ||
          !_signedInteger.hasMatch(sortValue) ||
          categoryValue == null) {
        return null;
      }
      final sortKey = int.tryParse(sortValue);
      final categoryIndexes = _categoryIndexes(
        categoryValue,
        categories.length,
      );
      if (sortKey == null ||
          '$sortKey' != sortValue ||
          !isValidSeoCollectionSortKey(sortKey) ||
          categoryIndexes == null) {
        return null;
      }
      final record = SeoCollectionRecord(
        title: title,
        searchText: search,
        categoryIndexes: categoryIndexes,
        sortKey: sortKey,
      );
      if (record.normalizedSearchText.length > seoCollectionMaxSearchLength) {
        return null;
      }
      parsedItems.add((
        sourceIndex: sourceIndex,
        element: child as web.HTMLElement,
        record: record,
      ));
    }
    parsedItems
        .sort((left, right) => left.sourceIndex.compareTo(right.sourceIndex));
    final items = [for (final item in parsedItems) item.element];
    final records = List<SeoCollectionRecord>.unmodifiable(
      [for (final item in parsedItems) item.record],
    );

    for (final controlId in [
      '$id-search',
      '$id-results',
      '$id-page-status',
    ]) {
      if (_idCount(document, controlId) != 0) return null;
    }

    return _CollectionPlan(
      root: root,
      id: id,
      pageSize: pageSize,
      initialSort: initialSort,
      labels: _CollectionLabels(
        interaction: interactionLabel!,
        search: searchLabel!,
        categories: categoriesLabel!,
        all: allLabel!,
        sort: sortLabel!,
        newest: newestLabel!,
        oldest: oldestLabel!,
        title: titleLabel!,
        previous: previousLabel!,
        next: nextLabel!,
        results: resultsLabel!,
        empty: emptyLabel!,
        page: pageLabel!,
      ),
      categoryNode: categoryNode,
      categories: categories,
      itemsNode: itemsNode,
      items: items,
      records: records,
      urlCodec: urlMarker == 'true'
          ? SeoCollectionUrlCodec(
              interactionId: id,
              categoryLabels: categories,
              initialSort: initialSort,
            )
          : null,
    );
  }

  static List<int>? _categoryIndexes(String value, int categoryCount) {
    if (value.isEmpty) return const [];
    if (!_categoryIndexList.hasMatch(value)) return null;
    final indexes = <int>[];
    final seen = <int>{};
    for (final part in value.split(' ')) {
      final index = int.tryParse(part);
      if (index == null ||
          index < 0 ||
          index >= categoryCount ||
          !seen.add(index)) {
        return null;
      }
      indexes.add(index);
    }
    return indexes;
  }

  static bool _hiddenByAncestor(
    web.Element root,
    web.Element container,
  ) {
    web.Element? current = root;
    while (current != null) {
      final ariaHidden = current.getAttribute('aria-hidden');
      if (current.hasAttribute('inert') ||
          (ariaHidden != null && ariaHidden.trim().toLowerCase() == 'true')) {
        return true;
      }
      if (current == container) return false;
      current = current.parentElement;
    }
    return true;
  }

  static int _idCount(web.Document document, String id) {
    if (id.isEmpty) return 0;
    return document.querySelectorAll('#$id').length;
  }

  void mount(_CollectionEventSink dispatch) {
    final toolbar = document.createElement('div') as web.HTMLElement
      ..className = 'esen-seo-collection-toolbar'
      ..setAttribute('data-esen-collection-toolbar', '');
    plan.root.setAttribute('role', 'region');
    plan.root.setAttribute('aria-label', plan.labels.interaction);

    final searchLabel = document.createElement('label') as web.HTMLElement
      ..className = 'esen-seo-collection-search'
      ..setAttribute('for', '${plan.id}-search');
    searchLabel.appendChild(
      document.createElement('span')..textContent = plan.labels.search,
    );
    _search = document.createElement('input') as web.HTMLInputElement
      ..id = '${plan.id}-search'
      ..type = 'search'
      ..maxLength = seoCollectionMaxSearchLength;
    _search.addEventListener(
      'input',
      ((web.Event _) => dispatch(SeoCollectionSetQuery(_search.value))).toJS,
    );
    searchLabel.appendChild(_search);
    toolbar.appendChild(searchLabel);

    final categoryGroup = document.createElement('div') as web.HTMLElement
      ..className = 'esen-seo-collection-categories'
      ..setAttribute('role', 'group')
      ..setAttribute('aria-label', plan.labels.categories);
    categoryGroup.appendChild(
      document.createElement('span')
        ..className = 'esen-seo-collection-control-label'
        ..textContent = plan.labels.categories,
    );
    final categoryOptions = document.createElement('div') as web.HTMLElement
      ..className = 'esen-seo-collection-category-options';
    void categoryButton(String label, int? categoryIndex) {
      final button = _button(label)
        ..setAttribute('data-esen-collection-category', '');
      button.addEventListener(
        'click',
        ((web.Event _) => dispatch(SeoCollectionSelectCategory(categoryIndex)))
            .toJS,
      );
      categoryOptions.appendChild(button);
      _categoryButtons.add(button);
    }

    categoryButton(plan.labels.all, null);
    for (var index = 0; index < plan.categories.length; index++) {
      categoryButton(plan.categories[index], index);
    }
    categoryGroup.appendChild(categoryOptions);
    toolbar.appendChild(categoryGroup);

    final sortGroup = document.createElement('div') as web.HTMLElement
      ..className = 'esen-seo-collection-sort'
      ..setAttribute('role', 'group')
      ..setAttribute('aria-label', plan.labels.sort);
    sortGroup.appendChild(
      document.createElement('span')
        ..className = 'esen-seo-collection-control-label'
        ..textContent = plan.labels.sort,
    );
    final sortOptions = document.createElement('div') as web.HTMLElement
      ..className = 'esen-seo-collection-sort-options';
    void sortButton(SeoCollectionSort sort, String label) {
      final button = _button(label)
        ..setAttribute(
            'data-esen-collection-sort', seoCollectionSortMarker(sort));
      button.addEventListener(
        'click',
        ((web.Event _) => dispatch(SeoCollectionSetSort(sort))).toJS,
      );
      sortOptions.appendChild(button);
      _sortButtons.add(button);
    }

    sortButton(SeoCollectionSort.newest, plan.labels.newest);
    sortButton(SeoCollectionSort.oldest, plan.labels.oldest);
    sortButton(SeoCollectionSort.title, plan.labels.title);
    sortGroup.appendChild(sortOptions);
    toolbar.appendChild(sortGroup);

    _resultStatus = document.createElement('p') as web.HTMLElement
      ..id = '${plan.id}-results'
      ..className = 'esen-seo-collection-results'
      ..setAttribute('aria-live', 'polite')
      ..setAttribute('aria-atomic', 'true');
    _emptyStatus = document.createElement('p') as web.HTMLElement
      ..className = 'esen-seo-collection-empty'
      ..textContent = plan.labels.empty
      ..setAttribute('hidden', '');

    _pagination = document.createElement('div') as web.HTMLElement
      ..className = 'esen-seo-collection-pagination'
      ..setAttribute('role', 'navigation')
      ..setAttribute('aria-label', plan.labels.page);
    _previous = _button(plan.labels.previous)
      ..setAttribute('data-esen-collection-previous', '')
      ..textContent = '\u2039';
    _next = _button(plan.labels.next)
      ..setAttribute('data-esen-collection-next', '')
      ..textContent = '\u203a';
    _pageStatus = document.createElement('span') as web.HTMLElement
      ..id = '${plan.id}-page-status'
      ..className = 'esen-seo-collection-page';
    _previous.addEventListener(
      'click',
      ((web.Event _) {
        if (!_previous.hasAttribute('disabled')) {
          dispatch(const SeoCollectionPreviousPage());
        }
      }).toJS,
    );
    _next.addEventListener(
      'click',
      ((web.Event _) {
        if (!_next.hasAttribute('disabled')) {
          dispatch(const SeoCollectionNextPage());
        }
      }).toJS,
    );
    _pagination.appendChild(_previous);
    _pagination.appendChild(_pageStatus);
    _pagination.appendChild(_next);

    plan.root.insertBefore(toolbar, plan.categoryNode);
    plan.root.insertBefore(_resultStatus, plan.categoryNode);
    plan.root.insertBefore(_emptyStatus, plan.categoryNode);
    plan.root.appendChild(_pagination);
    plan.root.setAttribute('data-esen-enhanced', 'true');
  }

  web.HTMLElement _button(String label) =>
      document.createElement('button') as web.HTMLElement
        ..setAttribute('type', 'button')
        ..setAttribute('aria-label', label)
        ..textContent = label;

  SeoCollectionState stateFromUrl() {
    final codec = plan.urlCodec;
    if (codec == null) return SeoCollectionState(sort: plan.initialSort);
    try {
      final url = web.URL(web.window.location.href);
      List<String> values(String name) {
        final matches = url.searchParams.getAll(name);
        return matches.length == 1 ? [matches[0].toDart] : const <String>[];
      }

      return codec.decode(
        queryValues: values(codec.queryParameter),
        categoryValues: values(codec.categoryParameter),
        sortValues: values(codec.sortParameter),
        pageValues: values(codec.pageParameter),
      );
    } catch (_) {
      return SeoCollectionState(sort: plan.initialSort);
    }
  }

  void synchronizeUrl(SeoCollectionState state, {required bool push}) {
    final codec = plan.urlCodec;
    if (codec == null) return;
    try {
      final current = web.window.location.href;
      final url = web.URL(current);
      url.searchParams
        ..delete(codec.queryParameter)
        ..delete(codec.categoryParameter)
        ..delete(codec.sortParameter)
        ..delete(codec.pageParameter);
      final values = codec.encode(state);
      if (values.query != null) {
        url.searchParams.set(codec.queryParameter, values.query!);
      }
      if (values.category != null) {
        url.searchParams.set(codec.categoryParameter, values.category!);
      }
      if (values.sort != null) {
        url.searchParams.set(codec.sortParameter, values.sort!);
      }
      if (values.page != null) {
        url.searchParams.set(codec.pageParameter, values.page!);
      }
      if (url.href == current) return;
      if (push) {
        web.window.history.pushState(null, '', url.href);
      } else {
        web.window.history.replaceState(null, '', url.href);
      }
    } catch (_) {
      // URL persistence is optional; interaction remains fully functional.
    }
  }

  void listenToHistory(void Function(SeoCollectionState) restore) {
    if (plan.urlCodec == null) return;
    web.window.addEventListener(
      'popstate',
      ((web.Event _) => restore(stateFromUrl())).toJS,
    );
  }

  void state(
    SeoCollectionState state, {
    required bool previousEnabled,
    required bool nextEnabled,
  }) {
    final snapshot = selectSeoCollection(
      records: plan.records,
      categoryCount: plan.categories.length,
      pageSize: plan.pageSize,
      state: state,
    );
    _search.value = snapshot.state.query;
    for (final index in snapshot.orderedIndices) {
      plan.itemsNode.appendChild(plan.items[index]);
    }
    final visible = snapshot.visibleIndices.toSet();
    for (var index = 0; index < plan.items.length; index++) {
      if (visible.contains(index)) {
        plan.items[index].removeAttribute('hidden');
      } else {
        plan.items[index].setAttribute('hidden', '');
      }
    }
    for (var index = 0; index < _categoryButtons.length; index++) {
      final selected = index == 0
          ? snapshot.state.categoryIndex == null
          : snapshot.state.categoryIndex == index - 1;
      _categoryButtons[index]
          .setAttribute('aria-pressed', selected ? 'true' : 'false');
    }
    for (var index = 0; index < _sortButtons.length; index++) {
      final selected = SeoCollectionSort.values[index] == snapshot.state.sort;
      _sortButtons[index]
          .setAttribute('aria-pressed', selected ? 'true' : 'false');
    }
    _resultStatus.textContent = '${snapshot.matchCount} ${plan.labels.results}';
    if (snapshot.matchCount == 0) {
      _emptyStatus.removeAttribute('hidden');
    } else {
      _emptyStatus.setAttribute('hidden', '');
    }
    if (snapshot.pageCount <= 1) {
      _pagination.setAttribute('hidden', '');
    } else {
      _pagination.removeAttribute('hidden');
    }
    _disabled(_previous, !previousEnabled);
    _disabled(_next, !nextEnabled);
    _pageStatus.textContent = snapshot.pageCount == 0
        ? '${plan.labels.page} 0 / 0'
        : '${plan.labels.page} ${snapshot.state.page + 1} / '
            '${snapshot.pageCount}';
  }

  void _disabled(web.HTMLElement control, bool disabled) {
    if (disabled) {
      control.setAttribute('disabled', '');
      control.setAttribute('aria-disabled', 'true');
    } else {
      control.removeAttribute('disabled');
      control.setAttribute('aria-disabled', 'false');
    }
  }
}

final RegExp _decimalIndex = RegExp(r'^(0|[1-9][0-9]*)$');
final RegExp _signedInteger = RegExp(r'^-?(0|[1-9][0-9]{0,15})$');
final RegExp _categoryIndexList =
    RegExp(r'^(0|[1-9][0-9]*)( (0|[1-9][0-9]*))*$');
