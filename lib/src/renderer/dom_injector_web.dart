import 'dart:async';

import 'package:web/web.dart' as web;

import 'seo_container.dart';
import 'seo_node.dart';

const String _metaMarker = 'data-esen-seo';

/// True while the visible shell is fading out — during that window its
/// content must stay put, or the user would watch it change mid-fade.
bool _shellFading = false;

/// The most recent tree, applied once the fade has finished.
List<SeoNode>? _pendingNodes;

/// Writes the semantic HTML tree into the browser DOM, next to the
/// Flutter canvas.
///
/// Builds real DOM elements through the typed `package:web` API instead of
/// assigning raw `innerHTML` strings, which keeps the injection independent
/// of `TrustedHTML` policies and safe against markup injection.
void injectSeoNodes(List<SeoNode> nodes) {
  final document = web.document;

  // Findet auch einen vom Prerenderer gebackenen Container wieder und
  // übernimmt ihn (Hydration).
  final existing = document.getElementById(seoContainerId);
  if (existing != null && existing.hasAttribute(seoShellAttribute)) {
    _startShellHandoff(existing, nodes);
    return;
  }
  if (existing != null && _shellFading) {
    // Der Shell ist noch am Ausblenden — den neuesten Stand merken und
    // erst danach einsetzen.
    _pendingNodes = nodes;
    return;
  }

  final web.Element container;
  if (existing == null) {
    container = document.createElement('div');
    container.id = seoContainerId;
    // The Flutter canvas stays the visible UI; the semantic tree must not
    // add scrollbars or intercept clicks, and screen readers already get
    // Flutter's own semantics tree.
    container.setAttribute('aria-hidden', 'true');
    container.setAttribute(seoInertAttribute, '');
    container.setAttribute('style', seoContainerStyle);
    document.body?.appendChild(container);
  } else {
    container = existing;
  }

  _fillContainer(document, container, nodes);
}

void _fillContainer(
  web.Document document,
  web.Element container,
  List<SeoNode> nodes,
) {
  container.textContent = '';
  for (final node in nodes) {
    container.appendChild(_buildDomNode(document, node));
  }
}

/// Hands the screen from a visible prerendered shell over to Flutter.
///
/// Runs the moment the first frame has been built, which is when this
/// injector is called for the first time. Flutter has painted *below*
/// the shell by then, so fading the shell out reveals a finished app
/// instead of a hard cut.
///
/// The container keeps its id and content for the whole fade — the
/// stylesheet is written against `#esen-seo-content`, and swapping the
/// content mid-fade would be visible. Only when the shell is gone does
/// it drop back to the invisible mirror of [SeoRenderMode.seoOnly] and
/// take the semantic tree.
void _startShellHandoff(web.Element container, List<SeoNode> nodes) {
  container.removeAttribute(seoShellAttribute);
  _shellFading = true;
  _pendingNodes = nodes;
  // Nur die Opazität ändern — die Transition steckt schon im Style.
  container.setAttribute(
    'style',
    '${seoShellStyle}opacity:0;pointer-events:none;',
  );

  Timer(const Duration(milliseconds: seoShellFadeMs), () {
    _shellFading = false;
    container.setAttribute('aria-hidden', 'true');
    // Ab jetzt wieder unsichtbarer Spiegel — also raus aus Tab-Reihenfolge
    // und Accessibility-Baum.
    container.setAttribute(seoInertAttribute, '');
    container.setAttribute('style', seoContainerStyle);
    final pending = _pendingNodes;
    _pendingNodes = null;
    if (pending != null) {
      _fillContainer(web.document, container, pending);
    }
  });
}

/// Writes the meta nodes from `SeoMeta.toNodes` into the document `<head>`.
///
/// Every injected element carries a `data-esen-seo` marker so repeated calls
/// replace only what esen_seo manages — tags hardcoded in index.html stay
/// untouched. The `<title>` node updates `document.title` directly.
void injectMetaNodes(List<SeoNode> nodes) {
  final document = web.document;
  final head = document.head;
  if (head == null) return;

  final stale = document.querySelectorAll('[$_metaMarker]');
  for (var i = stale.length - 1; i >= 0; i--) {
    final element = stale.item(i);
    if (element != null) element.parentNode?.removeChild(element);
  }

  for (final node in nodes) {
    if (node.tag == 'title') {
      document.title = node.text ?? '';
      continue;
    }
    _removeStaticDuplicates(document, node);
    final element = document.createElement(node.tag);
    node.attributes.forEach(
      (name, value) => element.setAttribute(name, value),
    );
    element.setAttribute(_metaMarker, 'true');
    if (node.rawText != null) element.textContent = node.rawText;
    head.appendChild(element);
  }
}

/// Removes hardcoded index.html tags that the injected [node] supersedes,
/// e.g. the Flutter template's `<meta name="description">` — otherwise
/// crawlers would see the tag twice with conflicting content.
void _removeStaticDuplicates(web.Document document, SeoNode node) {
  final String? selector;
  if (node.tag == 'meta' && node.attributes.containsKey('name')) {
    selector = 'meta[name="${node.attributes['name']}"]';
  } else if (node.tag == 'meta' && node.attributes.containsKey('property')) {
    selector = 'meta[property="${node.attributes['property']}"]';
  } else if (node.tag == 'link' && node.attributes['rel'] == 'canonical') {
    selector = 'link[rel="canonical"]';
  } else if (node.tag == 'link' &&
      node.attributes['rel'] == 'alternate' &&
      node.attributes.containsKey('hreflang')) {
    // Nur hreflang-Alternates ersetzen — RSS-Links (rel=alternate mit
    // type=...) aus der index.html bleiben unangetastet.
    selector =
        'link[rel="alternate"][hreflang="${node.attributes['hreflang']}"]';
  } else if (node.tag == 'script' &&
      node.attributes['type'] == 'application/ld+json') {
    // Vom Prerenderer gebackene JSON-LD-Blöcke weichen den frischen.
    selector = 'script[type="application/ld+json"]';
  } else {
    selector = null;
  }
  if (selector == null) return;

  // Nur unmanagte Tags entfernen — bereits injizierte eigene (markierte)
  // Elemente desselben Typs bleiben stehen (z.B. mehrere JSON-LD-Blöcke).
  final stale = document.querySelectorAll('$selector:not([$_metaMarker])');
  for (var i = stale.length - 1; i >= 0; i--) {
    final element = stale.item(i);
    if (element != null) element.parentNode?.removeChild(element);
  }
}

/// Sets `document.title`.
///
/// Called on every refresh, because Flutter's own `Title` widget (built
/// into MaterialApp) overwrites the browser title on rebuild.
void applyDocumentTitle(String title) {
  web.document.title = title;
}

web.Node _buildDomNode(web.Document document, SeoNode node) {
  if (node.isTextOnly) return document.createTextNode(node.text ?? '');

  final element = document.createElement(node.tag);
  node.attributes.forEach(
    (name, value) => element.setAttribute(name, value),
  );
  if (node.text != null) {
    element.appendChild(document.createTextNode(node.text!));
  }
  if (node.rawText != null) {
    element.appendChild(document.createTextNode(node.rawText!));
  }
  for (final child in node.children) {
    element.appendChild(_buildDomNode(document, child));
  }
  return element;
}
