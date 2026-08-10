/// Trusted progressive-enhancement assets for semantic components.
library;

import 'html_renderer.dart';
import 'seo_container.dart';
import 'seo_stylesheet.dart';

/// Marks the package-owned interaction runtime in a generated document.
const String seoInteractionScriptAttribute = 'data-esen-seo-interactions';

/// Structural styles for controls created by [seoInteractionRuntime].
///
/// The rules are scoped to an explicitly enhanced tabs root. They use
/// inherited colors so custom and generated theme stylesheets keep control of
/// the palette.
const String seoInteractionStylesheet = '''
#$seoContainerId [data-esen-component="tabs"][data-esen-enhanced="true"]>.esen-seo-tab-list{display:flex;flex-wrap:wrap;gap:.5rem;border-bottom:1px solid currentColor;margin-bottom:1rem}
#$seoContainerId [data-esen-component="tabs"]>.esen-seo-tab-list>.esen-seo-tab{font:inherit;color:inherit;background:transparent;border:0;border-bottom:2px solid transparent;padding:.5rem .75rem;cursor:pointer}
#$seoContainerId [data-esen-component="tabs"]>.esen-seo-tab-list>.esen-seo-tab[aria-selected="true"]{border-bottom-color:currentColor;font-weight:600}
#$seoContainerId [data-esen-component="tabs"]>.esen-seo-tab-list>.esen-seo-tab:focus-visible{outline:2px solid currentColor;outline-offset:2px}
#$seoContainerId [data-esen-component="tabs"][data-esen-enhanced="true"]>section[data-esen-tab-panel][hidden]{display:none}
''';

/// Package-owned JavaScript that progressively enhances marked tab groups in
/// the package's visible semantic container.
///
/// It constructs controls with DOM APIs and copies labels with `textContent`.
/// User data is never parsed as HTML, selectors or executable source.
const String seoInteractionRuntime = r'''
(function () {
  'use strict';

  var rootSelector = '[data-esen-component="tabs"]';

  function directPanels(root) {
    return Array.prototype.filter.call(root.children, function (child) {
      return child.tagName === 'SECTION' &&
          child.hasAttribute('data-esen-tab-panel');
    });
  }

  function idCount(id) {
    if (!id) return 0;
    var matches = document.querySelectorAll('[id]');
    var count = 0;
    for (var index = 0; index < matches.length; index += 1) {
      if (matches[index].id === id) count += 1;
    }
    return count;
  }

  function hiddenByAncestor(element) {
    var current = element;
    while (current) {
      var ariaHidden = current.getAttribute('aria-hidden');
      if (current.hasAttribute('inert') ||
          (ariaHidden && ariaHidden.toLowerCase() === 'true')) {
        return true;
      }
      current = current.parentElement;
    }
    return false;
  }

  function enhance(root) {
    if (root.getAttribute('data-esen-enhanced') === 'true') return;
    var shell = root.closest(
        '#esen-seo-content[data-esen-seo-shell="visible"]');
    if (!shell || idCount(shell.id) !== 1) return;
    if (hiddenByAncestor(root)) return;
    if (idCount(root.id) !== 1) return;

    var panels = directPanels(root);
    if (!panels.length || panels.length !== root.children.length) return;

    var headings = [];
    var ids = Object.create(null);
    var valid = panels.every(function (panel, index) {
      var heading = panel.firstElementChild;
      var headingTag = heading ? heading.tagName : '';
      var headingText = heading ? heading.textContent || '' : '';
      if (idCount(panel.id) !== 1 || ids[panel.id] ||
          idCount(root.id + '-tab-' + index) !== 0 ||
          !/^H[1-6]$/.test(headingTag) || !headingText.trim()) {
        return false;
      }
      ids[panel.id] = true;
      headings.push(heading);
      return true;
    });
    if (!valid) return;

    var tablist = document.createElement('div');
    tablist.className = 'esen-seo-tab-list';
    tablist.setAttribute('role', 'tablist');
    tablist.setAttribute(
        'aria-label', root.getAttribute('data-esen-label') || 'Tabs');

    var tabs = panels.map(function (panel, index) {
      var tab = document.createElement('button');
      tab.type = 'button';
      tab.id = root.id + '-tab-' + index;
      tab.className = 'esen-seo-tab';
      tab.textContent = headings[index].textContent || '';
      tab.setAttribute('role', 'tab');
      tab.setAttribute('aria-controls', panel.id);
      tablist.appendChild(tab);

      panel.setAttribute('role', 'tabpanel');
      panel.setAttribute('aria-labelledby', tab.id);
      headings[index].hidden = true;
      return tab;
    });

    function activate(index, moveFocus) {
      tabs.forEach(function (tab, tabIndex) {
        var selected = tabIndex === index;
        tab.setAttribute('aria-selected', selected ? 'true' : 'false');
        tab.tabIndex = selected ? 0 : -1;
        panels[tabIndex].hidden = !selected;
      });
      if (moveFocus) tabs[index].focus();
    }

    tabs.forEach(function (tab, index) {
      tab.addEventListener('click', function () {
        activate(index, false);
      });
      tab.addEventListener('keydown', function (event) {
        var target = null;
        if (event.key === 'ArrowRight') {
          target = (index + 1) % tabs.length;
        } else if (event.key === 'ArrowLeft') {
          target = (index - 1 + tabs.length) % tabs.length;
        } else if (event.key === 'Home') {
          target = 0;
        } else if (event.key === 'End') {
          target = tabs.length - 1;
        }
        if (target === null) return;
        event.preventDefault();
        activate(target, true);
      });
    });

    root.insertBefore(tablist, root.firstChild);
    root.setAttribute('data-esen-enhanced', 'true');
    var initial = Number.parseInt(
        root.getAttribute('data-esen-initial-index') || '0', 10);
    if (!Number.isFinite(initial) || initial < 0 || initial >= tabs.length) {
      initial = 0;
    }
    activate(initial, false);
  }

  function enhanceAll(scope) {
    var root = scope || document;
    if (root.matches && root.matches(rootSelector)) enhance(root);
    Array.prototype.forEach.call(
        root.querySelectorAll(rootSelector), enhance);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', function () {
      enhanceAll(document);
    }, {once: true});
  } else {
    enhanceAll(document);
  }
})();
''';

final RegExp _scriptClose = RegExp(r'</\s*script', caseSensitive: false);

/// Wraps the trusted runtime in an inline script tag.
///
/// [nonce] is optional. When supplied it is escaped as an HTML attribute so
/// callers can satisfy a nonce-based Content Security Policy.
String seoInteractionScriptHtml({String? nonce}) {
  if (_scriptClose.hasMatch(seoInteractionRuntime)) {
    throw StateError('The interaction runtime contains a script close tag.');
  }
  final value = nonce?.trim();
  final nonceAttribute = value == null || value.isEmpty
      ? ''
      : ' nonce="${HtmlRenderer.escapeAttribute(value)}"';
  return '<script $seoInteractionScriptAttribute$nonceAttribute>'
      '$seoInteractionRuntime</script>';
}

/// Wraps the package-owned interaction CSS in a managed style tag.
String seoInteractionStyleHtml({String? nonce}) =>
    seoStyleTagHtml(seoInteractionStylesheet, nonce: nonce);
