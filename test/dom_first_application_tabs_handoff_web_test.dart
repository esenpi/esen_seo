@TestOn('browser')
library;

import 'dart:convert';
import 'dart:js_interop';

import 'package:crypto/crypto.dart';
import 'package:esen_seo/server.dart';
import 'package:esen_seo/src/renderer/dom_first_tabs_adapter_web.dart';
import 'package:esen_seo/src/renderer/seo_dom_first_navigation_application_profile_runtime.g.dart';
import 'package:esen_seo/src/renderer/seo_dom_first_runtime_handoff.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;

const _profile = 'applicationRuntimeHandoff.navigation.application.'
    'tabs.product-tabs';
const _applicationId = 'product-tabs';
const _interactionId = 'product-tabs-control';
const _enhanceEvent = 'esen-seo:test-tabs-handoff';
const _applicationSource =
    'document.dispatchEvent(new Event("$_enhanceEvent"))';
final _applicationSourceBytes = utf8.encode(_applicationSource).length;
final _applicationSourceHash =
    sha256.convert(utf8.encode(_applicationSource)).toString();
final _applicationRuntime = seoDomFirstApplicationHandoffEnvelope(
  _applicationSource,
  kind: 'tabs',
);

void main() {
  test('hands one Tabs artifact across fresh route documents', () async {
    _cleanDocument();
    final originalHref = web.window.location.href;
    final enhanceListener = _mountEnhanceListener();
    addTearDown(() {
      web.document.removeEventListener(_enhanceEvent, enhanceListener);
      _restoreFetch();
      web.window.history.replaceState(null, '', originalHref);
      _cleanDocument();
    });

    web.window.history.replaceState(null, '', '/repo/overview');
    final manifest = _manifest([
      ['/overview', _profile, null],
      ['/basic', _profile, _descriptor()],
      ['/advanced', _profile, _descriptor()],
    ]);
    final overviewDocument = _document(
      title: 'Overview',
      body: _overviewBody(),
      manifest: manifest,
    );
    final basicDocument = _document(
      title: 'Basic product',
      body: _tabsBody(
        title: 'Basic product',
        initialIndex: 0,
        nextPath: '/repo/advanced',
      ),
      manifest: manifest,
      runtime: _runtimeTag(),
    );
    final advancedDocument = _document(
      title: 'Advanced product',
      body: _tabsBody(
        title: 'Advanced product',
        initialIndex: 2,
        nextPath: '/repo/overview',
      ),
      manifest: manifest,
      runtime: _runtimeTag(),
    );

    _mountHead('Overview', manifest);
    final overview = _mountBody(_overviewBody());
    _mockDocuments({
      '/repo/overview': overviewDocument,
      '/repo/basic': basicDocument,
      '/repo/advanced': advancedDocument,
    });
    _mountNavigationRuntime();

    (overview.querySelector('a')! as web.HTMLElement).click();
    await _waitFor(
      () =>
          web.window.location.pathname == '/repo/basic' &&
          _enhancedTabs() != null,
    );
    final basic = _enhancedTabs()!;
    expect(_selectedIndex(basic), 0);
    _tab(basic, 1).click();
    expect(_selectedIndex(basic), 1);
    final firstRuntime = web.document.querySelector(
      'script[$seoDomFirstLoadableRuntimeAttribute]',
    )! as web.HTMLScriptElement;
    expect(
      firstRuntime.getAttribute(seoDomFirstRuntimeKindAttribute),
      'tabs',
    );
    expect(
      firstRuntime.getAttribute(seoDomFirstRuntimeReadyAttribute),
      'true',
    );
    expect(firstRuntime.nonce, 'trusted-nonce');

    (web.document.querySelector('#next-route')! as web.HTMLElement).click();
    await _waitFor(
      () =>
          web.window.location.pathname == '/repo/advanced' &&
          _enhancedTabs() != null &&
          _enhancedTabs() != basic,
    );
    final advanced = _enhancedTabs()!;
    expect(basic.isConnected, isFalse);
    expect(_selectedIndex(advanced), 2);
    _keydown(_tab(advanced, 2), 'ArrowRight');
    expect(
      _selectedIndex(advanced),
      2,
      reason: 'the application transition does not wrap at the last tab',
    );
    expect(web.document.activeElement?.id, '$_interactionId-tab-2');
    expect(
      web.document
          .querySelectorAll('script[$seoDomFirstLoadableRuntimeAttribute]')
          .length,
      1,
    );

    (web.document.querySelector('#next-route')! as web.HTMLElement).click();
    await _waitFor(
      () =>
          web.window.location.pathname == '/repo/overview' &&
          web.document.title == 'Overview',
    );
    expect(advanced.isConnected, isFalse);
    expect(_enhancedTabs(), isNull);
    expect(
      web.document
          .querySelectorAll('script[$seoDomFirstLoadableRuntimeAttribute]')
          .length,
      0,
    );

    web.window.history.back();
    await _waitFor(
      () =>
          web.window.location.pathname == '/repo/advanced' &&
          _enhancedTabs() != null,
    );
    final restored = _enhancedTabs()!;
    expect(restored, isNot(same(advanced)));
    expect(_selectedIndex(restored), 2);
  });

  test('initializes direct Tabs from its delivered fragment target', () async {
    _cleanDocument();
    final originalHref = web.window.location.href;
    final enhanceListener = _mountEnhanceListener();
    addTearDown(() {
      web.document.removeEventListener(_enhanceEvent, enhanceListener);
      _restoreFetch();
      web.window.history.replaceState(null, '', originalHref);
      _cleanDocument();
    });

    web.window.history.replaceState(
      null,
      '',
      '/repo/direct#$_interactionId-panel-2',
    );
    final manifest = _manifest([
      ['/direct', _profile, _descriptor()],
      ['/overview', _profile, null],
    ]);
    final body = _tabsBody(
      title: 'Direct product',
      initialIndex: 0,
      nextPath: '/repo/overview',
    );
    final overviewDocument = _document(
      title: 'Overview',
      body: _overviewBody(),
      manifest: manifest,
    );
    _mountHead('Direct product', manifest);
    final direct = _mountBody(body);

    expect(direct.querySelectorAll('button'), isEmpty);
    expect(direct.textContent, contains('Overview content'));
    expect(direct.textContent, contains('Details content'));
    expect(direct.textContent, contains('Delivery content'));
    web.document.documentElement
        ?.setAttribute('data-esen-interaction-pending', '1');
    final runtime = _mountApplicationRuntime();
    final tabs = _enhancedTabs()!;
    expect(_selectedIndex(tabs), 2);
    expect(
      runtime.getAttribute(seoDomFirstRuntimeReadyAttribute),
      'true',
    );
    expect(
      web.document.documentElement
          ?.hasAttribute('data-esen-interaction-pending'),
      isFalse,
    );

    _mockDocuments({'/repo/overview': overviewDocument});
    _mountNavigationRuntime();
    expect(_navigationArmed(), isTrue);
    (web.document.querySelector('#next-route')! as web.HTMLElement).click();
    await _waitFor(
      () =>
          web.window.location.pathname == '/repo/overview' &&
          web.document.title == 'Overview',
    );
    expect(tabs.isConnected, isFalse);
    expect(_enhancedTabs(), isNull);
  });
}

SeoTabsState _tabsTransition(
  SeoTabsState state,
  SeoTabsAction action,
) {
  if (state.count == 0) return state;
  final next = switch (action) {
    SeoTabsSelect(:final index) when index >= 0 && index < state.count => index,
    SeoTabsSelect() => state.index,
    SeoTabsNext() =>
      state.index < state.count - 1 ? state.index + 1 : state.index,
    SeoTabsPrevious() => state.index > 0 ? state.index - 1 : state.index,
    SeoTabsFirst() => 0,
    SeoTabsLast() => state.count - 1,
  };
  return SeoTabsState(index: next, count: state.count);
}

List<Object?> _descriptor() => [
      seoDomFirstApplicationRuntimeOwner,
      'tabs',
      _applicationId,
      seoDomFirstRuntimeContractRevision,
      _applicationSourceHash,
      _applicationSourceBytes,
    ];

String _manifest(List<List<Object?>> routes) => jsonEncode({
      'schema': seoDomFirstTypedApplicationRuntimeHandoffManifestSchema,
      'base': '/repo',
      'profile': _profile,
      'routes': routes,
    });

String _overviewBody() =>
    '<div id="esen-seo-content" data-esen-seo-dom-first="true">'
    '<main><h1>Overview</h1>'
    '<a href="/repo/basic">Open product tabs</a>'
    '</main></div>';

String _tabsBody({
  required String title,
  required int initialIndex,
  required String nextPath,
}) {
  final tabs = const HtmlRenderer.domFirst().render(
    buildSeoTabsNodes(
      tabs: _tabEntries(),
      interactionId: _interactionId,
      interactionLabel: '$title information',
      initialIndex: initialIndex,
    ),
  );
  return '<div id="esen-seo-content" data-esen-seo-dom-first="true">'
      '<main><h1>$title</h1>$tabs'
      '<a id="next-route" href="$nextPath">Next route</a>'
      '</main></div>';
}

List<SeoTabComponentEntry> _tabEntries() => [
      (
        label: 'Overview',
        nodes: [SeoNode(tag: 'p', text: 'Overview content')],
      ),
      (
        label: 'Details',
        nodes: [SeoNode(tag: 'p', text: 'Details content')],
      ),
      (
        label: 'Delivery',
        nodes: [SeoNode(tag: 'p', text: 'Delivery content')],
      ),
    ];

String _document({
  required String title,
  required String body,
  required String manifest,
  String runtime = '',
}) =>
    '<!DOCTYPE html><html lang="en"><head>'
    '<title $seoDomFirstNavigationHeadAttribute>$title</title>'
    '<script type="application/json" '
    '$seoDomFirstNavigationManifestAttribute '
    'data-esen-navigation-profile="$_profile">$manifest</script>'
    '</head><body>$body$runtime'
    '<script data-esen-seo-dom-first-runtime></script>'
    '</body></html>';

String _runtimeTag() => '<script $seoDomFirstLoadableRuntimeAttribute="'
    '$seoDomFirstApplicationRuntimeOwner" '
    '$seoDomFirstApplicationScriptAttribute="$_applicationId" '
    '$seoDomFirstRuntimeKindAttribute="tabs" '
    '$seoDomFirstRuntimeContractAttribute="'
    '$seoDomFirstRuntimeContractRevision" '
    '$seoDomFirstRuntimeSha256Attribute="$_applicationSourceHash" '
    'nonce="fetched-nonce">$_applicationRuntime</script>';

JSFunction _mountEnhanceListener() {
  final listener = ((web.Event _) {
    enhanceSeoDomFirstTabs(transition: _tabsTransition);
  }).toJS;
  web.document.addEventListener(_enhanceEvent, listener);
  return listener;
}

void _mountHead(String titleText, String manifest) {
  final title = web.document.createElement('title')
    ..setAttribute(seoDomFirstNavigationHeadAttribute, '')
    ..textContent = titleText;
  final manifestNode = web.document.createElement('script')
    ..setAttribute('type', 'application/json')
    ..setAttribute(seoDomFirstNavigationManifestAttribute, '')
    ..setAttribute('data-esen-navigation-profile', _profile)
    ..textContent = manifest;
  web.document.head
    ?..appendChild(title)
    ..appendChild(manifestNode);
}

web.HTMLElement _mountBody(String body) {
  final holder = web.document.createElement('div')..setHTMLUnsafe(body.toJS);
  final content = holder.firstElementChild! as web.HTMLElement;
  web.document.body?.appendChild(content);
  return content;
}

web.HTMLScriptElement _mountApplicationRuntime() {
  final runtime = web.document.createElement('script') as web.HTMLScriptElement
    ..setAttribute(
      seoDomFirstLoadableRuntimeAttribute,
      seoDomFirstApplicationRuntimeOwner,
    )
    ..setAttribute(seoDomFirstApplicationScriptAttribute, _applicationId)
    ..setAttribute(seoDomFirstRuntimeKindAttribute, 'tabs')
    ..setAttribute(
      seoDomFirstRuntimeContractAttribute,
      '$seoDomFirstRuntimeContractRevision',
    )
    ..setAttribute(
      seoDomFirstRuntimeSha256Attribute,
      _applicationSourceHash,
    )
    ..setAttribute('nonce', 'trusted-nonce')
    ..textContent = _applicationRuntime;
  web.document.body?.appendChild(runtime);
  return runtime;
}

void _mountNavigationRuntime() {
  final runtime = web.document.createElement('script')
    ..setAttribute('data-esen-seo-dom-first-runtime', '')
    ..setAttribute('nonce', 'trusted-nonce')
    ..textContent = seoDomFirstNavigationApplicationProfileRuntime;
  web.document.body?.appendChild(runtime);
}

bool _navigationArmed() {
  _runJavaScript(
    'document.documentElement.dataset.tabsHandoffArmed='
    'history.state&&history.state.esenSeoNavigation===1?"1":"0"',
  );
  return web.document.documentElement
          ?.getAttribute('data-tabs-handoff-armed') ==
      '1';
}

web.Element? _enhancedTabs() {
  final tabs = web.document.querySelector(
    '[data-esen-component="tabs"]',
  );
  return tabs?.getAttribute('data-esen-enhanced') == 'true' ? tabs : null;
}

web.HTMLElement _tab(web.Element root, int index) => root.querySelector(
      '#$_interactionId-tab-$index',
    )! as web.HTMLElement;

int _selectedIndex(web.Element root) {
  for (var index = 0; index < _tabEntries().length; index++) {
    if (_tab(root, index).getAttribute('aria-selected') == 'true') return index;
  }
  return -1;
}

void _keydown(web.Element element, String key) {
  element.dispatchEvent(
    web.KeyboardEvent(
      'keydown',
      web.KeyboardEventInit(key: key, bubbles: true),
    ),
  );
}

void _mockDocuments(Map<String, String> documents) {
  final documentsJson = jsonEncode(documents);
  _runJavaScript(
    'globalThis.__esenOriginalFetch=globalThis.fetch;'
    'globalThis.__esenHandoffDocuments=$documentsJson;'
    'globalThis.fetch=async function(u,o){'
    'let body=globalThis.__esenHandoffDocuments[new URL(String(u)).pathname];'
    'return new Response(body,{headers:{'
    '"content-type":"text/html; charset=utf-8"}})}',
  );
}

void _restoreFetch() {
  _runJavaScript(
    'if(globalThis.__esenOriginalFetch)'
    'globalThis.fetch=globalThis.__esenOriginalFetch;'
    'delete globalThis.__esenOriginalFetch;'
    'delete globalThis.__esenHandoffDocuments;'
    'delete document.documentElement.dataset.tabsHandoffArmed;',
  );
  web.document.documentElement
      ?.removeAttribute('data-esen-interaction-pending');
}

Future<void> _waitFor(bool Function() condition) async {
  for (var index = 0; index < 250; index++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('Timed out waiting for the Tabs runtime handoff.');
}

void _cleanDocument() {
  for (final selector in const [
    'title',
    '[$seoDomFirstNavigationHeadAttribute]',
    'script[$seoDomFirstNavigationManifestAttribute]',
    'script[data-esen-seo-dom-first-runtime]',
    'script[$seoDomFirstLoadableRuntimeAttribute]',
    '#esen-seo-content',
  ]) {
    final nodes = web.document.querySelectorAll(selector);
    for (var index = nodes.length - 1; index >= 0; index--) {
      final node = nodes.item(index);
      if (node != null) node.parentNode?.removeChild(node);
    }
  }
}

void _runJavaScript(String source) {
  final script = web.document.createElement('script')..textContent = source;
  web.document.body?.appendChild(script);
  script.remove();
}
