/// Trusted progressive-enhancement assets for semantic components.
library;

import '../components/seo_component_format.dart';
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
#$seoContainerId [data-esen-component="tabs"]>.esen-seo-tab-list>.esen-seo-tab{display:inline-flex;box-sizing:border-box;align-items:center;font:inherit;color:inherit;background:transparent;border:0;border-bottom:2px solid transparent;padding:.5rem .75rem;cursor:pointer}
#$seoContainerId [data-esen-component="tabs"]>.esen-seo-tab-list>.esen-seo-tab[aria-selected="true"],#$seoContainerId [data-esen-component="tabs"]>.esen-seo-tab-list>.esen-seo-tab[data-esen-placeholder-selected="true"]{border-bottom-color:currentColor;font-weight:600}
#$seoContainerId [data-esen-component="tabs"]>.esen-seo-tab-list>.esen-seo-tab:focus-visible{outline:2px solid currentColor;outline-offset:2px}
#$seoContainerId [data-esen-component="tabs"][data-esen-enhanced="true"]>section[data-esen-tab-panel][hidden]{display:none}
#$seoContainerId [data-esen-component="tabs"]>[data-esen-prepaint-placeholder="tabs"][hidden]{display:none!important}
html[data-esen-interaction-pending] #$seoContainerId [data-esen-component="tabs"][data-esen-layout-stable="true"]:not([data-esen-enhanced="true"])>[data-esen-prepaint-placeholder="tabs"][hidden]{display:flex!important;flex-wrap:wrap;gap:.5rem;border-bottom:1px solid currentColor;margin-bottom:1rem}
html[data-esen-interaction-pending] #$seoContainerId [data-esen-component="tabs"][data-esen-layout-stable="true"]:not([data-esen-enhanced="true"])>section[data-esen-tab-panel]:not([data-esen-initial-active="true"]){display:none}
html[data-esen-interaction-pending] #$seoContainerId [data-esen-component="tabs"][data-esen-layout-stable="true"]:not([data-esen-enhanced="true"])>section[data-esen-tab-panel][data-esen-initial-active="true"]>:first-child{display:none}
#$seoContainerId [data-esen-component="carousel"]>.esen-seo-carousel-controls{display:flex;align-items:center;justify-content:center;gap:.5rem;margin-block:.75rem}
#$seoContainerId [data-esen-component="carousel"] [data-esen-carousel-control],#$seoContainerId [data-esen-component="carousel"] .esen-seo-carousel-control-placeholder{display:inline-flex;box-sizing:border-box;align-items:center;justify-content:center;font:inherit;color:inherit;background:transparent;border:1px solid currentColor;border-radius:4px;width:2.5rem;min-width:2.5rem;height:2.5rem;min-height:2.5rem;padding:0}
#$seoContainerId [data-esen-component="carousel"] [data-esen-carousel-control]{cursor:pointer}
#$seoContainerId [data-esen-component="carousel"] [data-esen-carousel-control][aria-disabled="true"]{opacity:.4;cursor:default}
#$seoContainerId [data-esen-component="carousel"] [data-esen-carousel-control]:focus-visible{outline:2px solid currentColor;outline-offset:2px}
#$seoContainerId [data-esen-component="carousel"] .esen-seo-carousel-status{display:inline-block;min-width:4rem;text-align:center}
#$seoContainerId [data-esen-component="carousel"][data-esen-enhanced="true"]>section[data-esen-carousel-slide][hidden]{display:none}
#$seoContainerId [data-esen-component="carousel"] .esen-seo-carousel-control-placeholder[data-esen-placeholder-disabled="true"]{opacity:.4}
#$seoContainerId [data-esen-component="carousel"]>[data-esen-prepaint-placeholder="carousel"][hidden]{display:none!important}
html[data-esen-interaction-pending] #$seoContainerId [data-esen-component="carousel"][data-esen-layout-stable="true"]:not([data-esen-enhanced="true"])>[data-esen-prepaint-placeholder="carousel"][hidden]{display:flex!important}
html[data-esen-interaction-pending] #$seoContainerId [data-esen-component="carousel"][data-esen-layout-stable="true"]:not([data-esen-enhanced="true"])>section[data-esen-carousel-slide]:not([data-esen-initial-active="true"]){display:none}
#$seoContainerId [data-esen-component="stepper"]>[data-esen-step-list]{list-style:none;padding:0}
#$seoContainerId [data-esen-component="stepper"] .esen-seo-step-button{display:block;box-sizing:border-box;font:inherit;color:inherit;background:transparent;border:0;padding:.5rem 0;cursor:pointer;text-align:start;width:100%;overflow-wrap:anywhere}
#$seoContainerId [data-esen-component="stepper"] [data-esen-step-button][aria-current="step"]{font-weight:600}
#$seoContainerId [data-esen-component="stepper"] [data-esen-step-button]:focus-visible{outline:2px solid currentColor;outline-offset:2px}
#$seoContainerId [data-esen-component="stepper"] .esen-seo-stepper-controls{display:flex;align-items:center;justify-content:space-between;gap:.5rem;margin-block:.75rem}
#$seoContainerId [data-esen-component="stepper"] [data-esen-stepper-control],#$seoContainerId [data-esen-component="stepper"] .esen-seo-stepper-control-placeholder{display:inline-flex;box-sizing:border-box;align-items:center;justify-content:center;font:inherit;color:inherit;background:transparent;border:1px solid currentColor;border-radius:4px;min-height:2.5rem;padding:.5rem .75rem;flex:1;min-width:0;overflow-wrap:anywhere}
#$seoContainerId [data-esen-component="stepper"] [data-esen-stepper-control]{cursor:pointer}
#$seoContainerId [data-esen-component="stepper"] [data-esen-stepper-control][aria-disabled="true"]{opacity:.4;cursor:default}
#$seoContainerId [data-esen-component="stepper"] [data-esen-stepper-control]:focus-visible{outline:2px solid currentColor;outline-offset:2px}
#$seoContainerId [data-esen-component="stepper"] .esen-seo-stepper-status{display:inline-block;min-width:6rem;text-align:center}
#$seoContainerId [data-esen-component="stepper"][data-esen-enhanced="true"] [data-esen-step-panel][hidden]{display:none}
#$seoContainerId [data-esen-component="stepper"] .esen-seo-stepper-control-placeholder[data-esen-placeholder-disabled="true"]{opacity:.4}
#$seoContainerId [data-esen-component="stepper"]>[data-esen-prepaint-placeholder="stepper"][hidden],#$seoContainerId [data-esen-component="stepper"] [data-esen-prepaint-placeholder="stepper-button"][hidden]{display:none!important}
html[data-esen-interaction-pending] #$seoContainerId [data-esen-component="stepper"][data-esen-layout-stable="true"]:not([data-esen-enhanced="true"])>[data-esen-prepaint-placeholder="stepper"][hidden]{display:flex!important}
html[data-esen-interaction-pending] #$seoContainerId [data-esen-component="stepper"][data-esen-layout-stable="true"]:not([data-esen-enhanced="true"])>[data-esen-step-list]>[data-esen-step]>[data-esen-prepaint-placeholder="stepper-button"][hidden]{display:block!important}
html[data-esen-interaction-pending] #$seoContainerId [data-esen-component="stepper"][data-esen-layout-stable="true"]:not([data-esen-enhanced="true"])>[data-esen-step-list]>[data-esen-step]>[data-esen-step-heading]{display:none}
html[data-esen-interaction-pending] #$seoContainerId [data-esen-component="stepper"][data-esen-layout-stable="true"]:not([data-esen-enhanced="true"])>[data-esen-step-list]>[data-esen-step]>[data-esen-step-panel]:not([data-esen-initial-active="true"]){display:none}
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
  var carouselSelector = '[data-esen-component="carousel"]';
  var stepperSelector = '[data-esen-component="stepper"]';
  var navSelector = '[data-esen-component="nav-menu"]';

  function directPanels(root) {
    return Array.prototype.filter.call(root.children, function (child) {
      return child.tagName === 'SECTION' &&
          child.hasAttribute('data-esen-tab-panel');
    });
  }

  function directCarouselSlides(root) {
    return Array.prototype.filter.call(root.children, function (child) {
      return child.tagName === 'SECTION' &&
          child.hasAttribute('data-esen-carousel-slide');
    });
  }

  function directStepperSteps(list) {
    return Array.prototype.filter.call(list.children, function (child) {
      return child.tagName === 'LI' && child.hasAttribute('data-esen-step');
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

    var placeholder = root.firstElementChild &&
        root.firstElementChild.hasAttribute('data-esen-prepaint-placeholder')
        ? root.firstElementChild : null;
    var stableLayout =
        root.getAttribute('data-esen-layout-stable') === 'true';
    if (!!placeholder !== stableLayout) return;
    var panels = directPanels(root);
    if (!panels.length ||
        panels.length + (placeholder ? 1 : 0) !== root.children.length) return;

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

    var initialValue = root.getAttribute('data-esen-initial-index') || '0';
    var initial = /^(0|[1-9][0-9]*)$/.test(initialValue)
        ? Number(initialValue) : 0;
    if (!Number.isSafeInteger(initial) || initial >= panels.length) initial = 0;
    if (stableLayout) {
      if (placeholder.tagName !== 'DIV' ||
          placeholder.getAttribute('data-esen-prepaint-placeholder') !==
              'tabs' ||
          !placeholder.classList.contains('esen-seo-tab-list') ||
          !placeholder.hasAttribute('hidden') ||
          placeholder.getAttribute('aria-hidden') !== 'true' ||
          placeholder.children.length !== panels.length) return;
      var placeholderValid = panels.every(function (panel, index) {
        var item = placeholder.children[index];
        var selected = index === initial;
        return item.tagName === 'SPAN' &&
            item.classList.contains('esen-seo-tab') &&
            item.textContent === headings[index].textContent &&
            item.getAttribute('data-esen-placeholder-selected') ===
                (selected ? 'true' : null) &&
            panel.getAttribute('data-esen-initial-active') ===
                (selected ? 'true' : null);
      });
      if (!placeholderValid) return;
    }

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

    if (placeholder) {
      root.replaceChild(tablist, placeholder);
    } else {
      root.insertBefore(tablist, root.firstChild);
    }
    root.setAttribute('data-esen-enhanced', 'true');
    activate(initial, false);
  }

  function enhanceCarousel(root) {
    if (!canEnhance(root)) return;

    var placeholder = root.firstElementChild &&
        root.firstElementChild.hasAttribute('data-esen-prepaint-placeholder')
        ? root.firstElementChild : null;
    var stableLayout =
        root.getAttribute('data-esen-layout-stable') === 'true';
    if (!!placeholder !== stableLayout) return;
    var slides = directCarouselSlides(root);
    if (slides.length < 2 || slides.length > '''
    '$seoCarouselMaxEnhancedSlides'
    r''' ||
        slides.length + (placeholder ? 1 : 0) !== root.children.length) return;

    var label = root.getAttribute('data-esen-label') || '';
    var previousLabel = root.getAttribute('data-esen-previous-label') || '';
    var nextLabel = root.getAttribute('data-esen-next-label') || '';
    if (!label.trim() || !previousLabel.trim() || !nextLabel.trim()) return;
    var initialValue = root.getAttribute('data-esen-initial-index');
    if (initialValue === null || !/^(0|[1-9][0-9]*)$/.test(initialValue)) {
      return;
    }
    var initial = Number(initialValue);
    if (!Number.isSafeInteger(initial) || initial >= slides.length) return;

    var previousId = root.id + '-previous';
    var nextId = root.id + '-next';
    var statusId = root.id + '-status';
    if (idCount(previousId) !== 0 || idCount(nextId) !== 0 ||
        idCount(statusId) !== 0) return;

    var ids = Object.create(null);
    var valid = slides.every(function (slide) {
      var heading = slide.firstElementChild;
      var headingTag = heading ? heading.tagName : '';
      var headingText = heading ? heading.textContent || '' : '';
      if (idCount(slide.id) !== 1 || ids[slide.id] ||
          !/^H[1-6]$/.test(headingTag) || !headingText.trim()) {
        return false;
      }
      ids[slide.id] = true;
      return true;
    });
    if (!valid) return;
    if (stableLayout) {
      var placeholderChildren = placeholder.children;
      var placeholderPrevious = placeholderChildren[0];
      var placeholderStatus = placeholderChildren[1];
      var placeholderNext = placeholderChildren[2];
      if (placeholder.tagName !== 'DIV' ||
          placeholder.getAttribute('data-esen-prepaint-placeholder') !==
              'carousel' ||
          !placeholder.classList.contains('esen-seo-carousel-controls') ||
          !placeholder.hasAttribute('hidden') ||
          placeholder.getAttribute('aria-hidden') !== 'true' ||
          placeholderChildren.length !== 3 ||
          placeholderPrevious.tagName !== 'SPAN' ||
          placeholderStatus.tagName !== 'SPAN' ||
          placeholderNext.tagName !== 'SPAN' ||
          !placeholderPrevious.classList.contains(
              'esen-seo-carousel-control-placeholder') ||
          !placeholderStatus.classList.contains('esen-seo-carousel-status') ||
          !placeholderNext.classList.contains(
              'esen-seo-carousel-control-placeholder') ||
          placeholderPrevious.textContent !== '\u2039' ||
          placeholderStatus.textContent !==
              (initial + 1) + ' / ' + slides.length ||
          placeholderNext.textContent !== '\u203A' ||
          placeholderPrevious.getAttribute(
              'data-esen-placeholder-disabled') !==
              (initial === 0 ? 'true' : null) ||
          placeholderNext.getAttribute(
              'data-esen-placeholder-disabled') !==
              (initial === slides.length - 1 ? 'true' : null)) return;
      var initialSlidesValid = slides.every(function (slide, index) {
        return slide.getAttribute('data-esen-initial-active') ===
            (index === initial ? 'true' : null);
      });
      if (!initialSlidesValid) return;
    }

    var rtl = window.getComputedStyle(root).direction === 'rtl';
    var controls = document.createElement('div');
    controls.className = 'esen-seo-carousel-controls';
    controls.setAttribute('data-esen-carousel-controls', '');

    function control(id, accessibleLabel, symbol) {
      var button = document.createElement('button');
      button.type = 'button';
      button.id = id;
      button.setAttribute('data-esen-carousel-control', '');
      button.setAttribute('aria-label', accessibleLabel);
      var icon = document.createElement('span');
      icon.setAttribute('aria-hidden', 'true');
      icon.textContent = symbol;
      button.appendChild(icon);
      return button;
    }

    var previous = control(previousId, previousLabel,
        rtl ? '\u203A' : '\u2039');
    var next = control(nextId, nextLabel, rtl ? '\u2039' : '\u203A');
    var status = document.createElement('span');
    status.id = statusId;
    status.className = 'esen-seo-carousel-status';
    status.setAttribute('data-esen-carousel-status', '');
    status.setAttribute('aria-live', 'polite');
    status.setAttribute('aria-atomic', 'true');
    controls.appendChild(previous);
    controls.appendChild(status);
    controls.appendChild(next);

    var current = 0;
    function activate(index) {
      if (index < 0 || index >= slides.length) return;
      current = index;
      slides.forEach(function (slide, slideIndex) {
        slide.hidden = slideIndex !== current;
      });
      previous.setAttribute('aria-disabled', current === 0 ? 'true' : 'false');
      next.setAttribute(
          'aria-disabled', current === slides.length - 1 ? 'true' : 'false');
      status.textContent = (current + 1) + ' / ' + slides.length;
    }

    function bind(button, offset) {
      button.addEventListener('click', function () {
        if (button.getAttribute('aria-disabled') !== 'true') {
          activate(current + offset);
        }
      });
      button.addEventListener('keydown', function (event) {
        var activation = event.key === 'Enter' || event.key === ' ';
        var target = null;
        if (activation) {
          target = button.getAttribute('aria-disabled') === 'true'
              ? current : current + offset;
        } else if (event.key === 'ArrowLeft') {
          target = current + (rtl ? 1 : -1);
        } else if (event.key === 'ArrowRight') {
          target = current + (rtl ? -1 : 1);
        } else if (event.key === 'Home') {
          target = 0;
        } else if (event.key === 'End') {
          target = slides.length - 1;
        }
        if (target === null) return;
        event.preventDefault();
        event.stopPropagation();
        if (!event.repeat) activate(target);
      });
    }

    bind(previous, -1);
    bind(next, 1);
    if (placeholder) {
      root.replaceChild(controls, placeholder);
    } else {
      root.insertBefore(controls, root.firstChild);
    }
    root.setAttribute('role', 'region');
    root.setAttribute('aria-label', label);
    root.setAttribute('data-esen-enhanced', 'true');
    activate(initial);
  }

  function enhanceStepper(root) {
    if (!canEnhance(root)) return;
    var placeholder = root.firstElementChild &&
        root.firstElementChild.hasAttribute('data-esen-prepaint-placeholder')
        ? root.firstElementChild : null;
    var stableLayout =
        root.getAttribute('data-esen-layout-stable') === 'true';
    if (!!placeholder !== stableLayout ||
        root.children.length !== (placeholder ? 2 : 1)) return;
    var list = placeholder ? placeholder.nextElementSibling :
        root.firstElementChild;
    if (!list || list.tagName !== 'OL' ||
        !list.hasAttribute('data-esen-step-list')) return;

    var steps = directStepperSteps(list);
    if (steps.length < 2 || steps.length !== list.children.length) return;

    var label = root.getAttribute('data-esen-label') || '';
    var previousLabel = root.getAttribute('data-esen-previous-label') || '';
    var nextLabel = root.getAttribute('data-esen-next-label') || '';
    var positionLabel = root.getAttribute('data-esen-position-label') || '';
    if (!label.trim() || !previousLabel.trim() || !nextLabel.trim() ||
        !positionLabel.trim()) return;

    var initialValue = root.getAttribute('data-esen-initial-index');
    if (initialValue === null || !/^(0|[1-9][0-9]*)$/.test(initialValue)) {
      return;
    }
    var initial = Number(initialValue);
    if (!Number.isSafeInteger(initial) || initial >= steps.length) return;

    var previousId = root.id + '-previous';
    var nextId = root.id + '-next';
    var statusId = root.id + '-status';
    if (idCount(previousId) !== 0 || idCount(nextId) !== 0 ||
        idCount(statusId) !== 0) return;

    var ids = Object.create(null);
    var entries = [];
    var valid = steps.every(function (step, index) {
      var buttonPlaceholder = step.firstElementChild &&
          step.firstElementChild.hasAttribute('data-esen-prepaint-placeholder')
          ? step.firstElementChild : null;
      if (!!buttonPlaceholder !== stableLayout ||
          step.children.length !== (buttonPlaceholder ? 3 : 2)) return false;
      var heading = step.children[buttonPlaceholder ? 1 : 0];
      var panel = step.children[buttonPlaceholder ? 2 : 1];
      var headingTag = heading ? heading.tagName : '';
      var headingText = heading ? heading.textContent || '' : '';
      var buttonId = root.id + '-step-button-' + index;
      var expectedStepId = root.id + '-step-' + index;
      var expectedPanelId = root.id + '-panel-' + index;
      if (step.id !== expectedStepId || panel.id !== expectedPanelId ||
          idCount(step.id) !== 1 || idCount(panel.id) !== 1 ||
          ids[step.id] || ids[panel.id] || idCount(buttonId) !== 0 ||
          !/^H[1-6]$/.test(headingTag) || !headingText.trim() ||
          panel.tagName !== 'DIV' ||
          !panel.hasAttribute('data-esen-step-panel')) {
        return false;
      }
      ids[step.id] = true;
      ids[panel.id] = true;
      entries.push({
        step: step,
        heading: heading,
        panel: panel,
        buttonId: buttonId,
        buttonPlaceholder: buttonPlaceholder
      });
      return true;
    });
    if (!valid) return;
    if (stableLayout) {
      var placeholderChildren = placeholder.children;
      var placeholderPrevious = placeholderChildren[0];
      var placeholderStatus = placeholderChildren[1];
      var placeholderNext = placeholderChildren[2];
      if (placeholder.tagName !== 'DIV' ||
          placeholder.getAttribute('data-esen-prepaint-placeholder') !==
              'stepper' ||
          !placeholder.classList.contains('esen-seo-stepper-controls') ||
          !placeholder.hasAttribute('hidden') ||
          placeholder.getAttribute('aria-hidden') !== 'true' ||
          placeholderChildren.length !== 3 ||
          placeholderPrevious.tagName !== 'SPAN' ||
          placeholderStatus.tagName !== 'SPAN' ||
          placeholderNext.tagName !== 'SPAN' ||
          !placeholderPrevious.classList.contains(
              'esen-seo-stepper-control-placeholder') ||
          !placeholderStatus.classList.contains('esen-seo-stepper-status') ||
          !placeholderNext.classList.contains(
              'esen-seo-stepper-control-placeholder') ||
          placeholderPrevious.textContent !== previousLabel ||
          placeholderStatus.textContent !== positionLabel + ' ' +
              (initial + 1) + ' / ' + entries.length ||
          placeholderNext.textContent !== nextLabel ||
          placeholderPrevious.getAttribute(
              'data-esen-placeholder-disabled') !==
              (initial === 0 ? 'true' : null) ||
          placeholderNext.getAttribute(
              'data-esen-placeholder-disabled') !==
              (initial === entries.length - 1 ? 'true' : null)) return;
      var initialStepsValid = entries.every(function (entry, index) {
        var buttonPlaceholder = entry.buttonPlaceholder;
        return buttonPlaceholder.tagName === 'SPAN' &&
            buttonPlaceholder.getAttribute(
                'data-esen-prepaint-placeholder') === 'stepper-button' &&
            buttonPlaceholder.classList.contains('esen-seo-step-button') &&
            buttonPlaceholder.hasAttribute('hidden') &&
            buttonPlaceholder.getAttribute('aria-hidden') === 'true' &&
            buttonPlaceholder.textContent === entry.heading.textContent &&
            entry.heading.hasAttribute('data-esen-step-heading') &&
            entry.panel.getAttribute('data-esen-initial-active') ===
                (index === initial ? 'true' : null);
      });
      if (!initialStepsValid) return;
    }

    var rtl = window.getComputedStyle(root).direction === 'rtl';
    var buttons = entries.map(function (entry) {
      var button = document.createElement('button');
      button.type = 'button';
      button.id = entry.buttonId;
      button.className = 'esen-seo-step-button';
      button.setAttribute('data-esen-step-button', '');
      button.setAttribute('aria-controls', entry.panel.id);
      button.textContent = entry.heading.textContent || '';
      entry.panel.setAttribute('role', 'region');
      entry.panel.setAttribute('aria-labelledby', button.id);
      entry.heading.hidden = true;
      if (entry.buttonPlaceholder) {
        entry.step.replaceChild(button, entry.buttonPlaceholder);
      } else {
        entry.step.insertBefore(button, entry.heading);
      }
      return button;
    });

    var controls = document.createElement('div');
    controls.className = 'esen-seo-stepper-controls';
    controls.setAttribute('data-esen-stepper-controls', '');

    function control(id, accessibleLabel) {
      var button = document.createElement('button');
      button.type = 'button';
      button.id = id;
      button.setAttribute('data-esen-stepper-control', '');
      button.textContent = accessibleLabel;
      return button;
    }

    var previous = control(previousId, previousLabel);
    var next = control(nextId, nextLabel);
    var status = document.createElement('span');
    status.id = statusId;
    status.className = 'esen-seo-stepper-status';
    status.setAttribute('data-esen-stepper-status', '');
    status.setAttribute('aria-live', 'polite');
    status.setAttribute('aria-atomic', 'true');
    controls.appendChild(previous);
    controls.appendChild(status);
    controls.appendChild(next);

    var current = 0;
    function activate(index, moveFocus) {
      if (index < 0 || index >= entries.length) return;
      current = index;
      entries.forEach(function (entry, entryIndex) {
        var selected = entryIndex === current;
        if (selected) {
          buttons[entryIndex].setAttribute('aria-current', 'step');
        } else {
          buttons[entryIndex].removeAttribute('aria-current');
        }
        buttons[entryIndex].setAttribute(
            'aria-expanded', selected ? 'true' : 'false');
        buttons[entryIndex].tabIndex = selected ? 0 : -1;
        entry.panel.hidden = !selected;
      });
      previous.setAttribute('aria-disabled', current === 0 ? 'true' : 'false');
      next.setAttribute(
          'aria-disabled', current === entries.length - 1 ? 'true' : 'false');
      status.textContent = positionLabel + ' ' +
          (current + 1) + ' / ' + entries.length;
      if (moveFocus) buttons[current].focus();
    }

    buttons.forEach(function (button, index) {
      button.addEventListener('click', function () {
        activate(index, false);
      });
      button.addEventListener('keydown', function (event) {
        var target = null;
        if (event.key === 'ArrowDown') {
          target = Math.min(index + 1, buttons.length - 1);
        } else if (event.key === 'ArrowUp') {
          target = Math.max(index - 1, 0);
        } else if (event.key === 'ArrowRight') {
          target = rtl ? Math.max(index - 1, 0) :
              Math.min(index + 1, buttons.length - 1);
        } else if (event.key === 'ArrowLeft') {
          target = rtl ? Math.min(index + 1, buttons.length - 1) :
              Math.max(index - 1, 0);
        } else if (event.key === 'Home') {
          target = 0;
        } else if (event.key === 'End') {
          target = buttons.length - 1;
        }
        if (target === null) return;
        event.preventDefault();
        event.stopPropagation();
        if (!event.repeat) activate(target, true);
      });
    });

    previous.addEventListener('click', function () {
      if (previous.getAttribute('aria-disabled') !== 'true') {
        activate(current - 1, false);
      }
    });
    next.addEventListener('click', function () {
      if (next.getAttribute('aria-disabled') !== 'true') {
        activate(current + 1, false);
      }
    });

    if (placeholder) {
      root.replaceChild(controls, placeholder);
    } else {
      root.appendChild(controls);
    }
    root.setAttribute('role', 'region');
    root.setAttribute('aria-label', label);
    root.setAttribute('data-esen-enhanced', 'true');
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
    enhanceSelector(root, carouselSelector, enhanceCarousel);
    enhanceSelector(root, stepperSelector, enhanceStepper);
    enhanceSelector(root, navSelector, enhanceNav);
  }

  function enhanceDocument() {
    enhanceAll(document);
    delete document.documentElement.dataset.esenInteractionPending;
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', function () {
      enhanceDocument();
    }, {once: true});
  } else {
    enhanceDocument();
  }
})();
''';

final RegExp _scriptTokenizerTrap = RegExp(
  r'<!--|</\s*script',
  caseSensitive: false,
);

/// Wraps the trusted runtime in an inline script tag.
///
/// [nonce] is optional. When supplied it is escaped as an HTML attribute so
/// callers can satisfy a nonce-based Content Security Policy.
String seoInteractionScriptHtml({String? nonce}) {
  if (_scriptTokenizerTrap.hasMatch(seoInteractionRuntime)) {
    throw StateError('The interaction runtime contains unsafe inline code.');
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
