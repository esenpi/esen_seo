@TestOn('browser')
library;

import 'dart:convert';
import 'dart:js_interop';

import 'package:crypto/crypto.dart';
import 'package:esen_seo/server.dart';
import 'package:esen_seo/src/renderer/dom_first_carousel_adapter_web.dart';
import 'package:esen_seo/src/renderer/seo_dom_first_navigation_application_profile_runtime.g.dart';
import 'package:esen_seo/src/renderer/seo_dom_first_runtime_handoff.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;

const _profile = 'applicationRuntimeHandoff.navigation.application.'
    'carousel.product-carousel';
const _applicationId = 'product-carousel';
const _interactionId = 'product-carousel-control';
const _enhanceEvent = 'esen-seo:test-carousel-handoff';
const _applicationSource =
    'document.dispatchEvent(new Event("$_enhanceEvent"))';
final _applicationSourceBytes = utf8.encode(_applicationSource).length;
final _applicationSourceHash =
    sha256.convert(utf8.encode(_applicationSource)).toString();
final _applicationRuntime = seoDomFirstApplicationHandoffEnvelope(
  _applicationSource,
  kind: 'carousel',
);

void main() {
  test('hands one Carousel artifact across fresh route documents', () async {
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
      title: 'Basic gallery',
      body: _carouselBody(
        title: 'Basic gallery',
        initialIndex: 0,
        nextPath: '/repo/advanced',
      ),
      manifest: manifest,
      runtime: _runtimeTag(),
    );
    final advancedDocument = _document(
      title: 'Advanced gallery',
      body: _carouselBody(
        title: 'Advanced gallery',
        initialIndex: 1,
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
          _enhancedCarousel() != null,
    );
    final basic = _enhancedCarousel()!;
    expect(_selectedIndex(basic), 0);
    _next(basic).click();
    expect(
      _selectedIndex(basic),
      2,
      reason: 'the application transition skips the middle slide',
    );
    final firstRuntime = web.document.querySelector(
      'script[$seoDomFirstLoadableRuntimeAttribute]',
    )! as web.HTMLScriptElement;
    expect(
      firstRuntime.getAttribute(seoDomFirstRuntimeKindAttribute),
      'carousel',
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
          _enhancedCarousel() != null &&
          _enhancedCarousel() != basic,
    );
    final advanced = _enhancedCarousel()!;
    expect(basic.isConnected, isFalse);
    expect(_selectedIndex(advanced), 1);
    final advancedNext = _next(advanced)..focus();
    _keydown(advancedNext, 'End');
    expect(_selectedIndex(advanced), 2);
    expect(web.document.activeElement?.id, '$_interactionId-next');
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
    expect(_enhancedCarousel(), isNull);
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
          _enhancedCarousel() != null,
    );
    final restored = _enhancedCarousel()!;
    expect(restored, isNot(same(advanced)));
    expect(_selectedIndex(restored), 1);
  });

  test('initializes direct Carousel from its delivered fragment target',
      () async {
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
      '/repo/direct#$_interactionId-slide-2',
    );
    final manifest = _manifest([
      ['/direct', _profile, _descriptor()],
      ['/overview', _profile, null],
    ]);
    final body = _carouselBody(
      title: 'Direct gallery',
      initialIndex: 0,
      nextPath: '/repo/overview',
    );
    final overviewDocument = _document(
      title: 'Overview',
      body: _overviewBody(),
      manifest: manifest,
    );
    _mountHead('Direct gallery', manifest);
    final direct = _mountBody(body);

    expect(direct.querySelectorAll('button'), isEmpty);
    expect(direct.textContent, contains('Overview content'));
    expect(direct.textContent, contains('Details content'));
    expect(direct.textContent, contains('Delivery content'));
    web.document.documentElement
        ?.setAttribute('data-esen-interaction-pending', '1');
    final runtime = _mountApplicationRuntime();
    final carousel = _enhancedCarousel()!;
    expect(_selectedIndex(carousel), 2);
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
    expect(carousel.isConnected, isFalse);
    expect(_enhancedCarousel(), isNull);
  });
}

SeoCarouselState _carouselTransition(
  SeoCarouselState state,
  SeoCarouselAction action,
) {
  if (action is SeoCarouselNext && state.index == 0 && state.count > 2) {
    return SeoCarouselState(index: 2, count: state.count);
  }
  return transitionSeoCarousel(state, action);
}

List<Object?> _descriptor() => [
      seoDomFirstApplicationRuntimeOwner,
      'carousel',
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
    '<a href="/repo/basic">Open product carousel</a>'
    '</main></div>';

String _carouselBody({
  required String title,
  required int initialIndex,
  required String nextPath,
}) {
  final carousel = const HtmlRenderer.domFirst().render(
    buildSeoCarouselNodes(
      slides: _slideEntries(),
      interactionId: _interactionId,
      interactionLabel: '$title images',
      initialIndex: initialIndex,
    ),
  );
  return '<div id="esen-seo-content" data-esen-seo-dom-first="true">'
      '<main><h1>$title</h1>$carousel'
      '<a id="next-route" href="$nextPath">Next route</a>'
      '</main></div>';
}

List<SeoCarouselComponentEntry> _slideEntries() => [
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
    '$seoDomFirstRuntimeKindAttribute="carousel" '
    '$seoDomFirstRuntimeContractAttribute="'
    '$seoDomFirstRuntimeContractRevision" '
    '$seoDomFirstRuntimeSha256Attribute="$_applicationSourceHash" '
    'nonce="fetched-nonce">$_applicationRuntime</script>';

JSFunction _mountEnhanceListener() {
  final listener = ((web.Event _) {
    enhanceSeoDomFirstCarousels(transition: _carouselTransition);
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
    ..setAttribute(seoDomFirstRuntimeKindAttribute, 'carousel')
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
    'document.documentElement.dataset.carouselHandoffArmed='
    'history.state&&history.state.esenSeoNavigation===1?"1":"0"',
  );
  return web.document.documentElement
          ?.getAttribute('data-carousel-handoff-armed') ==
      '1';
}

web.Element? _enhancedCarousel() {
  final carousel = web.document.querySelector(
    '[data-esen-component="carousel"]',
  );
  return carousel?.getAttribute('data-esen-enhanced') == 'true'
      ? carousel
      : null;
}

web.HTMLElement _next(web.Element root) => root.querySelector(
      '#$_interactionId-next',
    )! as web.HTMLElement;

int _selectedIndex(web.Element root) {
  final slides = root.querySelectorAll('[data-esen-carousel-slide]');
  for (var index = 0; index < slides.length; index++) {
    if (!(slides.item(index)! as web.Element).hasAttribute('hidden')) {
      return index;
    }
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
    'delete document.documentElement.dataset.carouselHandoffArmed;',
  );
  web.document.documentElement
      ?.removeAttribute('data-esen-interaction-pending');
}

Future<void> _waitFor(bool Function() condition) async {
  for (var index = 0; index < 250; index++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('Timed out waiting for the Carousel runtime handoff.');
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
