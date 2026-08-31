@TestOn('browser')
library;

import 'dart:convert';
import 'dart:js_interop';

import 'package:esen_seo/core.dart';
import 'package:esen_seo/src/renderer/seo_dom_first_navigation_prefetch_runtime.g.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;

const _profile = 'navigation.prefetch';

void main() {
  test('prefetches only intended validated documents and consumes them once',
      () async {
    _cleanDocument();
    final originalHref = web.window.location.href;
    addTearDown(() {
      _restoreBrowserGlobals();
      _cleanDocument();
      web.window.history.replaceState(null, '', originalHref);
    });

    web.window.history.replaceState(null, '', '/?prefetch-start=1');
    final manifest = jsonEncode({
      'schema': seoDomFirstNavigationManifestSchema,
      'base': '/',
      'profile': _profile,
      'routes': [
        ['/', _profile],
        ['/other', null],
      ],
    });
    final documents = <String, String>{
      'cached': _document(
        'Cached',
        manifest,
        '<h2 id="cached-target">Cached target</h2>'
            '<a id="redirect-link" href="?redirect=1">Redirect</a>',
      ),
      'redirect': _document(
        'Redirected',
        manifest,
        '<a id="no-store-link" href="?no-store=1">No store</a>',
      ),
      'no-store': _document(
        'No store',
        manifest,
        '<a id="no-cache-link" href="?no-cache=1">No cache</a>',
      ),
      'no-cache': _document(
        'No cache',
        manifest,
        '<a id="max-age-link" href="?max-age=1">Max age</a>',
      ),
      'max-age': _document(
        'Max age',
        manifest,
        '<a id="pragma-link" href="?pragma=1">Pragma</a>',
      ),
      'pragma': _document(
        'Pragma',
        manifest,
        '<a id="vary-link" href="?vary=1">Vary</a>',
      ),
      'vary': _document(
        'Vary',
        manifest,
        '<a id="invalid-link" href="?invalid=1">Invalid first</a>',
      ),
      'invalid': _document(
        'Recovered',
        manifest,
        '<a id="slow-a-link" href="?slow-a=1">Slow A</a>'
            '<a id="slow-b-link" href="?slow-b=1">Slow B</a>',
      ),
      'slow-b': _document(
        'Slow B',
        manifest,
        '<a id="short-link" href="?short=1">Short cache</a>',
      ),
      'short': _document(
        'Short cache',
        manifest,
        '<a id="ttl-link" href="?ttl=1">TTL</a>',
      ),
      'ttl': _document(
        'TTL',
        manifest,
        '<a id="save-link" href="?save=1">Save data</a>',
      ),
      'save': _document('Done', manifest, '<p id="done">Done</p>'),
    };

    _installInitialDocument(manifest);
    _mockFetch(documents, manifest);
    _runJavaScript(
      'globalThis.__esenOriginalDateNow=Date.now;'
      'globalThis.__esenNow=1000000;Date.now=()=>globalThis.__esenNow',
    );
    final runtime = web.document.createElement('script')
      ..setAttribute('data-esen-seo-dom-first-runtime', '')
      ..textContent = seoDomFirstNavigationPrefetchRuntime;
    web.document.body?.appendChild(runtime);

    for (final id in [
      'fragment-link',
      'download-link',
      'target-link',
      'external-link',
      'incompatible-link',
    ]) {
      _pointerIntent(id);
    }
    await _settle();
    expect(_fetchTotal, 0);

    _pointerIntent('cached-link');
    await _waitFor(() => _fetchCount('cached') == 1);
    await _settle();
    expect(web.document.title, 'Initial');
    expect(web.window.location.search, '?prefetch-start=1');
    expect(
      web.document
          .querySelector('#esen-seo-content')
          ?.getAttribute('aria-busy'),
      isNull,
    );

    _pointerIntent('cached-link');
    await _settle();
    expect(_fetchCount('cached'), 1);
    expect(_click('cached-link'), isTrue);
    await _waitFor(() => web.document.title == 'Cached');
    expect(_fetchCount('cached'), 1);
    expect(web.window.location.hash, '#cached-target');
    expect(web.document.activeElement?.id, 'cached-target');

    _pointerIntent('redirect-link');
    await _waitFor(() => _fetchCount('redirect') == 1);
    await _settle();
    expect(_click('redirect-link'), isTrue);
    await _waitFor(() => web.document.title == 'Redirected');
    expect(_fetchCount('redirect'), 1);
    expect(web.window.location.search, '?redirected=1');

    await _expectNotRetained('no-store-link', 'no-store', 'No store');
    await _expectNotRetained('no-cache-link', 'no-cache', 'No cache');
    await _expectNotRetained('max-age-link', 'max-age', 'Max age');
    await _expectNotRetained('pragma-link', 'pragma', 'Pragma');
    await _expectNotRetained('vary-link', 'vary', 'Vary');

    _pointerIntent('invalid-link');
    await _waitFor(() => _fetchCount('invalid') == 1);
    await _settle();
    expect(web.document.title, 'Vary');
    expect(web.window.location.search, '?vary=1');
    expect(
      web.document.documentElement
          ?.hasAttribute('data-esen-navigation-pending'),
      isFalse,
    );
    expect(_click('invalid-link'), isTrue);
    await _waitFor(() => web.document.title == 'Recovered');
    expect(_fetchCount('invalid'), 2);

    _pointerIntent('slow-a-link');
    await _waitFor(() => _fetchCount('slow-a') == 1);
    _pointerIntent('slow-b-link');
    await _waitFor(
      () => _fetchCount('slow-b') == 1 && _abortedFetches == 1,
    );
    await _settle();
    expect(_click('slow-b-link'), isTrue);
    await _waitFor(() => web.document.title == 'Slow B');
    expect(_fetchCount('slow-b'), 1);

    _pointerIntent('short-link');
    await _waitFor(() => _fetchCount('short') == 1);
    await _settle();
    _runJavaScript('globalThis.__esenNow+=1001');
    expect(_click('short-link'), isTrue);
    await _waitFor(() => web.document.title == 'Short cache');
    expect(_fetchCount('short'), 2);

    _pointerIntent('ttl-link');
    await _waitFor(() => _fetchCount('ttl') == 1);
    await _settle();
    _runJavaScript('globalThis.__esenNow+=10001');
    expect(_click('ttl-link'), isTrue);
    await _waitFor(() => web.document.title == 'TTL');
    expect(_fetchCount('ttl'), 2);

    _setConnection(saveData: true, effectiveType: '4g');
    _pointerIntent('save-link');
    await _settle();
    expect(_fetchCount('save'), 0);
    _setConnection(saveData: false, effectiveType: '2g');
    _pointerIntent('save-link');
    await _settle();
    expect(_fetchCount('save'), 0);
    _setConnection(saveData: false, effectiveType: '4g');
    _focusIntent('save-link');
    await _waitFor(() => _fetchCount('save') == 1);
    await _settle();
    expect(_click('save-link'), isTrue);
    await _waitFor(() => web.document.title == 'Done');
    expect(_fetchCount('save'), 1);
    expect(web.document.querySelector('#done')?.textContent, 'Done');
  });
}

Future<void> _expectNotRetained(
  String linkId,
  String key,
  String title,
) async {
  _pointerIntent(linkId);
  await _waitFor(() => _fetchCount(key) == 1);
  await _settle();
  expect(_click(linkId), isTrue);
  await _waitFor(() => web.document.title == title);
  expect(_fetchCount(key), 2);
}

void _installInitialDocument(String manifest) {
  final title = web.document.createElement('title')
    ..setAttribute(seoDomFirstNavigationHeadAttribute, '')
    ..textContent = 'Initial';
  final manifestNode = web.document.createElement('script')
    ..setAttribute('type', 'application/json')
    ..setAttribute(seoDomFirstNavigationManifestAttribute, '')
    ..setAttribute('data-esen-navigation-profile', _profile)
    ..textContent = manifest;
  web.document.head
    ?..appendChild(title)
    ..appendChild(manifestNode);
  final holder = web.document.createElement('div')
    ..setHTMLUnsafe(
      ('<div id="esen-seo-content" data-esen-seo-dom-first="true">'
              '<main><h1>Initial</h1>'
              '<a id="cached-link" href="?cached=1#cached-target">Cached</a>'
              '<a id="fragment-link" href="#local">Fragment</a>'
              '<a id="download-link" href="?download=1" download>Download</a>'
              '<a id="target-link" href="?target=1" target="_blank">Target</a>'
              '<a id="external-link" href="https://example.invalid/">External</a>'
              '<a id="incompatible-link" href="/other">Other</a>'
              '<p id="local">Local</p></main></div>')
          .toJS,
    );
  web.document.body?.appendChild(holder.firstElementChild!);
}

String _document(String title, String manifest, String content) =>
    '<!DOCTYPE html><html lang="en"><head>'
    '<title $seoDomFirstNavigationHeadAttribute>$title</title>'
    '<script type="application/json" '
    '$seoDomFirstNavigationManifestAttribute '
    'data-esen-navigation-profile="$_profile">$manifest</script>'
    '</head><body>'
    '<div id="esen-seo-content" data-esen-seo-dom-first="true">'
    '<main><h1>$title</h1>$content</main></div>'
    '<script data-esen-seo-dom-first-runtime></script></body></html>';

void _mockFetch(Map<String, String> documents, String manifest) {
  final invalid = '<!DOCTYPE html><html><head>'
      '<title $seoDomFirstNavigationHeadAttribute>Invalid</title>'
      '<script type="application/json" '
      '$seoDomFirstNavigationManifestAttribute '
      'data-esen-navigation-profile="$_profile">$manifest</script>'
      '</head><body>'
      '<div id="esen-seo-content" data-esen-seo-dom-first="true">'
      '<main><script>bad()</script></main></div>'
      '<script data-esen-seo-dom-first-runtime></script></body></html>';
  _runJavaScript(
    'globalThis.__esenOriginalFetch=globalThis.fetch;'
    'globalThis.__esenConnectionOwn=Object.getOwnPropertyDescriptor('
    'navigator,"connection");globalThis.__esenFetchCounts={};'
    'document.documentElement.dataset.fetchTotal="0";'
    'document.documentElement.dataset.fetchAborted="0";'
    'globalThis.fetch=function(raw,options){'
    'let url=new URL(String(raw),location.href),key=[...url.searchParams.keys()][0]||"none",'
    'counts=globalThis.__esenFetchCounts;counts[key]=(counts[key]||0)+1;'
    'document.documentElement.dataset.fetchTotal=String('
    'Number(document.documentElement.dataset.fetchTotal)+1);'
    'document.documentElement.setAttribute("data-fetch-"+key,String(counts[key]));'
    'if(key==="slow-a")return new Promise((resolve,reject)=>{'
    'options.signal.addEventListener("abort",()=>{'
    'document.documentElement.dataset.fetchAborted=String('
    'Number(document.documentElement.dataset.fetchAborted)+1);'
    'reject(new DOMException("Aborted","AbortError"))},{once:true})});'
    'let bodies=${jsonEncode(documents)},body=bodies[key]||bodies.save,'
    'headers={"content-type":"text/html; charset=utf-8"};'
    'if(key==="invalid"&&counts[key]===1)body=${jsonEncode(invalid)};'
    'if(key==="no-store")headers["cache-control"]="no-store";'
    'if(key==="no-cache")headers["cache-control"]="no-cache";'
    'if(key==="max-age")headers["cache-control"]="max-age=0";'
    'if(key==="short")headers["cache-control"]="max-age=1";'
    'if(key==="pragma")headers.pragma="no-cache";'
    'if(key==="vary")headers.vary="*";'
    'let response=new Response(body,{headers});'
    'if(key==="redirect")Object.defineProperty(response,"url",{'
    'value:new URL("?redirected=1",location.href).href});'
    'return Promise.resolve(response)}',
  );
}

int get _fetchTotal => int.parse(
      web.document.documentElement?.getAttribute('data-fetch-total') ?? '0',
    );

int get _abortedFetches => int.parse(
      web.document.documentElement?.getAttribute('data-fetch-aborted') ?? '0',
    );

int _fetchCount(String key) => int.parse(
      web.document.documentElement?.getAttribute('data-fetch-$key') ?? '0',
    );

void _pointerIntent(String id) {
  _runJavaScript(
    'document.getElementById(${jsonEncode(id)}).dispatchEvent('
    'new PointerEvent("pointerover",{bubbles:true}))',
  );
}

void _focusIntent(String id) {
  (web.document.getElementById(id)! as web.HTMLElement).focus();
}

bool _click(String id) {
  web.document.documentElement?.removeAttribute('data-click-prevented');
  _runJavaScript(
    'window.addEventListener("click",event=>{'
    'document.documentElement.dataset.clickPrevented=String('
    'event.defaultPrevented);event.preventDefault()},{once:true})',
  );
  web.document.getElementById(id)!.dispatchEvent(
        web.MouseEvent(
          'click',
          web.MouseEventInit(bubbles: true, cancelable: true),
        ),
      );
  return web.document.documentElement?.getAttribute('data-click-prevented') ==
      'true';
}

void _setConnection({required bool saveData, required String effectiveType}) {
  _runJavaScript(
    'Object.defineProperty(navigator,"connection",{configurable:true,'
    'value:{saveData:$saveData,effectiveType:${jsonEncode(effectiveType)}}})',
  );
}

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 30));

Future<void> _waitFor(bool Function() condition) async {
  for (var index = 0; index < 150; index++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('Timed out waiting for DOM-first prefetch state.');
}

void _restoreBrowserGlobals() {
  _runJavaScript(
    'if(globalThis.__esenOriginalFetch)globalThis.fetch='
    'globalThis.__esenOriginalFetch;'
    'if(globalThis.__esenOriginalDateNow)Date.now='
    'globalThis.__esenOriginalDateNow;'
    'try{delete navigator.connection;if(globalThis.__esenConnectionOwn)'
    'Object.defineProperty(navigator,"connection",'
    'globalThis.__esenConnectionOwn)}catch(_){};'
    'delete globalThis.__esenOriginalFetch;'
    'delete globalThis.__esenOriginalDateNow;delete globalThis.__esenNow;'
    'delete globalThis.__esenConnectionOwn;delete globalThis.__esenFetchCounts',
  );
}

void _cleanDocument() {
  for (final selector in [
    '#esen-seo-content',
    'title',
    '[$seoDomFirstNavigationHeadAttribute]',
    'script[$seoDomFirstNavigationManifestAttribute]',
    'script[data-esen-seo-dom-first-runtime]',
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
