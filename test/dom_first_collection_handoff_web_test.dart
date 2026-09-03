@TestOn('browser')
library;

import 'dart:convert';
import 'dart:js_interop';

import 'package:esen_seo/core.dart';
import 'package:esen_seo/src/renderer/seo_dom_first_navigation_handoff_runtime.g.dart';
import 'package:esen_seo/src/renderer/seo_dom_first_runtime_handoff.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;

const _profile = 'navigation.runtimeHandoff';
const _collectionId = 'handoff-collection';

void main() {
  test('loads a verified Collection runtime and retires its old state',
      () async {
    _removeAll('title');
    _removeAll('[$seoDomFirstNavigationHeadAttribute]');
    _removeAll('script[$seoDomFirstNavigationManifestAttribute]');
    _removeAll('script[data-esen-seo-dom-first-runtime]');
    _removeAll('script[$seoDomFirstLoadableRuntimeAttribute]');
    _removeAll('#esen-seo-content');

    final originalHref = web.window.location.href;
    addTearDown(() {
      _runJavaScript(
        'globalThis.fetch=globalThis.__esenOriginalFetch;'
        'delete globalThis.__esenOriginalFetch',
      );
      web.window.history.replaceState(null, '', originalHref);
      _removeAll('[$seoDomFirstNavigationHeadAttribute]');
      _removeAll('script[$seoDomFirstNavigationManifestAttribute]');
      _removeAll('script[data-esen-seo-dom-first-runtime]');
      _removeAll('script[$seoDomFirstLoadableRuntimeAttribute]');
      _removeAll('#esen-seo-content');
      web.document.documentElement?.removeAttribute('data-handoff-fetches');
    });

    web.window.history.replaceState(null, '', '/repo/handoff');
    final manifest = jsonEncode({
      'schema': seoDomFirstRuntimeHandoffManifestSchema,
      'base': '/repo',
      'profile': _profile,
      'routes': [
        ['/handoff', _profile, null],
        [
          '/handoff/articles',
          _profile,
          [
            seoDomFirstCollectionRuntimeKind,
            seoDomFirstCollectionHandoffRuntimeSha256,
            seoDomFirstCollectionHandoffRuntimeBytes,
          ],
        ],
      ],
    });
    final overviewBody = _overviewBody();
    final collectionBody = _collectionBody();
    final overviewDocument = _document(
      title: 'Overview',
      body: overviewBody,
      manifest: manifest,
    );
    final collectionDocument = _document(
      title: 'Articles',
      body: collectionBody,
      manifest: manifest,
      collectionRuntime: true,
    );

    _mountHead('Overview', manifest);
    final initial = _mountBody(overviewBody);
    _mockFetch(overviewDocument, collectionDocument);
    final navigationRuntime = web.document.createElement('script')
      ..setAttribute('data-esen-seo-dom-first-runtime', '')
      ..setAttribute('nonce', 'trusted-nonce')
      ..textContent = seoDomFirstNavigationHandoffRuntime;
    web.document.body?.appendChild(navigationRuntime);

    (initial.querySelector('a')! as web.HTMLElement).click();
    await _waitFor(
      () =>
          web.window.location.pathname == '/repo/handoff/articles' &&
          web.document.title == 'Articles' &&
          web.document
                  .querySelector('[data-esen-component="collection"]')
                  ?.getAttribute('data-esen-enhanced') ==
              'true',
    );

    final collection = web.document.querySelector(
      '[data-esen-component="collection"]',
    )!;
    final oldSearch =
        collection.querySelector('input')! as web.HTMLInputElement;
    expect(oldSearch.value, 'Beta');
    expect(_visibleItems(collection).map((item) => item.textContent), [
      contains('Beta'),
    ]);
    final loadable = web.document.querySelector(
      'script[$seoDomFirstLoadableRuntimeAttribute]',
    )! as web.HTMLScriptElement;
    expect(
      loadable.getAttribute(seoDomFirstRuntimeSha256Attribute),
      seoDomFirstCollectionHandoffRuntimeSha256,
    );
    expect(
      loadable.getAttribute(seoDomFirstRuntimeReadyAttribute),
      'true',
    );
    expect(loadable.nonce, 'trusted-nonce');
    expect(
      web.document.documentElement?.getAttribute('data-handoff-fetches'),
      '1',
    );

    web.window.history.back();
    await _waitFor(
      () => web.window.location.pathname == '/repo/handoff',
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(collection.isConnected, isTrue);
    expect(oldSearch.value, 'Beta');
    await _waitFor(
      () =>
          web.window.location.pathname == '/repo/handoff' &&
          web.document.title == 'Overview',
    );

    expect(collection.isConnected, isFalse);
    expect(
      web.document
          .querySelectorAll(
            'script[$seoDomFirstLoadableRuntimeAttribute]',
          )
          .length,
      0,
    );
    expect(
      web.document.querySelector('#esen-seo-content')?.textContent,
      contains('Overview'),
    );
    expect(
      web.document.documentElement?.getAttribute('data-handoff-fetches'),
      '2',
    );

    web.window.history.forward();
    await _waitFor(
      () =>
          web.window.location.pathname == '/repo/handoff/articles' &&
          web.document
                  .querySelector('[data-esen-component="collection"]')
                  ?.getAttribute('data-esen-enhanced') ==
              'true',
    );
    final restoredCollection = web.document.querySelector(
      '[data-esen-component="collection"]',
    )!;
    final restoredSearch =
        restoredCollection.querySelector('input')! as web.HTMLInputElement;
    expect(restoredSearch.value, 'Beta');
    expect(
      web.document.documentElement?.getAttribute('data-handoff-fetches'),
      '3',
    );

    _runJavaScript(
      'history.replaceState(history.state,"",'
      '"/repo/handoff/articles?esen.$_collectionId.q=Alpha")',
    );
    web.window.dispatchEvent(web.PopStateEvent('popstate'));
    await _waitFor(() => restoredSearch.value == 'Alpha');
    expect(
      _visibleItems(restoredCollection).map((item) => item.textContent),
      [contains('Alpha')],
    );

    (web.document.querySelector('#back-to-overview')! as web.HTMLElement)
        .click();
    await _waitFor(
      () =>
          web.window.location.pathname == '/repo/handoff' &&
          web.document.title == 'Overview',
    );
    expect(restoredCollection.isConnected, isFalse);
    expect(
      web.document.documentElement?.getAttribute('data-handoff-fetches'),
      '4',
    );

    _runJavaScript(
      'history.replaceState(history.state,"",'
      '"/repo/handoff?esen.$_collectionId.q=Beta")',
    );
    web.window.dispatchEvent(web.PopStateEvent('popstate'));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(oldSearch.value, 'Beta');
    expect(restoredSearch.value, 'Alpha');

    final current = web.document.querySelector('#esen-seo-content')!;
    (current.querySelector('a')! as web.HTMLElement).click();
    await _waitFor(
      () =>
          web.window.location.pathname == '/repo/handoff/articles' &&
          web.document
                  .querySelector('[data-esen-component="collection"]')
                  ?.getAttribute('data-esen-enhanced') ==
              'true',
    );
    expect(
      web.document
          .querySelectorAll(
            'script[$seoDomFirstLoadableRuntimeAttribute]',
          )
          .length,
      1,
    );
    expect(
      web.document.documentElement?.getAttribute('data-handoff-fetches'),
      '5',
    );
  });

  test('keeps the newest navigation when an older response finishes later',
      () async {
    _removeAll('title');
    _removeAll('[$seoDomFirstNavigationHeadAttribute]');
    _removeAll('script[$seoDomFirstNavigationManifestAttribute]');
    _removeAll('script[data-esen-seo-dom-first-runtime]');
    _removeAll('script[$seoDomFirstLoadableRuntimeAttribute]');
    _removeAll('#esen-seo-content');

    final originalHref = web.window.location.href;
    addTearDown(() {
      _runJavaScript(
        'globalThis.fetch=globalThis.__esenOriginalFetch;'
        'delete globalThis.__esenOriginalFetch',
      );
      web.window.history.replaceState(null, '', originalHref);
      _removeAll('[$seoDomFirstNavigationHeadAttribute]');
      _removeAll('script[$seoDomFirstNavigationManifestAttribute]');
      _removeAll('script[data-esen-seo-dom-first-runtime]');
      _removeAll('script[$seoDomFirstLoadableRuntimeAttribute]');
      _removeAll('#esen-seo-content');
      web.document.documentElement?.removeAttribute('data-handoff-fetches');
    });

    web.window.history.replaceState(null, '', '/handoff-race');
    final manifest = jsonEncode({
      'schema': seoDomFirstRuntimeHandoffManifestSchema,
      'base': '/',
      'profile': _profile,
      'routes': [
        ['/handoff-race', _profile, null],
        [
          '/handoff-race/slow',
          _profile,
          [
            seoDomFirstCollectionRuntimeKind,
            seoDomFirstCollectionHandoffRuntimeSha256,
            seoDomFirstCollectionHandoffRuntimeBytes,
          ],
        ],
        ['/handoff-race/fast', _profile, null],
      ],
    });
    final sourceBody =
        '<div id="esen-seo-content" data-esen-seo-dom-first="true">'
        '<main><h1>Source</h1><a id="slow" href="/handoff-race/slow">'
        'Slow</a><a id="fast" href="/handoff-race/fast">Fast</a>'
        '</main></div>';
    final slowDocument = _document(
      title: 'Slow',
      body: _collectionBody(),
      manifest: manifest,
      collectionRuntime: true,
    );
    final fastDocument = _document(
      title: 'Fast',
      body: '<div id="esen-seo-content" '
          'data-esen-seo-dom-first="true"><main><h1>Fast</h1></main></div>',
      manifest: manifest,
    );

    _mountHead('Source', manifest);
    final source = _mountBody(sourceBody);
    _mockRacingFetch(slowDocument, fastDocument);
    final runtime = web.document.createElement('script')
      ..setAttribute('data-esen-seo-dom-first-runtime', '')
      ..textContent = seoDomFirstNavigationHandoffRuntime;
    web.document.body?.appendChild(runtime);

    (source.querySelector('#slow')! as web.HTMLElement).click();
    (source.querySelector('#fast')! as web.HTMLElement).click();
    await _waitFor(
      () =>
          web.window.location.pathname == '/handoff-race/fast' &&
          web.document.title == 'Fast',
    );
    await Future<void>.delayed(const Duration(milliseconds: 120));

    expect(web.document.title, 'Fast');
    expect(
      web.document.querySelector('#esen-seo-content')?.textContent,
      contains('Fast'),
    );
    expect(
      web.document
          .querySelectorAll('script[$seoDomFirstLoadableRuntimeAttribute]')
          .length,
      0,
    );
    expect(
      web.document.documentElement?.getAttribute('data-handoff-fetches'),
      '2',
    );
  });
}

String _overviewBody() =>
    '<div id="esen-seo-content" data-esen-seo-dom-first="true">'
    '<main><h1>Overview</h1>'
    '<a href="/repo/handoff/articles?esen.$_collectionId.q=Beta">'
    'Open articles</a></main></div>';

String _collectionBody() {
  final collection = const HtmlRenderer.domFirst().render(
    buildSeoCollectionNodes(
      items: [
        (
          title: 'Alpha',
          searchText: 'Alpha guide',
          categories: const ['Guide'],
          sortKey: 2,
          nodes: [SeoNode(tag: 'h2', text: 'Alpha')],
        ),
        (
          title: 'Beta',
          searchText: 'Beta guide',
          categories: const ['Guide'],
          sortKey: 1,
          nodes: [SeoNode(tag: 'h2', text: 'Beta')],
        ),
      ],
      interactionId: _collectionId,
      interactionLabel: 'Articles',
      pageSize: 1,
      synchronizeUrl: true,
    ),
  );
  return '<div id="esen-seo-content" data-esen-seo-dom-first="true">'
      '<main><h1>Articles</h1>$collection'
      '<a id="back-to-overview" href="/repo/handoff">Overview</a>'
      '</main></div>';
}

String _document({
  required String title,
  required String body,
  required String manifest,
  bool collectionRuntime = false,
}) =>
    '<!DOCTYPE html><html lang="en"><head>'
    '<title $seoDomFirstNavigationHeadAttribute>$title</title>'
    '<script type="application/json" '
    '$seoDomFirstNavigationManifestAttribute '
    'data-esen-navigation-profile="$_profile">$manifest</script>'
    '</head><body>$body'
    '${collectionRuntime ? _loadableRuntimeTag() : ''}'
    '<script data-esen-seo-dom-first-runtime></script>'
    '</body></html>';

String _loadableRuntimeTag() =>
    '<script $seoDomFirstLoadableRuntimeAttribute="collection" '
    '$seoDomFirstRuntimeSha256Attribute="'
    '$seoDomFirstCollectionHandoffRuntimeSha256" nonce="fetched-nonce">'
    '$seoDomFirstCollectionHandoffRuntime</script>';

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

Iterable<web.Element> _visibleItems(web.Element root) sync* {
  final items = root.querySelectorAll('[data-esen-collection-item]');
  for (var index = 0; index < items.length; index++) {
    final item = items.item(index) as web.Element?;
    if (item != null && !item.hasAttribute('hidden')) yield item;
  }
}

void _mockFetch(String overviewDocument, String collectionDocument) {
  _runJavaScript(
    'globalThis.__esenOriginalFetch=globalThis.fetch;'
    'document.documentElement.dataset.handoffFetches="0";'
    'globalThis.fetch=async function(u,o){'
    'document.documentElement.dataset.handoffFetches=String('
    'Number(document.documentElement.dataset.handoffFetches)+1);'
    'let articles=new URL(String(u)).pathname.endsWith("/articles");'
    'if(!articles)await new Promise(r=>setTimeout(r,60));'
    'let body=articles?${jsonEncode(collectionDocument)}:'
    '${jsonEncode(overviewDocument)};'
    'return new Response(body,{headers:{'
    '"content-type":"text/html; charset=utf-8"}})}',
  );
}

void _mockRacingFetch(String slowDocument, String fastDocument) {
  _runJavaScript(
    'globalThis.__esenOriginalFetch=globalThis.fetch;'
    'document.documentElement.dataset.handoffFetches="0";'
    'globalThis.fetch=async function(u,o){'
    'document.documentElement.dataset.handoffFetches=String('
    'Number(document.documentElement.dataset.handoffFetches)+1);'
    'let slow=String(u).includes("/slow");'
    'if(slow)await new Promise(r=>setTimeout(r,80));'
    'return new Response(slow?${jsonEncode(slowDocument)}:'
    '${jsonEncode(fastDocument)},{headers:{'
    '"content-type":"text/html; charset=utf-8"}})}',
  );
}

Future<void> _waitFor(bool Function() condition) async {
  for (var index = 0; index < 200; index++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('Timed out waiting for the Collection runtime handoff.');
}

void _removeAll(String selector) {
  final nodes = web.document.querySelectorAll(selector);
  for (var index = nodes.length - 1; index >= 0; index--) {
    final node = nodes.item(index);
    if (node != null) node.parentNode?.removeChild(node);
  }
}

void _runJavaScript(String source) {
  final script = web.document.createElement('script')..textContent = source;
  web.document.body?.appendChild(script);
  script.remove();
}
