@TestOn('browser')
library;

import 'dart:convert';
import 'dart:js_interop';

import 'package:crypto/crypto.dart';
import 'package:esen_seo/server.dart';
import 'package:esen_seo/src/renderer/seo_dom_first_collection_runtime.g.dart';
import 'package:esen_seo/src/renderer/seo_dom_first_navigation_application_handoff_runtime.g.dart';
import 'package:esen_seo/src/renderer/seo_dom_first_runtime_handoff.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;

const _profile = 'applicationRuntimeHandoff.navigation';
const _applicationId = 'application-collection';
const _collectionId = 'application-collection-control';
const _forgedHash =
    '0000000000000000000000000000000000000000000000000000000000000000';

const _applicationSource = seoDomFirstCollectionRuntime;
final _applicationRuntime =
    seoDomFirstApplicationHandoffEnvelope(_applicationSource);
final _applicationSourceBytes = utf8.encode(_applicationSource).length;
final _applicationSourceHash =
    sha256.convert(utf8.encode(_applicationSource)).toString();

void main() {
  test('hands one application Collection runtime across route-local documents',
      () async {
    _cleanDocument();
    final originalHref = web.window.location.href;
    addTearDown(() {
      _restoreFetch();
      web.window.history.replaceState(null, '', originalHref);
      _cleanDocument();
      web.document.documentElement?.removeAttribute('data-handoff-fetches');
    });

    web.window.history.replaceState(null, '', '/repo/overview');
    final manifest = _manifest([
      ['/overview', _profile, null],
      ['/articles', _profile, _descriptor()],
      ['/releases', _profile, _descriptor()],
    ]);
    final overviewDocument = _document(
      title: 'Overview',
      body: _overviewBody(),
      manifest: manifest,
    );
    final articlesDocument = _document(
      title: 'Articles',
      body: _collectionBody(
        title: 'Articles',
        first: 'Alpha',
        second: 'Beta',
        nextPath: '/repo/releases?esen.$_collectionId.q=Gamma',
      ),
      manifest: manifest,
      runtime: _runtimeTag(_applicationRuntime),
    );
    final releasesDocument = _document(
      title: 'Releases',
      body: _collectionBody(
        title: 'Releases',
        first: 'Gamma',
        second: 'Delta',
        nextPath: '/repo/overview',
      ),
      manifest: manifest,
      runtime: _runtimeTag(_applicationRuntime),
    );

    _mountHead('Overview', manifest);
    final initial = _mountBody(_overviewBody());
    _mockDocuments({
      '/repo/overview': overviewDocument,
      '/repo/articles': articlesDocument,
      '/repo/releases': releasesDocument,
    });
    _mountNavigationRuntime();

    (initial.querySelector('a')! as web.HTMLElement).click();
    await _waitFor(
      () =>
          web.window.location.pathname == '/repo/articles' &&
          _enhancedCollection()
                  ?.querySelector('input')
                  ?.getAttribute('value') !=
              '__never__',
    );
    final articles = _enhancedCollection()!;
    final articlesSearch =
        articles.querySelector('input')! as web.HTMLInputElement;
    expect(articlesSearch.value, 'Beta');
    expect(_visibleItems(articles).map((item) => item.textContent), [
      contains('Beta'),
    ]);
    final loadable = web.document.querySelector(
      'script[$seoDomFirstLoadableRuntimeAttribute]',
    )! as web.HTMLScriptElement;
    expect(
      loadable.getAttribute(seoDomFirstLoadableRuntimeAttribute),
      seoDomFirstApplicationRuntimeOwner,
    );
    expect(
      loadable.getAttribute(seoDomFirstApplicationScriptAttribute),
      _applicationId,
    );
    expect(
      loadable.getAttribute(seoDomFirstRuntimeKindAttribute),
      seoDomFirstCollectionRuntimeKind,
    );
    expect(
      loadable.getAttribute(seoDomFirstRuntimeContractAttribute),
      '$seoDomFirstRuntimeContractRevision',
    );
    expect(
      loadable.getAttribute(seoDomFirstRuntimeReadyAttribute),
      'true',
    );
    expect(loadable.nonce, 'trusted-nonce');

    (web.document.querySelector('#next-route')! as web.HTMLElement).click();
    await _waitFor(
      () =>
          web.window.location.pathname == '/repo/releases' &&
          web.document.title == 'Releases' &&
          _enhancedCollection() != null,
    );
    final releases = _enhancedCollection()!;
    final releasesSearch =
        releases.querySelector('input')! as web.HTMLInputElement;
    expect(articles.isConnected, isFalse);
    expect(releasesSearch.value, 'Gamma');
    expect(_visibleItems(releases).map((item) => item.textContent), [
      contains('Gamma'),
    ]);
    expect(
      web.document
          .querySelectorAll('script[$seoDomFirstLoadableRuntimeAttribute]')
          .length,
      1,
    );

    final fetches =
        web.document.documentElement?.getAttribute('data-handoff-fetches');
    _runJavaScript(
      'history.replaceState(history.state,"",'
      '"/repo/releases?esen.$_collectionId.q=Delta")',
    );
    web.window.dispatchEvent(web.PopStateEvent('popstate'));
    await _waitFor(() => releasesSearch.value == 'Delta');
    expect(
      web.document.documentElement?.getAttribute('data-handoff-fetches'),
      fetches,
    );
    expect(_visibleItems(releases).map((item) => item.textContent), [
      contains('Delta'),
    ]);

    (web.document.querySelector('#next-route')! as web.HTMLElement).click();
    await _waitFor(
      () =>
          web.window.location.pathname == '/repo/overview' &&
          web.document.title == 'Overview',
    );
    expect(releases.isConnected, isFalse);
    expect(
      web.document
          .querySelectorAll(
            'script[$seoDomFirstLoadableRuntimeAttribute]',
          )
          .length,
      0,
    );

    web.window.history.back();
    await _waitFor(
      () =>
          web.window.location.pathname == '/repo/releases' &&
          _enhancedCollection() != null,
    );
    final restored = _enhancedCollection()!;
    expect(
      (restored.querySelector('input')! as web.HTMLInputElement).value,
      'Delta',
    );
    expect(releases.isConnected, isFalse);
  });

  test('initializes a direct application document before navigation starts',
      () async {
    _cleanDocument();
    final originalHref = web.window.location.href;
    addTearDown(() {
      _restoreFetch();
      web.window.history.replaceState(null, '', originalHref);
      _cleanDocument();
    });

    web.window.history.replaceState(null, '', '/repo/articles');
    final manifest = _manifest([
      ['/overview', _profile, null],
      ['/articles', _profile, _descriptor()],
    ]);
    final overviewDocument = _document(
      title: 'Overview',
      body: _overviewBody(),
      manifest: manifest,
    );
    _mountHead('Articles', manifest);
    final content = _mountBody(
      _collectionBody(
        title: 'Articles',
        first: 'Alpha',
        second: 'Beta',
        nextPath: '/repo/overview',
      ),
    );
    final applicationScript = _mountApplicationRuntime();

    expect(applicationScript.getAttribute(seoDomFirstRuntimeReadyAttribute),
        'true');
    expect(_enhancedCollection(), isNotNull);
    _mockDocuments({'/repo/overview': overviewDocument});
    _mountNavigationRuntime();

    (content.querySelector('#next-route')! as web.HTMLElement).click();
    await _waitFor(
      () =>
          web.window.location.pathname == '/repo/overview' &&
          web.document.title == 'Overview',
    );
    expect(content.isConnected, isFalse);
    expect(applicationScript.isConnected, isFalse);
  });

  test('does not let a stale application response replace a newer route',
      () async {
    _cleanDocument();
    final originalHref = web.window.location.href;
    addTearDown(() {
      _restoreFetch();
      web.window.history.replaceState(null, '', originalHref);
      _cleanDocument();
    });

    web.window.history.replaceState(null, '', '/race');
    final manifest = _manifest([
      ['/race', _profile, null],
      ['/slow', _profile, _descriptor()],
      ['/fast', _profile, null],
    ], base: '/');
    _mountHead('Race source', manifest);
    final initial = _mountBody(
      '<div id="esen-seo-content" data-esen-seo-dom-first="true">'
      '<main><h1>Race source</h1><a id="slow" href="/slow">Slow</a>'
      '<a id="fast" href="/fast">Fast</a></main></div>',
    );
    final slow = _document(
      title: 'Slow',
      body: _collectionBody(
        title: 'Slow',
        first: 'Old',
        second: 'Response',
        nextPath: '/race',
      ),
      manifest: manifest,
      runtime: _runtimeTag(_applicationRuntime),
    );
    final fast = _document(
      title: 'Fast',
      body: '<div id="esen-seo-content" data-esen-seo-dom-first="true">'
          '<main><h1>Fast</h1></main></div>',
      manifest: manifest,
    );
    _mockRacingDocuments(slow: slow, fast: fast);
    _mountNavigationRuntime();

    (initial.querySelector('#slow')! as web.HTMLElement).click();
    await Future<void>.delayed(const Duration(milliseconds: 5));
    (initial.querySelector('#fast')! as web.HTMLElement).click();
    await _waitFor(
      () =>
          web.window.location.pathname == '/fast' &&
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
          .querySelectorAll(
            'script[$seoDomFirstLoadableRuntimeAttribute]',
          )
          .length,
      0,
    );
  });

  test('rejects unbound application payloads and missing readiness', () async {
    _cleanDocument();
    final originalHref = web.window.location.href;
    addTearDown(() {
      _restoreFetch();
      web.window.history.replaceState(null, '', originalHref);
      _cleanDocument();
      for (final name in const [
        'data-handoff-hard',
        'data-handoff-hard-url',
        'data-handoff-hard-mode',
        'data-handoff-disable-crypto',
      ]) {
        web.document.documentElement?.removeAttribute(name);
      }
    });

    const notReadySource = 'document.currentScript.setAttribute=()=>{}';
    final notReadyHash = sha256.convert(utf8.encode(notReadySource)).toString();
    final notReadyRuntime =
        seoDomFirstApplicationHandoffEnvelope(notReadySource);
    web.window.history.replaceState(null, '', '/security');
    final manifest = _manifest([
      ['/security', _profile, null],
      ['/articles', _profile, _descriptor()],
      [
        '/no-ready',
        _profile,
        _descriptor(
          hash: notReadyHash,
          bytes: utf8.encode(notReadySource).length,
        ),
      ],
    ], base: '/');
    _mountHead('Security source', manifest);
    final initial = _mountBody(
      '<div id="esen-seo-content" data-esen-seo-dom-first="true">'
      '<main><h1>Security source</h1><a href="/articles">Open</a>'
      '</main></div>',
    );
    _mockCases({
      'valid': _securityDocument(manifest, _runtimeTag(_applicationRuntime)),
      'tampered': _securityDocument(
        manifest,
        _runtimeTag('${_applicationSource.substring(
          0,
          _applicationSource.length - 1,
        )}x$seoDomFirstApplicationHandoffEpilogue'),
      ),
      'forged': _securityDocument(
        manifest,
        _runtimeTag(_applicationRuntime, hash: _forgedHash),
      ),
      'wrong-id': _securityDocument(
        manifest,
        _runtimeTag(_applicationRuntime, id: 'other-collection'),
      ),
      'wrong-kind': _securityDocument(
        manifest,
        _runtimeTag(_applicationRuntime, kind: 'tabs'),
      ),
      'wrong-contract': _securityDocument(
        manifest,
        _runtimeTag(_applicationRuntime, contract: 2),
      ),
      'wrong-epilogue': _securityDocument(
        manifest,
        _runtimeTag(
          '$_applicationSource\n;delete document.documentElement.dataset.'
          'esenCollectionPending',
        ),
      ),
      'unknown-attribute': _securityDocument(
        manifest,
        _runtimeTag(_applicationRuntime).replaceFirst(
          '<script ',
          '<script data-unexpected="true" ',
        ),
      ),
      'duplicate': _securityDocument(
        manifest,
        '${_runtimeTag(_applicationRuntime)}'
        '${_runtimeTag(_applicationRuntime)}',
      ),
      'missing': _securityDocument(manifest, ''),
      'no-ready': _securityDocument(
        manifest,
        _runtimeTag(
          notReadyRuntime,
          hash: notReadyHash,
        ),
      ),
    });
    _mountInstrumentedNavigationRuntime();

    final link = initial.querySelector('a')! as web.HTMLAnchorElement;
    var fallbackCount = 0;

    Future<void> expectRejected(String testCase) async {
      link.href = '/articles?case=$testCase';
      link.click();
      await _waitForHardFallback(++fallbackCount);
      expect(initial.isConnected, isTrue, reason: testCase);
      expect(web.document.title, 'Security source', reason: testCase);
      expect(
        web.document
            .querySelectorAll(
              'script[$seoDomFirstLoadableRuntimeAttribute]',
            )
            .length,
        0,
        reason: testCase,
      );
    }

    web.document.documentElement
        ?.setAttribute('data-handoff-disable-crypto', '');
    await expectRejected('valid');
    web.document.documentElement
        ?.removeAttribute('data-handoff-disable-crypto');
    for (final testCase in const [
      'tampered',
      'forged',
      'wrong-id',
      'wrong-kind',
      'wrong-contract',
      'wrong-epilogue',
      'unknown-attribute',
      'duplicate',
      'missing',
    ]) {
      await expectRejected(testCase);
    }

    link.href = '/no-ready?case=no-ready';
    link.click();
    await _waitForHardFallback(++fallbackCount);
    expect(initial.isConnected, isFalse);
    expect(web.document.title, 'Rejected target');
    expect(
      web.document.documentElement?.getAttribute('data-handoff-hard-mode'),
      'reload',
    );
    expect(
      web.document
          .querySelector('script[$seoDomFirstLoadableRuntimeAttribute]')
          ?.getAttribute(seoDomFirstRuntimeReadyAttribute),
      isNull,
    );
  });
}

List<Object?> _descriptor({String? hash, int? bytes}) => [
      seoDomFirstApplicationRuntimeOwner,
      seoDomFirstCollectionRuntimeKind,
      _applicationId,
      seoDomFirstRuntimeContractRevision,
      hash ?? _applicationSourceHash,
      bytes ?? _applicationSourceBytes,
    ];

String _manifest(List<List<Object?>> routes, {String base = '/repo'}) =>
    jsonEncode({
      'schema': seoDomFirstApplicationRuntimeHandoffManifestSchema,
      'base': base,
      'profile': _profile,
      'routes': routes,
    });

String _overviewBody() =>
    '<div id="esen-seo-content" data-esen-seo-dom-first="true">'
    '<main><h1>Overview</h1>'
    '<a href="/repo/articles?esen.$_collectionId.q=Beta">Open articles</a>'
    '</main></div>';

String _collectionBody({
  required String title,
  required String first,
  required String second,
  required String nextPath,
}) {
  final collection = const HtmlRenderer.domFirst().render(
    buildSeoCollectionNodes(
      items: [
        (
          title: first,
          searchText: '$first record',
          categories: const ['Docs'],
          sortKey: 2,
          nodes: [SeoNode(tag: 'h2', text: first)],
        ),
        (
          title: second,
          searchText: '$second record',
          categories: const ['Docs'],
          sortKey: 1,
          nodes: [SeoNode(tag: 'h2', text: second)],
        ),
      ],
      interactionId: _collectionId,
      interactionLabel: title,
      pageSize: 1,
      synchronizeUrl: true,
    ),
  );
  return '<div id="esen-seo-content" data-esen-seo-dom-first="true">'
      '<main><h1>$title</h1>$collection'
      '<a id="next-route" href="$nextPath">Next route</a>'
      '</main></div>';
}

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

String _securityDocument(String manifest, String runtime) => _document(
      title: 'Rejected target',
      body: '<div id="esen-seo-content" data-esen-seo-dom-first="true">'
          '<main><h1>Rejected target</h1></main></div>',
      manifest: manifest,
      runtime: runtime,
    );

String _runtimeTag(
  String source, {
  String id = _applicationId,
  String kind = seoDomFirstCollectionRuntimeKind,
  int contract = seoDomFirstRuntimeContractRevision,
  String? hash,
}) =>
    '<script $seoDomFirstLoadableRuntimeAttribute="'
    '$seoDomFirstApplicationRuntimeOwner" '
    '$seoDomFirstApplicationScriptAttribute="$id" '
    '$seoDomFirstRuntimeKindAttribute="$kind" '
    '$seoDomFirstRuntimeContractAttribute="$contract" '
    '$seoDomFirstRuntimeSha256Attribute="${hash ?? _applicationSourceHash}" '
    'nonce="fetched-nonce">$source</script>';

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

void _mountNavigationRuntime() {
  final runtime = web.document.createElement('script')
    ..setAttribute('data-esen-seo-dom-first-runtime', '')
    ..setAttribute('nonce', 'trusted-nonce')
    ..textContent = seoDomFirstNavigationApplicationHandoffRuntime;
  web.document.body?.appendChild(runtime);
}

web.HTMLScriptElement _mountApplicationRuntime() {
  final runtime = web.document.createElement('script') as web.HTMLScriptElement
    ..setAttribute(
      seoDomFirstLoadableRuntimeAttribute,
      seoDomFirstApplicationRuntimeOwner,
    )
    ..setAttribute(seoDomFirstApplicationScriptAttribute, _applicationId)
    ..setAttribute(
      seoDomFirstRuntimeKindAttribute,
      seoDomFirstCollectionRuntimeKind,
    )
    ..setAttribute(
      seoDomFirstRuntimeContractAttribute,
      '$seoDomFirstRuntimeContractRevision',
    )
    ..setAttribute(seoDomFirstRuntimeSha256Attribute, _applicationSourceHash)
    ..setAttribute('nonce', 'trusted-nonce')
    ..textContent = _applicationRuntime;
  web.document.body?.appendChild(runtime);
  return runtime;
}

void _mountInstrumentedNavigationRuntime() {
  const hard =
      'hard=(url,pop)=>{delete d.documentElement.dataset.esenNavigationPending;if(pop)location.reload();else location.assign(url.href)}';
  const observedHard =
      'hard=(url,pop)=>{delete d.documentElement.dataset.esenNavigationPending;d.documentElement.dataset.handoffHard=String(Number(d.documentElement.dataset.handoffHard||0)+1);d.documentElement.dataset.handoffHardUrl=url.href;d.documentElement.dataset.handoffHardMode=pop?"reload":"assign"}';
  const subtle = 'let subtle=globalThis.crypto&&globalThis.crypto.subtle';
  const observedSubtle =
      'let subtle=d.documentElement.hasAttribute("data-handoff-disable-crypto")?null:globalThis.crypto&&globalThis.crypto.subtle';
  final instrumented = seoDomFirstNavigationApplicationHandoffRuntime
      .replaceFirst(hard, observedHard)
      .replaceFirst(subtle, observedSubtle);
  expect(instrumented, contains(observedHard));
  expect(instrumented, contains(observedSubtle));
  final runtime = web.document.createElement('script')
    ..setAttribute('data-esen-seo-dom-first-runtime', '')
    ..textContent = instrumented;
  web.document.body?.appendChild(runtime);
}

web.Element? _enhancedCollection() {
  final collection = web.document.querySelector(
    '[data-esen-component="collection"]',
  );
  return collection?.getAttribute('data-esen-enhanced') == 'true'
      ? collection
      : null;
}

Iterable<web.Element> _visibleItems(web.Element root) sync* {
  final items = root.querySelectorAll('[data-esen-collection-item]');
  for (var index = 0; index < items.length; index++) {
    final item = items.item(index) as web.Element?;
    if (item != null && !item.hasAttribute('hidden')) yield item;
  }
}

void _mockDocuments(Map<String, String> documents) {
  _runJavaScript(
    'globalThis.__esenOriginalFetch=globalThis.fetch;'
    'globalThis.__esenHandoffDocuments=${jsonEncode(documents)};'
    'document.documentElement.dataset.handoffFetches="0";'
    'globalThis.fetch=async function(u,o){'
    'document.documentElement.dataset.handoffFetches=String('
    'Number(document.documentElement.dataset.handoffFetches)+1);'
    'let body=globalThis.__esenHandoffDocuments[new URL(String(u)).pathname];'
    'return new Response(body,{headers:{'
    '"content-type":"text/html; charset=utf-8"}})}',
  );
}

void _mockCases(Map<String, String> documents) {
  _runJavaScript(
    'globalThis.__esenOriginalFetch=globalThis.fetch;'
    'globalThis.__esenHandoffDocuments=${jsonEncode(documents)};'
    'globalThis.fetch=async function(u,o){'
    'let key=new URL(String(u),location.href).searchParams.get("case");'
    'return new Response(globalThis.__esenHandoffDocuments[key],{headers:{'
    '"content-type":"text/html; charset=utf-8"}})}',
  );
}

void _mockRacingDocuments({required String slow, required String fast}) {
  _runJavaScript(
    'globalThis.__esenOriginalFetch=globalThis.fetch;'
    'globalThis.fetch=async function(u,o){'
    'let isSlow=new URL(String(u),location.href).pathname==="/slow";'
    'if(isSlow)await new Promise(r=>setTimeout(r,80));'
    'return new Response(isSlow?${jsonEncode(slow)}:${jsonEncode(fast)},'
    '{headers:{"content-type":"text/html; charset=utf-8"}})}',
  );
}

void _restoreFetch() {
  _runJavaScript(
    'if(globalThis.__esenOriginalFetch)'
    'globalThis.fetch=globalThis.__esenOriginalFetch;'
    'delete globalThis.__esenOriginalFetch;'
    'delete globalThis.__esenHandoffDocuments',
  );
}

Future<void> _waitFor(bool Function() condition) async {
  for (var index = 0; index < 250; index++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('Timed out waiting for the application Collection handoff.');
}

Future<void> _waitForHardFallback(int count) async {
  await _waitFor(
    () =>
        web.document.documentElement?.getAttribute('data-handoff-hard') ==
        '$count',
  );
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
