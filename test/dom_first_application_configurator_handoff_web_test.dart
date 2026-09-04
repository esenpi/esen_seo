@TestOn('browser')
library;

import 'dart:convert';
import 'dart:js_interop';

import 'package:crypto/crypto.dart';
import 'package:esen_seo/server.dart';
import 'package:esen_seo/src/components/seo_configurator_component.dart';
import 'package:esen_seo/src/components/seo_configurator_transition.dart';
import 'package:esen_seo/src/renderer/dom_first_configurator_adapter_web.dart';
import 'package:esen_seo/src/renderer/seo_dom_first_navigation_application_profile_runtime.g.dart';
import 'package:esen_seo/src/renderer/seo_dom_first_runtime_handoff.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;

const _profile = 'applicationRuntimeHandoff.navigation.application.'
    'configurator.pricing-configurator';
const _applicationId = 'pricing-configurator';
const _interactionId = 'pricing-calculator';
const _enhanceEvent = 'esen-seo:test-configurator-handoff';
const _applicationSource =
    'document.dispatchEvent(new Event("$_enhanceEvent"))';
final _applicationRuntime = seoDomFirstApplicationHandoffEnvelope(
  _applicationSource,
  kind: 'configurator',
);
final _applicationSourceBytes = utf8.encode(_applicationSource).length;
final _applicationSourceHash =
    sha256.convert(utf8.encode(_applicationSource)).toString();

const _constraints = SeoConfiguratorConstraints(
  choiceCount: 2,
  minQuantity: 1,
  maxQuantity: 5,
);

void main() {
  test('hands one Configurator artifact across fresh route documents',
      () async {
    _cleanDocument();
    final originalHref = web.window.location.href;
    late JSFunction enhanceListener;
    enhanceListener = ((web.Event _) {
      enhanceSeoDomFirstConfigurators(
        interactionIds: const {_interactionId},
        transition: transitionSeoConfigurator,
        project: _pricingView,
      );
    }).toJS;
    web.document.addEventListener(_enhanceEvent, enhanceListener);
    addTearDown(() {
      web.document.removeEventListener(_enhanceEvent, enhanceListener);
      _restoreFetch();
      web.window.history.replaceState(null, '', originalHref);
      _cleanDocument();
    });

    web.window.history.replaceState(null, '', '/repo/overview');
    final manifest = _manifest([
      ['/overview', _profile, null],
      ['/pricing', _profile, _descriptor()],
      ['/enterprise', _profile, _descriptor()],
    ]);
    final overviewDocument = _document(
      title: 'Overview',
      body: _overviewBody(),
      manifest: manifest,
    );
    final pricingDocument = _document(
      title: 'Pricing',
      body: _configuratorBody(
        title: 'Pricing',
        initialQuantity: 1,
        nextPath: '/repo/enterprise',
      ),
      manifest: manifest,
      runtime: _runtimeTag(_applicationRuntime),
    );
    final enterpriseDocument = _document(
      title: 'Enterprise',
      body: _configuratorBody(
        title: 'Enterprise',
        initialQuantity: 3,
        nextPath: '/repo/overview',
      ),
      manifest: manifest,
      runtime: _runtimeTag(_applicationRuntime),
    );

    _mountHead('Overview', manifest);
    final initial = _mountBody(_overviewBody());
    _mockDocuments({
      '/repo/overview': overviewDocument,
      '/repo/pricing': pricingDocument,
      '/repo/enterprise': enterpriseDocument,
    });
    _mountNavigationRuntime();

    (initial.querySelector('a')! as web.HTMLElement).click();
    await _waitFor(
      () =>
          web.window.location.pathname == '/repo/pricing' &&
          _enhancedConfigurator() != null,
    );
    final pricing = _enhancedConfigurator()!;
    expect(_quantity(pricing), '1');
    expect(_price(pricing), 'EUR 10');
    (pricing.querySelector('[data-esen-configurator-increment]')!
            as web.HTMLElement)
        .click();
    expect(_quantity(pricing), '2');
    expect(_price(pricing), 'EUR 20');
    final firstRuntime = web.document.querySelector(
      'script[$seoDomFirstLoadableRuntimeAttribute]',
    )! as web.HTMLScriptElement;
    expect(
      firstRuntime.getAttribute(seoDomFirstRuntimeKindAttribute),
      'configurator',
    );
    expect(
      firstRuntime.getAttribute(seoDomFirstRuntimeReadyAttribute),
      'true',
    );
    expect(firstRuntime.nonce, 'trusted-nonce');

    (web.document.querySelector('#next-route')! as web.HTMLElement).click();
    await _waitFor(
      () =>
          web.window.location.pathname == '/repo/enterprise' &&
          _enhancedConfigurator() != null &&
          _enhancedConfigurator() != pricing,
    );
    final enterprise = _enhancedConfigurator()!;
    expect(pricing.isConnected, isFalse);
    expect(_quantity(enterprise), '3');
    expect(_price(enterprise), 'EUR 30');
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
    expect(enterprise.isConnected, isFalse);
    expect(_enhancedConfigurator(), isNull);
    expect(
      web.document
          .querySelectorAll('script[$seoDomFirstLoadableRuntimeAttribute]')
          .length,
      0,
    );

    web.window.history.back();
    await _waitFor(
      () =>
          web.window.location.pathname == '/repo/enterprise' &&
          _enhancedConfigurator() != null,
    );
    final restored = _enhancedConfigurator()!;
    expect(restored, isNot(same(enterprise)));
    expect(_quantity(restored), '3');
    expect(_price(restored), 'EUR 30');
  });

  test('rejects tampered source and unavailable verification before apply',
      () async {
    _cleanDocument();
    final originalHref = web.window.location.href;
    addTearDown(() {
      _restoreFetch();
      web.window.history.replaceState(null, '', originalHref);
      web.document.documentElement
        ?..removeAttribute('data-handoff-hard')
        ..removeAttribute('data-handoff-disable-crypto');
      _cleanDocument();
    });

    web.window.history.replaceState(null, '', '/repo/overview');
    final manifest = _manifest([
      ['/overview', _profile, null],
      ['/pricing', _profile, _descriptor()],
    ]);
    final tamperedSource = _applicationSource.replaceFirst('test-', 'lest-');
    expect(tamperedSource.length, _applicationSource.length);
    final tamperedDocument = _document(
      title: 'Tampered',
      body: _configuratorBody(
        title: 'Tampered',
        initialQuantity: 2,
        nextPath: '/repo/overview',
      ),
      manifest: manifest,
      runtime: _runtimeTag(
        seoDomFirstApplicationHandoffEnvelope(
          tamperedSource,
          kind: 'configurator',
        ),
      ),
    );
    final validDocument = _document(
      title: 'Pricing',
      body: _configuratorBody(
        title: 'Pricing',
        initialQuantity: 2,
        nextPath: '/repo/overview',
      ),
      manifest: manifest,
      runtime: _runtimeTag(_applicationRuntime),
    );

    _mountHead('Overview', manifest);
    _mountBody(
      '<div id="esen-seo-content" data-esen-seo-dom-first="true">'
      '<main><h1>Overview</h1>'
      '<a id="tampered" href="/repo/pricing?case=tampered">Tampered</a>'
      '<a id="no-crypto" href="/repo/pricing?case=crypto">No crypto</a>'
      '</main></div>',
    );
    _mockCases({
      'tampered': tamperedDocument,
      'crypto': validDocument,
    });
    _mountInstrumentedNavigationRuntime();

    (web.document.querySelector('#tampered')! as web.HTMLElement).click();
    await _waitForHardFallback(1);
    expect(web.window.location.pathname, '/repo/overview');
    expect(web.document.title, 'Overview');
    expect(_enhancedConfigurator(), isNull);

    web.document.documentElement
        ?.setAttribute('data-handoff-disable-crypto', '');
    (web.document.querySelector('#no-crypto')! as web.HTMLElement).click();
    await _waitForHardFallback(2);
    expect(web.window.location.pathname, '/repo/overview');
    expect(web.document.title, 'Overview');
    expect(_enhancedConfigurator(), isNull);
  });
}

SeoConfiguratorView _pricingView(SeoConfiguratorState state) =>
    SeoConfiguratorView(
      priceText: 'EUR ${state.quantity * 10}',
      summaryText: 'Plan ${state.choiceIndex + 1}, ${state.quantity}',
      announcementText: 'Price EUR ${state.quantity * 10}',
      activeChoiceRegion: state.choiceIndex,
      optionRegionVisible: state.optionEnabled,
    );

List<Object?> _descriptor() => [
      seoDomFirstApplicationRuntimeOwner,
      'configurator',
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
    '<a href="/repo/pricing">Open pricing</a>'
    '</main></div>';

String _configuratorBody({
  required String title,
  required int initialQuantity,
  required String nextPath,
}) {
  final configurator = const HtmlRenderer.domFirst().render(
    buildSeoConfiguratorNodes(
      choices: [
        (
          label: 'Solo',
          nodes: [SeoNode(tag: 'p', text: 'Solo details')],
        ),
        (
          label: 'Team',
          nodes: [SeoNode(tag: 'p', text: 'Team details')],
        ),
      ],
      optionNodes: [SeoNode(tag: 'p', text: 'Support details')],
      constraints: _constraints,
      initialState: SeoConfiguratorState(
        choiceIndex: 0,
        quantity: initialQuantity,
        optionEnabled: false,
      ),
      project: _pricingView,
      interactionId: _interactionId,
      heading: '$title calculator',
      interactionLabel: '$title calculator',
      choiceGroupLabel: 'Plan',
      quantityLabel: 'Seats',
      optionLabel: 'Support',
      priceLabel: 'Price',
      decrementLabel: 'Remove seat',
      incrementLabel: 'Add seat',
    ),
  );
  return '<div id="esen-seo-content" data-esen-seo-dom-first="true">'
      '<main><h1>$title</h1>$configurator'
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

String _runtimeTag(String source) =>
    '<script $seoDomFirstLoadableRuntimeAttribute="'
    '$seoDomFirstApplicationRuntimeOwner" '
    '$seoDomFirstApplicationScriptAttribute="$_applicationId" '
    '$seoDomFirstRuntimeKindAttribute="configurator" '
    '$seoDomFirstRuntimeContractAttribute="'
    '$seoDomFirstRuntimeContractRevision" '
    '$seoDomFirstRuntimeSha256Attribute="$_applicationSourceHash" '
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
    ..textContent = seoDomFirstNavigationApplicationProfileRuntime;
  web.document.body?.appendChild(runtime);
}

void _mountInstrumentedNavigationRuntime() {
  const hard =
      'hard=(url,pop)=>{delete d.documentElement.dataset.esenNavigationPending;if(pop)location.reload();else location.assign(url.href)}';
  const observedHard =
      'hard=(url,pop)=>{delete d.documentElement.dataset.esenNavigationPending;d.documentElement.dataset.handoffHard=String(Number(d.documentElement.dataset.handoffHard||0)+1)}';
  const subtle = 'let subtle=globalThis.crypto&&globalThis.crypto.subtle';
  const observedSubtle =
      'let subtle=d.documentElement.hasAttribute("data-handoff-disable-crypto")?null:globalThis.crypto&&globalThis.crypto.subtle';
  final instrumented = seoDomFirstNavigationApplicationProfileRuntime
      .replaceFirst(hard, observedHard)
      .replaceFirst(subtle, observedSubtle);
  expect(instrumented, contains(observedHard));
  expect(instrumented, contains(observedSubtle));
  final runtime = web.document.createElement('script')
    ..setAttribute('data-esen-seo-dom-first-runtime', '')
    ..textContent = instrumented;
  web.document.body?.appendChild(runtime);
}

web.Element? _enhancedConfigurator() {
  final configurator = web.document.querySelector(
    '[data-esen-component="configurator"]',
  );
  return configurator?.getAttribute('data-esen-enhanced') == 'true'
      ? configurator
      : null;
}

String _quantity(web.Element root) =>
    root
        .querySelector('[data-esen-configurator-quantity-value]')!
        .textContent ??
    '';

String _price(web.Element root) =>
    root.querySelector('[data-esen-configurator-price]')!.textContent ?? '';

void _mockDocuments(Map<String, String> documents) {
  _runJavaScript(
    'globalThis.__esenOriginalFetch=globalThis.fetch;'
    'globalThis.__esenHandoffDocuments=${jsonEncode(documents)};'
    'globalThis.fetch=async function(u,o){'
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
  fail('Timed out waiting for the Configurator runtime handoff.');
}

Future<void> _waitForHardFallback(int count) => _waitFor(
      () =>
          web.document.documentElement?.getAttribute('data-handoff-hard') ==
          '$count',
    );

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
