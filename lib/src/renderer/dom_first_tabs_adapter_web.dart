import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../components/seo_component_format.dart';
import '../components/seo_tabs_transition.dart';
import 'seo_container.dart';

/// Enhances every valid tab group in the package-owned DOM-first container.
///
/// The whole control is validated before [_TabsApplyBoundary] performs the
/// first mutation. Invalid or ambiguous markup therefore remains complete,
/// readable HTML instead of becoming a partially initialized control.
void enhanceSeoDomFirstTabs({
  SeoTabsTransition transition = transitionSeoTabs,
}) {
  for (final apply in _TabsApplyBoundary.discover(web.document)) {
    _enhanceTabs(apply, transition);
  }
}

void _enhanceTabs(
  _TabsApplyBoundary apply,
  SeoTabsTransition transition,
) {
  var state = initialSeoTabsState(
    count: apply.count,
    index: apply.initialIndex,
  );

  void dispatch(SeoTabsAction action, {required bool moveFocus}) {
    state = applySeoTabsTransition(transition, state, action);
    apply.state(state, moveFocus: moveFocus);
  }

  apply.mount((index, event) {
    final action = switch (event) {
      _TabsControlEvent.select => SeoTabsSelect(index),
      _TabsControlEvent.next => const SeoTabsNext(),
      _TabsControlEvent.previous => const SeoTabsPrevious(),
      _TabsControlEvent.first => const SeoTabsFirst(),
      _TabsControlEvent.last => const SeoTabsLast(),
    };
    dispatch(action, moveFocus: event != _TabsControlEvent.select);
  });
  apply.state(state, moveFocus: false);
}

enum _TabsControlEvent { select, next, previous, first, last }

typedef _TabsEventSink = void Function(int index, _TabsControlEvent event);

final class _TabsPlan {
  const _TabsPlan({
    required this.root,
    required this.id,
    required this.label,
    required this.initialIndex,
    required this.panels,
    required this.headings,
  });

  final web.Element root;
  final String id;
  final String label;
  final int initialIndex;
  final List<web.Element> panels;
  final List<web.HTMLElement> headings;
}

final class _TabsApplyBoundary {
  _TabsApplyBoundary(this.document, this.plan);

  final web.Document document;
  final _TabsPlan plan;
  final List<web.HTMLElement> _tabs = [];

  int get count => plan.panels.length;
  int get initialIndex => plan.initialIndex;

  static List<_TabsApplyBoundary> discover(web.Document document) {
    final container = document.getElementById(seoContainerId);
    if (container == null ||
        container.getAttribute(seoDomFirstAttribute) != 'true' ||
        _idCount(document, seoContainerId) != 1) {
      return const [];
    }

    final boundaries = <_TabsApplyBoundary>[];
    final roots = container.querySelectorAll('[data-esen-component="tabs"]');
    for (var index = 0; index < roots.length; index++) {
      final node = roots.item(index);
      if (node == null) continue;
      final plan = _validate(document, container, node as web.Element);
      if (plan != null) boundaries.add(_TabsApplyBoundary(document, plan));
    }
    return boundaries;
  }

  static _TabsPlan? _validate(
    web.Document document,
    web.Element container,
    web.Element root,
  ) {
    if (root.getAttribute('data-esen-enhanced') == 'true') return null;
    if (_hiddenByAncestor(root, container)) return null;
    final id = root.id;
    if (!isValidSeoInteractionId(id) || _idCount(document, id) != 1) {
      return null;
    }

    final panels = <web.Element>[];
    final headings = <web.HTMLElement>[];
    final panelIds = <String>{};
    final children = root.children;
    for (var index = 0; index < children.length; index++) {
      final child = children.item(index);
      if (child == null ||
          child.tagName != 'SECTION' ||
          !child.hasAttribute('data-esen-tab-panel')) {
        return null;
      }
      final expectedPanelId = '$id-panel-$index';
      final expectedTabId = '$id-tab-$index';
      final heading = child.firstElementChild;
      if (child.id != expectedPanelId ||
          !panelIds.add(child.id) ||
          _idCount(document, child.id) != 1 ||
          _idCount(document, expectedTabId) != 0 ||
          heading == null ||
          !_headingTag.hasMatch(heading.tagName) ||
          (heading.textContent ?? '').trim().isEmpty) {
        return null;
      }
      panels.add(child);
      headings.add(heading as web.HTMLElement);
    }
    if (panels.isEmpty) return null;

    final initial = root.getAttribute('data-esen-initial-index');
    if (initial == null || !_decimalIndex.hasMatch(initial)) return null;
    final initialIndex = int.tryParse(initial);
    if (initialIndex == null ||
        initialIndex < 0 ||
        initialIndex >= panels.length) {
      return null;
    }

    final rawLabel = root.getAttribute('data-esen-label');
    return _TabsPlan(
      root: root,
      id: id,
      label: rawLabel == null || rawLabel.trim().isEmpty ? 'Tabs' : rawLabel,
      initialIndex: initialIndex,
      panels: panels,
      headings: headings,
    );
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
    final elements = document.querySelectorAll('[id]');
    var count = 0;
    for (var index = 0; index < elements.length; index++) {
      final element = elements.item(index);
      if (element != null && (element as web.Element).id == id) count++;
    }
    return count;
  }

  void mount(_TabsEventSink dispatch) {
    final tablist = document.createElement('div');
    tablist.className = 'esen-seo-tab-list';
    tablist.setAttribute('role', 'tablist');
    tablist.setAttribute('aria-label', plan.label);

    for (var index = 0; index < plan.panels.length; index++) {
      final panel = plan.panels[index];
      final heading = plan.headings[index];
      final tab = document.createElement('button') as web.HTMLElement;
      tab.setAttribute('type', 'button');
      tab.id = '${plan.id}-tab-$index';
      tab.className = 'esen-seo-tab';
      tab.textContent = heading.textContent ?? '';
      tab.setAttribute('role', 'tab');
      tab.setAttribute('aria-controls', panel.id);
      tab.addEventListener(
        'click',
        ((web.Event _) => dispatch(index, _TabsControlEvent.select)).toJS,
      );
      tab.addEventListener(
        'keydown',
        ((web.Event rawEvent) {
          final event = rawEvent as web.KeyboardEvent;
          final action = switch (event.key) {
            'ArrowRight' => _TabsControlEvent.next,
            'ArrowLeft' => _TabsControlEvent.previous,
            'Home' => _TabsControlEvent.first,
            'End' => _TabsControlEvent.last,
            _ => null,
          };
          if (action == null) return;
          event.preventDefault();
          dispatch(index, action);
        }).toJS,
      );
      tablist.appendChild(tab);
      _tabs.add(tab);

      panel.setAttribute('role', 'tabpanel');
      panel.setAttribute('aria-labelledby', tab.id);
      heading.setAttribute('hidden', '');
    }

    plan.root.insertBefore(tablist, plan.panels.first);
    plan.root.setAttribute('data-esen-enhanced', 'true');
  }

  void state(SeoTabsState state, {required bool moveFocus}) {
    for (var index = 0; index < _tabs.length; index++) {
      final selected = index == state.index;
      final tab = _tabs[index];
      final panel = plan.panels[index];
      tab.setAttribute('aria-selected', selected ? 'true' : 'false');
      tab.setAttribute('tabindex', selected ? '0' : '-1');
      if (selected) {
        panel.removeAttribute('hidden');
      } else {
        panel.setAttribute('hidden', '');
      }
    }
    if (moveFocus) _tabs[state.index].focus();
  }
}

final RegExp _headingTag = RegExp(r'^H[1-6]$');
final RegExp _decimalIndex = RegExp(r'^(0|[1-9][0-9]*)$');
