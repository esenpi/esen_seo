/// Trusted progressive-enhancement assets for semantic components.
library;

import 'html_renderer.dart';
import 'seo_container.dart';
import 'seo_stylesheet.dart';

/// Marks the package-owned interaction runtime in a generated document.
const String seoInteractionScriptAttribute = 'data-esen-seo-interactions';

/// Structural styles for controls created by [seoInteractionRuntime].
///
/// The rules are scoped to explicitly marked component roots. They use
/// inherited colors so custom and generated theme stylesheets keep control of
/// the palette.
const String seoInteractionStylesheet = '''
#$seoContainerId [data-esen-component="tabs"][data-esen-enhanced="true"]>.esen-seo-tab-list{display:flex;flex-wrap:wrap;gap:.5rem;border-bottom:1px solid currentColor;margin-bottom:1rem}
#$seoContainerId [data-esen-component="tabs"]>.esen-seo-tab-list>.esen-seo-tab{font:inherit;color:inherit;background:transparent;border:0;border-bottom:2px solid transparent;padding:.5rem .75rem;cursor:pointer}
#$seoContainerId [data-esen-component="tabs"]>.esen-seo-tab-list>.esen-seo-tab[aria-selected="true"]{border-bottom-color:currentColor;font-weight:600}
#$seoContainerId [data-esen-component="tabs"]>.esen-seo-tab-list>.esen-seo-tab:focus-visible{outline:2px solid currentColor;outline-offset:2px}
#$seoContainerId [data-esen-component="tabs"][data-esen-enhanced="true"]>section[data-esen-tab-panel][hidden]{display:none}
#$seoContainerId [data-esen-component="nav-menu"] [data-esen-nav-toggle]{font:inherit;color:inherit;background:transparent;border:0;padding:.25rem;cursor:pointer}
#$seoContainerId [data-esen-component="nav-menu"] [data-esen-nav-toggle]:focus-visible{outline:2px solid currentColor;outline-offset:2px}
#$seoContainerId [data-esen-component="nav-menu"] .esen-seo-nav-toggle-label{padding:.25rem 0}
#$seoContainerId [data-esen-component="nav-menu"] .esen-seo-nav-toggle-indicator{display:inline-block;margin-inline-start:.35rem}
#$seoContainerId [data-esen-component="nav-menu"] .esen-seo-nav-toggle-icon .esen-seo-nav-toggle-indicator{margin-inline-start:0}
#$seoContainerId [data-esen-component="nav-menu"][data-esen-enhanced="true"] [data-esen-nav-submenu][hidden],#$seoContainerId [data-esen-component="nav-menu"][data-esen-enhanced="true"] [data-esen-nav-branch]>span[hidden]{display:none}
''';

/// Package-owned JavaScript that progressively enhances marked components in
/// the package's visible semantic container.
///
/// It constructs controls with DOM APIs and copies labels with `textContent`.
/// User data is never parsed as HTML, selectors or executable source.
const String seoInteractionRuntime = r'''
(function () {
  'use strict';

  var tabsSelector = '[data-esen-component="tabs"]';
  var navSelector = '[data-esen-component="nav-menu"]';

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

  function canEnhance(root) {
    if (root.getAttribute('data-esen-enhanced') === 'true') return;
    var shell = root.closest(
        '#esen-seo-content[data-esen-seo-shell="visible"]');
    return !!shell && idCount(shell.id) === 1 &&
        !hiddenByAncestor(root) && idCount(root.id) === 1;
  }

  function enhanceTabs(root) {
    if (!canEnhance(root)) return;

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

  function enhanceNav(root) {
    if (!canEnhance(root) || root.children.length !== 1) return;
    var rootList = root.firstElementChild;
    if (!rootList || rootList.tagName !== 'UL' ||
        !rootList.hasAttribute('data-esen-nav-root-list')) return;

    var branches = root.querySelectorAll('[data-esen-nav-branch]');
    var submenus = root.querySelectorAll('[data-esen-nav-submenu]');
    var nestedLists = root.querySelectorAll('li > ul');
    if (!branches.length || submenus.length !== branches.length ||
        nestedLists.length !== branches.length) return;

    var ids = Object.create(null);
    var entries = [];
    var valid = Array.prototype.every.call(branches, function (branch) {
      if (branch.tagName !== 'LI' || branch.children.length !== 2) {
        return false;
      }
      var label = branch.children[0];
      var submenu = branch.children[1];
      var labelText = label.textContent || '';
      var linked = label.tagName === 'A';
      var toggleId = submenu.id + '-toggle';
      if ((!linked && label.tagName !== 'SPAN') || !labelText.trim() ||
          submenu.tagName !== 'UL' ||
          !submenu.hasAttribute('data-esen-nav-submenu') ||
          idCount(submenu.id) !== 1 || ids[submenu.id] ||
          idCount(toggleId) !== 0) {
        return false;
      }
      ids[submenu.id] = true;
      entries.push({
        branch: branch,
        label: label,
        labelText: labelText,
        linked: linked,
        submenu: submenu,
        toggleId: toggleId
      });
      return true;
    });
    if (!valid) return;

    entries.forEach(function (entry) {
      var button = document.createElement('button');
      button.type = 'button';
      button.id = entry.toggleId;
      button.className = entry.linked
          ? 'esen-seo-nav-toggle esen-seo-nav-toggle-icon'
          : 'esen-seo-nav-toggle esen-seo-nav-toggle-label';
      button.setAttribute('data-esen-nav-toggle', '');
      button.setAttribute('aria-controls', entry.submenu.id);
      button.setAttribute('aria-expanded', 'false');

      if (entry.linked) {
        button.setAttribute('aria-label', entry.labelText);
      } else {
        button.appendChild(document.createTextNode(entry.labelText));
        entry.label.hidden = true;
      }
      var indicator = document.createElement('span');
      indicator.className = 'esen-seo-nav-toggle-indicator';
      indicator.setAttribute('aria-hidden', 'true');
      button.appendChild(indicator);

      function setOpen(open, moveFocus) {
        button.setAttribute('aria-expanded', open ? 'true' : 'false');
        entry.submenu.hidden = !open;
        indicator.textContent = open ? '\u25BE' : '\u25B8';
        if (moveFocus) button.focus();
      }

      button.addEventListener('click', function () {
        setOpen(button.getAttribute('aria-expanded') !== 'true', false);
      });
      button.addEventListener('keydown', function (event) {
        if (event.key === 'Enter' || event.key === ' ') {
          event.preventDefault();
          event.stopPropagation();
          if (!event.repeat) {
            setOpen(button.getAttribute('aria-expanded') !== 'true', false);
          }
          return;
        }
        if (event.key !== 'Escape' ||
            button.getAttribute('aria-expanded') !== 'true') return;
        event.preventDefault();
        event.stopPropagation();
        setOpen(false, true);
      });
      entry.submenu.addEventListener('keydown', function (event) {
        if (event.key !== 'Escape') return;
        event.preventDefault();
        event.stopPropagation();
        setOpen(false, true);
      });

      entry.branch.insertBefore(button, entry.submenu);
      setOpen(false, false);
    });
    root.setAttribute('data-esen-enhanced', 'true');
  }

  function enhanceSelector(scope, selector, callback) {
    if (scope.matches && scope.matches(selector)) callback(scope);
    Array.prototype.forEach.call(
        scope.querySelectorAll(selector), callback);
  }

  function enhanceAll(scope) {
    var root = scope || document;
    enhanceSelector(root, tabsSelector, enhanceTabs);
    enhanceSelector(root, navSelector, enhanceNav);
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
