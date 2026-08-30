import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../components/seo_component_format.dart';
import '../components/seo_tabs_transition.dart';
import 'dom_first_adapter_web.dart';

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
    index: apply.fragmentIndex ?? apply.initialIndex,
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
    required this.placeholder,
  });

  final web.Element root;
  final String id;
  final String label;
  final int initialIndex;
  final List<web.Element> panels;
  final List<web.HTMLElement> headings;
  final web.Element? placeholder;
}

final class _TabsApplyBoundary {
  _TabsApplyBoundary(this.document, this.plan);

  final web.Document document;
  final _TabsPlan plan;
  final List<web.HTMLElement> _tabs = [];

  int get count => plan.panels.length;
  int get initialIndex => plan.initialIndex;

  int? get fragmentIndex {
    final target = domFirstFragmentTarget(document, plan.root);
    if (target == null) return null;
    for (var index = 0; index < plan.panels.length; index++) {
      final panel = plan.panels[index];
      if (panel == target || panel.contains(target)) return index;
    }
    return null;
  }

  static List<_TabsApplyBoundary> discover(web.Document document) {
    final container = domFirstContainer(document);
    if (container == null) return const [];

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
    if (domFirstHiddenByAncestor(root, container)) return null;
    final id = root.id;
    if (!isValidSeoInteractionId(id) || domFirstIdCount(document, id) != 1) {
      return null;
    }

    final panels = <web.Element>[];
    final headings = <web.HTMLElement>[];
    final panelIds = <String>{};
    final children = root.children;
    final firstChild = children.item(0);
    final placeholder = firstChild != null &&
            firstChild.hasAttribute('data-esen-prepaint-placeholder')
        ? firstChild
        : null;
    final panelOffset = placeholder == null ? 0 : 1;
    for (var index = panelOffset; index < children.length; index++) {
      final child = children.item(index);
      final panelIndex = index - panelOffset;
      if (child == null ||
          child.tagName != 'SECTION' ||
          !child.hasAttribute('data-esen-tab-panel')) {
        return null;
      }
      final expectedPanelId = '$id-panel-$panelIndex';
      final expectedTabId = '$id-tab-$panelIndex';
      final heading = child.firstElementChild;
      if (child.id != expectedPanelId ||
          !panelIds.add(child.id) ||
          domFirstIdCount(document, child.id) != 1 ||
          domFirstIdCount(document, expectedTabId) != 0 ||
          heading == null ||
          !domFirstHeadingTag.hasMatch(heading.tagName) ||
          (heading.textContent ?? '').trim().isEmpty) {
        return null;
      }
      panels.add(child);
      headings.add(heading as web.HTMLElement);
    }
    if (panels.isEmpty) return null;

    final initialIndex = domFirstInitialIndex(root, panels.length);
    if (initialIndex == null) return null;
    if (!_validStableLayout(
      root: root,
      placeholder: placeholder,
      panels: panels,
      headings: headings,
      initialIndex: initialIndex,
    )) {
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
      placeholder: placeholder,
    );
  }

  static bool _validStableLayout({
    required web.Element root,
    required web.Element? placeholder,
    required List<web.Element> panels,
    required List<web.HTMLElement> headings,
    required int initialIndex,
  }) {
    final stable = root.getAttribute('data-esen-layout-stable') == 'true';
    if (!stable) return placeholder == null;
    if (placeholder == null ||
        placeholder.tagName != 'DIV' ||
        placeholder.getAttribute('data-esen-prepaint-placeholder') != 'tabs' ||
        !placeholder.classList.contains('esen-seo-tab-list') ||
        !placeholder.hasAttribute('hidden') ||
        placeholder.getAttribute('aria-hidden') != 'true' ||
        placeholder.children.length != panels.length) {
      return false;
    }
    for (var index = 0; index < panels.length; index++) {
      final item = placeholder.children.item(index);
      final selected = index == initialIndex;
      if (item == null ||
          item.tagName != 'SPAN' ||
          !item.classList.contains('esen-seo-tab') ||
          item.textContent != headings[index].textContent ||
          item.getAttribute('data-esen-placeholder-selected') !=
              (selected ? 'true' : null) ||
          panels[index].getAttribute('data-esen-initial-active') !=
              (selected ? 'true' : null)) {
        return false;
      }
    }
    return true;
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

    final placeholder = plan.placeholder;
    if (placeholder == null) {
      plan.root.insertBefore(tablist, plan.panels.first);
    } else {
      plan.root.replaceChild(tablist, placeholder);
    }
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
