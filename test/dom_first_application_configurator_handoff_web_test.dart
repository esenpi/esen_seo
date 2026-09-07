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
const _forgedHash =
    '0000000000000000000000000000000000000000000000000000000000000000';
const _tamperMarker = 'data-handoff-tampered';
const _notReadySource = 'document.currentScript.setAttribute=()=>{}';
final _applicationRuntime = seoDomFirstApplicationHandoffEnvelope(
  _applicationSource,
  kind: 'configurator',
);
final _applicationSourceBytes = utf8.encode(_applicationSource).length;
final _applicationSourceHash =
    sha256.convert(utf8.encode(_applicationSource)).toString();
final _notReadyRuntime = seoDomFirstApplicationHandoffEnvelope(
  _notReadySource,
  kind: 'configurator',
);
final _notReadyBytes = utf8.encode(_notReadySource).length;
final _notReadyHash = sha256.convert(utf8.encode(_notReadySource)).toString();
final _tamperedSource = _padToSourceBytes(
  'document.documentElement.setAttribute("$_tamperMarker","1")',
);
final _epilogueLength =
    seoDomFirstConfiguratorApplicationHandoffEpilogue.length;

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
    final enhanceListener = _mountEnhanceListener();
    addTearDown(() {
      web.document.removeEventListener(_enhanceEvent, enhanceListener);
      _restoreFetch();
      web.window.history.replaceState(null, '', originalHref);
      _cleanDocument();
      web.document.documentElement?.removeAttribute('data-handoff-fetches');
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

    web.window.history.forward();
    await _waitFor(
      () =>
          web.window.location.pathname == '/repo/overview' &&
          web.document.title == 'Overview',
    );
    expect(restored.isConnected, isFalse);
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
    final reentered = _enhancedConfigurator()!;
    expect(reentered, isNot(same(restored)));
    expect(_quantity(reentered), '3');
    expect(_price(reentered), 'EUR 30');
    expect(
      web.document
          .querySelectorAll('script[$seoDomFirstLoadableRuntimeAttribute]')
          .length,
      1,
    );
  });

  test('reloads the replaced target when the artifact never reports readiness',
      () async {
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
        'data-handoff-fetches',
        'data-esen-interaction-pending',
        'data-esen-collection-pending',
      ]) {
        web.document.documentElement?.removeAttribute(name);
      }
    });

    web.window.history.replaceState(null, '', '/repo/overview');
    final manifest = _manifest([
      ['/overview', _profile, null],
      [
        '/no-ready',
        _profile,
        _descriptor(hash: _notReadyHash, bytes: _notReadyBytes),
      ],
    ]);
    final notReadyDocument = _document(
      title: 'Rejected target',
      body: _configuratorBody(
        title: 'Rejected target',
        initialQuantity: 2,
        nextPath: '/repo/overview',
      ),
      manifest: manifest,
      runtime: _runtimeTag(_notReadyRuntime, hash: _notReadyHash),
    );

    _mountHead('Overview', manifest);
    final initial = _mountBody(
      '<div id="esen-seo-content" data-esen-seo-dom-first="true">'
      '<main><h1>Overview</h1>'
      '<a id="no-ready" href="/repo/no-ready">Not ready</a>'
      '</main></div>',
    );
    _mockDocuments({'/repo/no-ready': notReadyDocument});
    web.document.documentElement
      ?..setAttribute('data-esen-interaction-pending', '1')
      ..setAttribute('data-esen-collection-pending', '1');
    _mountInstrumentedNavigationRuntime();
    web.window.history.pushState(null, '', '/repo/overview');
    final entries = web.window.history.length;

    (initial.querySelector('#no-ready')! as web.HTMLElement).click();
    await _waitForHardFallback(1);
    expect(
      web.document.documentElement?.getAttribute('data-handoff-hard-mode'),
      'reload',
    );
    expect(
      web.document.documentElement?.getAttribute('data-handoff-hard-url'),
      contains('/repo/no-ready'),
    );
    expect(web.window.location.pathname, '/repo/no-ready');
    expect(web.document.title, 'Rejected target');
    expect(initial.isConnected, isFalse);
    expect(web.window.history.length, entries + 1);
    expect(
      web.document
          .querySelectorAll('script[$seoDomFirstLoadableRuntimeAttribute]')
          .length,
      1,
    );
    expect(
      web.document
          .querySelector('script[$seoDomFirstLoadableRuntimeAttribute]')
          ?.getAttribute(seoDomFirstRuntimeReadyAttribute),
      isNull,
    );
    expect(
      web.document.documentElement
          ?.hasAttribute('data-esen-interaction-pending'),
      isFalse,
    );
    expect(
      web.document.documentElement
          ?.getAttribute('data-esen-collection-pending'),
      '1',
    );
  });

  test('rejects tampered source and unavailable verification before apply',
      () async {
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
        'data-esen-interaction-pending',
        _tamperMarker,
      ]) {
        web.document.documentElement?.removeAttribute(name);
      }
    });

    expect(utf8.encode(_tamperedSource), hasLength(_applicationSourceBytes));
    web.window.history.replaceState(null, '', '/repo/overview');
    final manifest = _manifest([
      ['/overview', _profile, null],
      ['/pricing', _profile, _descriptor()],
    ]);
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
          _tamperedSource,
          kind: 'configurator',
        ),
      ),
    );
    final lengthDocument = _document(
      title: 'Tampered',
      body: _configuratorBody(
        title: 'Tampered',
        initialQuantity: 2,
        nextPath: '/repo/overview',
      ),
      manifest: manifest,
      runtime: _runtimeTag(
        seoDomFirstApplicationHandoffEnvelope(
          '${_tamperedSource}y',
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
      '<a id="tampered-length" href="/repo/pricing?case=length">Length</a>'
      '<a id="no-crypto" href="/repo/pricing?case=crypto">No crypto</a>'
      '</main></div>',
    );
    _mockCases({
      'tampered': tamperedDocument,
      'length': lengthDocument,
      'crypto': validDocument,
    });
    web.document.documentElement
        ?.setAttribute('data-esen-interaction-pending', '1');
    _mountInstrumentedNavigationRuntime();

    var fallbackCount = 0;
    for (final id in const ['#tampered', '#tampered-length', '#no-crypto']) {
      if (id == '#no-crypto') {
        web.document.documentElement
            ?.setAttribute('data-handoff-disable-crypto', '');
      }
      (web.document.querySelector(id)! as web.HTMLElement).click();
      await _waitForHardFallback(++fallbackCount);
      expect(web.window.location.pathname, '/repo/overview', reason: id);
      expect(web.document.title, 'Overview', reason: id);
      expect(_enhancedConfigurator(), isNull, reason: id);
      expect(
        web.document.documentElement?.hasAttribute(_tamperMarker),
        isFalse,
        reason: id,
      );
      expect(
        web.document
            .querySelectorAll('script[$seoDomFirstLoadableRuntimeAttribute]')
            .length,
        0,
        reason: id,
      );
      expect(
        web.document.documentElement?.getAttribute('data-handoff-hard-mode'),
        'assign',
        reason: id,
      );
      expect(
        web.document.documentElement
            ?.getAttribute('data-esen-interaction-pending'),
        '1',
        reason: id,
      );
    }

    web.document.documentElement
        ?.removeAttribute('data-handoff-disable-crypto');
    (web.document.querySelector('#no-crypto')! as web.HTMLElement).click();
    await _waitFor(
      () =>
          web.window.location.pathname == '/repo/pricing' &&
          web.document.querySelector(
                'script[$seoDomFirstLoadableRuntimeAttribute]',
              ) !=
              null,
    );
    expect(web.document.title, 'Pricing');
    expect(web.document.querySelector('#no-crypto'), isNull);
    expect(
      web.document.documentElement?.getAttribute('data-handoff-hard'),
      '$fallbackCount',
    );
    expect(
      web.document
          .querySelector('script[$seoDomFirstLoadableRuntimeAttribute]')
          ?.getAttribute(seoDomFirstRuntimeReadyAttribute),
      'true',
    );
    expect(
      web.document.documentElement
          ?.hasAttribute('data-esen-interaction-pending'),
      isFalse,
    );
  });

  test('rejects unbound Configurator payloads before any replacement',
      () async {
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
        'data-esen-interaction-pending',
      ]) {
        web.document.documentElement?.removeAttribute(name);
      }
    });

    web.window.history.replaceState(null, '', '/repo/start');
    List<List<Object?>> routesWith(List<Object?> pricing) => [
          ['/start', _profile, null],
          ['/pricing', _profile, pricing],
          ['/overview', _profile, null],
          [
            '/mismatch',
            _profile,
            _descriptor(bytes: _applicationSourceBytes + 1),
          ],
        ];
    final routes = routesWith(_descriptor());
    final manifest = _manifest(routes);
    final driftManifest =
        _manifest(routesWith(_descriptor(id: 'other-configurator')));

    _mountHead('Descriptor source', manifest);
    final initial = _mountBody(
      '<div id="esen-seo-content" data-esen-seo-dom-first="true">'
      '<main><h1>Descriptor source</h1>'
      '<a href="/repo/pricing">Target</a>'
      '</main></div>',
    );
    _mockCases({
      'valid': _rejectedDocument(manifest, _runtimeTag(_applicationRuntime)),
      'forged': _rejectedDocument(
        manifest,
        _runtimeTag(_applicationRuntime, hash: _forgedHash),
      ),
      'wrong-id': _rejectedDocument(
        manifest,
        _runtimeTag(_applicationRuntime, id: 'other-configurator'),
      ),
      'wrong-kind': _rejectedDocument(
        manifest,
        _runtimeTag(
          _applicationRuntime,
          kind: seoDomFirstCollectionRuntimeKind,
        ),
      ),
      'wrong-owner': _rejectedDocument(
        manifest,
        _runtimeTag(
          _applicationRuntime,
          owner: seoDomFirstCollectionRuntimeKind,
        ),
      ),
      'wrong-contract': _rejectedDocument(
        manifest,
        _runtimeTag(
          _applicationRuntime,
          contract: seoDomFirstRuntimeContractRevision + 1,
        ),
      ),
      'collection-epilogue': _rejectedDocument(
        manifest,
        _runtimeTag(seoDomFirstApplicationHandoffEnvelope(_applicationSource)),
      ),
      'extra-epilogue': _rejectedDocument(
        manifest,
        _runtimeTag('$_applicationRuntime;void 0'),
      ),
      'padded-epilogue': _rejectedDocument(
        manifest,
        _runtimeTag('$_applicationSource${'x' * _epilogueLength}'),
      ),
      'unknown-attribute': _rejectedDocument(
        manifest,
        _runtimeTag(_applicationRuntime).replaceFirst(
          '<script ',
          '<script data-unexpected="true" ',
        ),
      ),
      'split-markers': _rejectedDocument(
        manifest,
        '${_runtimeTag(_applicationRuntime).replaceFirst(
          ' $seoDomFirstApplicationScriptAttribute="$_applicationId"',
          '',
        )}<script $seoDomFirstApplicationScriptAttribute='
        '"$_applicationId"></script>',
      ),
      'ready-false': _rejectedDocument(
        manifest,
        _runtimeTag(_applicationRuntime).replaceFirst(
          '<script ',
          '<script $seoDomFirstRuntimeReadyAttribute="false" ',
        ),
      ),
      'duplicate': _rejectedDocument(
        manifest,
        '${_runtimeTag(_applicationRuntime)}'
        '${_runtimeTag(_applicationRuntime)}',
      ),
      'missing': _rejectedDocument(manifest, ''),
      'unexpected-on-static': _rejectedDocument(
        manifest,
        _runtimeTag(_applicationRuntime),
      ),
      'bad-bytes': _rejectedDocument(
        manifest,
        _runtimeTag(_applicationRuntime),
      ),
      'schema-3': _rejectedDocument(
        _manifest(
          routes,
          schema: seoDomFirstApplicationRuntimeHandoffManifestSchema,
        ),
        _runtimeTag(_applicationRuntime),
      ),
      'plan-unknown-kind': _rejectedDocument(
        _manifest(routesWith(_descriptor(kind: 'tabs'))),
        _runtimeTag(_applicationRuntime),
      ),
      'plan-bad-id': _rejectedDocument(
        _manifest(routesWith(_descriptor(id: 'Pricing'))),
        _runtimeTag(_applicationRuntime),
      ),
      'plan-bad-hash': _rejectedDocument(
        _manifest(routesWith(_descriptor(hash: _forgedHash.substring(1)))),
        _runtimeTag(_applicationRuntime),
      ),
      'plan-oversized': _rejectedDocument(
        _manifest(routesWith(_descriptor(bytes: 524289))),
        _runtimeTag(_applicationRuntime),
      ),
      'plan-drift': _rejectedDocument(
        driftManifest,
        _runtimeTag(_applicationRuntime, id: 'other-configurator'),
      ),
      'wrong-profile': _rejectedDocument(
        _manifest(routes, profile: 'other.navigation.profile'),
        _runtimeTag(_applicationRuntime),
        profile: 'other.navigation.profile',
      ),
    });
    web.document.documentElement
        ?.setAttribute('data-esen-interaction-pending', '1');
    _mountInstrumentedNavigationRuntime();

    final link = initial.querySelector('a')! as web.HTMLAnchorElement;
    var fallbackCount = 0;

    Future<void> expectRejected(
      String testCase, {
      String path = '/repo/pricing',
    }) async {
      link.href = '$path?case=$testCase';
      link.click();
      await _waitForHardFallback(++fallbackCount);
      expect(initial.isConnected, isTrue, reason: testCase);
      expect(web.document.title, 'Descriptor source', reason: testCase);
      expect(web.window.location.pathname, '/repo/start', reason: testCase);
      expect(_enhancedConfigurator(), isNull, reason: testCase);
      expect(
        web.document
            .querySelectorAll('script[$seoDomFirstLoadableRuntimeAttribute]')
            .length,
        0,
        reason: testCase,
      );
      expect(
        web.document.documentElement?.getAttribute('data-handoff-hard-mode'),
        'assign',
        reason: testCase,
      );
      expect(
        web.document.documentElement?.getAttribute('data-handoff-hard-url'),
        contains('$path?case=$testCase'),
        reason: testCase,
      );
      expect(
        web.document.documentElement
            ?.getAttribute('data-esen-interaction-pending'),
        '1',
        reason: testCase,
      );
    }

    web.document.documentElement
        ?.setAttribute('data-handoff-disable-crypto', '');
    await expectRejected('valid');
    web.document.documentElement
        ?.removeAttribute('data-handoff-disable-crypto');
    for (final testCase in const [
      'forged',
      'wrong-id',
      'wrong-kind',
      'wrong-owner',
      'wrong-contract',
      'collection-epilogue',
      'extra-epilogue',
      'padded-epilogue',
      'unknown-attribute',
      'split-markers',
      'ready-false',
      'duplicate',
      'missing',
      'schema-3',
      'plan-unknown-kind',
      'plan-bad-id',
      'plan-bad-hash',
      'plan-oversized',
      'plan-drift',
      'wrong-profile',
    ]) {
      await expectRejected(testCase);
    }
    await expectRejected('unexpected-on-static', path: '/repo/overview');
    await expectRejected('bad-bytes', path: '/repo/mismatch');

    link.href = '/repo/pricing?case=valid';
    link.click();
    await _waitFor(
      () =>
          web.window.location.pathname == '/repo/pricing' &&
          web.document.querySelector(
                'script[$seoDomFirstLoadableRuntimeAttribute]',
              ) !=
              null,
    );
    expect(initial.isConnected, isFalse);
    expect(web.document.title, 'Rejected target');
    expect(
      web.document.documentElement?.getAttribute('data-handoff-hard'),
      '$fallbackCount',
    );
    expect(
      web.document
          .querySelectorAll('script[$seoDomFirstLoadableRuntimeAttribute]')
          .length,
      1,
    );
    expect(
      web.document
          .querySelector('script[$seoDomFirstLoadableRuntimeAttribute]')
          ?.getAttribute(seoDomFirstRuntimeReadyAttribute),
      'true',
    );
    expect(
      web.document.documentElement
          ?.hasAttribute('data-esen-interaction-pending'),
      isFalse,
    );
  });

  test('does not let a stale Configurator response replace a newer route',
      () async {
    _cleanDocument();
    final originalHref = web.window.location.href;
    var enhanceCount = 0;
    final enhanceListener = _mountEnhanceListener(() => enhanceCount++);
    addTearDown(() {
      web.document.removeEventListener(_enhanceEvent, enhanceListener);
      _restoreFetch();
      web.window.history.replaceState(null, '', originalHref);
      _cleanDocument();
      for (final name in const [
        'data-handoff-hard',
        'data-handoff-hard-url',
        'data-handoff-hard-mode',
        'data-handoff-slow-response',
      ]) {
        web.document.documentElement?.removeAttribute(name);
      }
    });

    web.window.history.replaceState(null, '', '/repo/race');
    final manifest = _manifest([
      ['/race', _profile, null],
      ['/slow', _profile, _descriptor()],
      ['/fast', _profile, null],
    ]);
    _mountHead('Race source', manifest);
    final initial = _mountBody(_raceBody());
    _mockRacingDocuments(
      slow: _document(
        title: 'Slow',
        body: _configuratorBody(
          title: 'Slow',
          initialQuantity: 4,
          nextPath: '/repo/race',
        ),
        manifest: manifest,
        runtime: _runtimeTag(_applicationRuntime),
      ),
      fast: _document(
        title: 'Fast',
        body: '<div id="esen-seo-content" data-esen-seo-dom-first="true">'
            '<main><h1>Fast</h1></main></div>',
        manifest: manifest,
      ),
    );
    _mountInstrumentedNavigationRuntime();

    (initial.querySelector('#slow')! as web.HTMLElement).click();
    await Future<void>.delayed(const Duration(milliseconds: 5));
    (initial.querySelector('#fast')! as web.HTMLElement).click();
    await _waitFor(
      () =>
          web.window.location.pathname == '/repo/fast' &&
          web.document.title == 'Fast',
    );
    await _waitForStaleResponse();

    expect(web.document.title, 'Fast');
    expect(enhanceCount, 0);
    expect(_enhancedConfigurator(), isNull);
    expect(
      web.document
          .querySelectorAll('script[$seoDomFirstLoadableRuntimeAttribute]')
          .length,
      0,
    );
    expect(
      web.document.documentElement
          ?.hasAttribute('data-esen-navigation-pending'),
      isFalse,
    );
    expect(
      web.document.documentElement?.hasAttribute('data-handoff-hard'),
      isFalse,
    );
  });

  test('keeps one Configurator instance when a newer route wins', () async {
    _cleanDocument();
    final originalHref = web.window.location.href;
    var enhanceCount = 0;
    final enhanceListener = _mountEnhanceListener(() => enhanceCount++);
    addTearDown(() {
      web.document.removeEventListener(_enhanceEvent, enhanceListener);
      _restoreFetch();
      web.window.history.replaceState(null, '', originalHref);
      _cleanDocument();
      for (final name in const [
        'data-handoff-hard',
        'data-handoff-hard-url',
        'data-handoff-hard-mode',
        'data-handoff-slow-response',
      ]) {
        web.document.documentElement?.removeAttribute(name);
      }
    });

    web.window.history.replaceState(null, '', '/repo/race');
    final manifest = _manifest([
      ['/race', _profile, null],
      ['/slow', _profile, _descriptor()],
      ['/fast', _profile, _descriptor()],
    ]);
    _mountHead('Race source', manifest);
    final initial = _mountBody(_raceBody());
    _mockRacingDocuments(
      slow: _document(
        title: 'Slow',
        body: _configuratorBody(
          title: 'Slow',
          initialQuantity: 4,
          nextPath: '/repo/race',
        ),
        manifest: manifest,
        runtime: _runtimeTag(_applicationRuntime),
      ),
      fast: _document(
        title: 'Fast',
        body: _configuratorBody(
          title: 'Fast',
          initialQuantity: 2,
          nextPath: '/repo/race',
        ),
        manifest: manifest,
        runtime: _runtimeTag(_applicationRuntime),
      ),
    );
    _mountInstrumentedNavigationRuntime();

    (initial.querySelector('#slow')! as web.HTMLElement).click();
    await Future<void>.delayed(const Duration(milliseconds: 5));
    (initial.querySelector('#fast')! as web.HTMLElement).click();
    await _waitFor(
      () =>
          web.window.location.pathname == '/repo/fast' &&
          web.document.title == 'Fast' &&
          _enhancedConfigurator() != null,
    );
    await _waitForStaleResponse();

    final fast = _enhancedConfigurator()!;
    expect(enhanceCount, 1);
    expect(_quantity(fast), '2');
    expect(_price(fast), 'EUR 20');
    expect(
      web.document
          .querySelectorAll('script[$seoDomFirstLoadableRuntimeAttribute]')
          .length,
      1,
    );
    final applied = web.document.querySelector(
      'script[$seoDomFirstLoadableRuntimeAttribute]',
    )!;
    expect(
      applied.getAttribute(seoDomFirstApplicationScriptAttribute),
      _applicationId,
    );
    expect(
      applied.getAttribute(seoDomFirstRuntimeKindAttribute),
      'configurator',
    );
    expect(
      applied.getAttribute(seoDomFirstRuntimeReadyAttribute),
      'true',
    );
    expect(
      web.document.documentElement?.hasAttribute('data-handoff-hard'),
      isFalse,
    );
  });

  test('uses only the executing loader nonce for the applied artifact',
      () async {
    _cleanDocument();
    final originalHref = web.window.location.href;
    final enhanceListener = _mountEnhanceListener();
    addTearDown(() {
      web.document.removeEventListener(_enhanceEvent, enhanceListener);
      _restoreFetch();
      web.window.history.replaceState(null, '', originalHref);
      _cleanDocument();
      web.document.documentElement?.removeAttribute('data-handoff-fetches');
    });

    web.window.history.replaceState(null, '', '/repo/overview');
    final manifest = _manifest([
      ['/overview', _profile, null],
      ['/pricing', _profile, _descriptor()],
    ]);
    _mountHead('Overview', manifest);
    final initial = _mountBody(_overviewBody());
    _mockDocuments({
      '/repo/pricing': _document(
        title: 'Pricing',
        body: _configuratorBody(
          title: 'Pricing',
          initialQuantity: 1,
          nextPath: '/repo/overview',
        ),
        manifest: manifest,
        runtime: _runtimeTag(_applicationRuntime),
      ),
    });
    _mountNavigationRuntime(nonce: null);

    (initial.querySelector('a')! as web.HTMLElement).click();
    await _waitFor(
      () =>
          web.window.location.pathname == '/repo/pricing' &&
          _enhancedConfigurator() != null,
    );
    final applied = web.document.querySelector(
      'script[$seoDomFirstLoadableRuntimeAttribute]',
    )! as web.HTMLScriptElement;
    expect(applied.getAttribute('nonce'), isNull);
    expect(applied.nonce, isEmpty);
    expect(
      applied.getAttribute(seoDomFirstRuntimeReadyAttribute),
      'true',
    );
  });

  test('initializes a direct Configurator document before navigation starts',
      () async {
    _cleanDocument();
    final originalHref = web.window.location.href;
    final enhanceListener = _mountEnhanceListener();
    addTearDown(() {
      web.document.removeEventListener(_enhanceEvent, enhanceListener);
      _restoreFetch();
      web.window.history.replaceState(null, '', originalHref);
      _cleanDocument();
      web.document.documentElement
        ?..removeAttribute('data-handoff-fetches')
        ..removeAttribute('data-handoff-armed')
        ..removeAttribute('data-esen-interaction-pending');
    });

    final manifest = _manifest([
      ['/overview', _profile, null],
      ['/pricing', _profile, _descriptor()],
    ]);
    web.window.history.replaceState(null, '', '/repo/pricing');
    web.document.documentElement
        ?.setAttribute('data-esen-interaction-pending', '1');
    _mountHead('Pricing', manifest);
    final content = _mountBody(
      _configuratorBody(
        title: 'Pricing',
        initialQuantity: 2,
        nextPath: '/repo/overview',
      ),
    );
    final applicationScript = _mountApplicationRuntime();

    expect(
      applicationScript.getAttribute(seoDomFirstRuntimeReadyAttribute),
      'true',
    );
    final direct = _enhancedConfigurator()!;
    expect(_quantity(direct), '2');
    expect(_price(direct), 'EUR 20');
    expect(
      web.document.documentElement
          ?.hasAttribute('data-esen-interaction-pending'),
      isFalse,
    );

    _mockDocuments({
      '/repo/overview': _document(
        title: 'Overview',
        body: _overviewBody(),
        manifest: manifest,
      ),
    });
    _mountNavigationRuntime();
    expect(_navigationArmed(), '1');

    (content.querySelector('#next-route')! as web.HTMLElement).click();
    await _waitFor(
      () =>
          web.window.location.pathname == '/repo/overview' &&
          web.document.title == 'Overview',
    );
    expect(content.isConnected, isFalse);
    expect(applicationScript.isConnected, isFalse);
    expect(_enhancedConfigurator(), isNull);
    expect(
      web.document
          .querySelectorAll('script[$seoDomFirstLoadableRuntimeAttribute]')
          .length,
      0,
    );
    expect(
      web.document.documentElement?.getAttribute('data-handoff-fetches'),
      '1',
    );
  });

  test('does not arm navigation while the delivered artifact is not ready',
      () async {
    _cleanDocument();
    final originalHref = web.window.location.href;
    final enhanceListener = _mountEnhanceListener();
    addTearDown(() {
      web.document.removeEventListener(_enhanceEvent, enhanceListener);
      web.window.history.replaceState(null, '', originalHref);
      _cleanDocument();
      web.document.documentElement
        ?..removeAttribute('data-handoff-armed')
        ..removeAttribute('data-esen-interaction-pending');
    });

    final manifest = _manifest([
      ['/overview', _profile, null],
      [
        '/pricing',
        _profile,
        _descriptor(hash: _notReadyHash, bytes: _notReadyBytes),
      ],
    ]);
    web.window.history.replaceState(null, '', '/repo/pricing');
    web.document.documentElement
        ?.setAttribute('data-esen-interaction-pending', '1');
    _mountHead('Pricing', manifest);
    _mountBody(
      _configuratorBody(
        title: 'Pricing',
        initialQuantity: 2,
        nextPath: '/repo/overview',
      ),
    );
    final applicationScript = _mountApplicationRuntime(
      source: _notReadyRuntime,
      hash: _notReadyHash,
    );
    _mountNavigationRuntime();

    expect(_navigationArmed(), '0');
    expect(
      applicationScript.getAttribute(seoDomFirstRuntimeReadyAttribute),
      isNull,
    );
    expect(_enhancedConfigurator(), isNull);
    expect(
      web.document.documentElement
          ?.hasAttribute('data-esen-interaction-pending'),
      isFalse,
    );
    expect(
      web.document.documentElement
          ?.hasAttribute('data-esen-navigation-pending'),
      isFalse,
    );
  });

  test('does not arm navigation on an invalid schema-4 descriptor', () {
    _cleanDocument();
    final originalHref = web.window.location.href;
    addTearDown(() {
      web.window.history.replaceState(null, '', originalHref);
      _cleanDocument();
      web.document.documentElement?.removeAttribute('data-handoff-armed');
    });

    String armedFor(List<Object?> descriptor) {
      _cleanDocument();
      web.window.history.replaceState(null, '', '/repo/start');
      _mountHead(
        'Descriptor source',
        _manifest([
          ['/start', _profile, null],
          ['/pricing', _profile, descriptor],
        ]),
      );
      _mountBody(
        '<div id="esen-seo-content" data-esen-seo-dom-first="true">'
        '<main><h1>Descriptor source</h1></main></div>',
      );
      _mountNavigationRuntime();
      return _navigationArmed();
    }

    expect(armedFor(_descriptor()), '1');
    for (final descriptor in [
      _descriptor(kind: 'tabs'),
      _descriptor(id: 'Pricing'),
      _descriptor(hash: _forgedHash.substring(1)),
      _descriptor(bytes: 524289),
    ]) {
      expect(armedFor(descriptor), '0', reason: '$descriptor');
    }
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

String _padToSourceBytes(String source) {
  final padding = _applicationSourceBytes - utf8.encode(source).length - 3;
  return '$source;//${'x' * padding}';
}

List<Object?> _descriptor({
  Object kind = 'configurator',
  Object id = _applicationId,
  Object? hash,
  Object? bytes,
}) =>
    [
      seoDomFirstApplicationRuntimeOwner,
      kind,
      id,
      seoDomFirstRuntimeContractRevision,
      hash ?? _applicationSourceHash,
      bytes ?? _applicationSourceBytes,
    ];

String _manifest(
  List<List<Object?>> routes, {
  int schema = seoDomFirstTypedApplicationRuntimeHandoffManifestSchema,
  String profile = _profile,
}) =>
    jsonEncode({
      'schema': schema,
      'base': '/repo',
      'profile': profile,
      'routes': routes,
    });

String _overviewBody() =>
    '<div id="esen-seo-content" data-esen-seo-dom-first="true">'
    '<main><h1>Overview</h1>'
    '<a href="/repo/pricing">Open pricing</a>'
    '</main></div>';

String _raceBody() =>
    '<div id="esen-seo-content" data-esen-seo-dom-first="true">'
    '<main><h1>Race source</h1>'
    '<a id="slow" href="/repo/slow">Slow</a>'
    '<a id="fast" href="/repo/fast">Fast</a>'
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
  String profile = _profile,
}) =>
    '<!DOCTYPE html><html lang="en"><head>'
    '<title $seoDomFirstNavigationHeadAttribute>$title</title>'
    '<script type="application/json" '
    '$seoDomFirstNavigationManifestAttribute '
    'data-esen-navigation-profile="$profile">$manifest</script>'
    '</head><body>$body$runtime'
    '<script data-esen-seo-dom-first-runtime></script>'
    '</body></html>';

String _rejectedDocument(
  String manifest,
  String runtime, {
  String profile = _profile,
}) =>
    _document(
      title: 'Rejected target',
      body: '<div id="esen-seo-content" data-esen-seo-dom-first="true">'
          '<main><h1>Rejected target</h1></main></div>',
      manifest: manifest,
      runtime: runtime,
      profile: profile,
    );

String _runtimeTag(
  String source, {
  String owner = seoDomFirstApplicationRuntimeOwner,
  String id = _applicationId,
  String kind = 'configurator',
  int contract = seoDomFirstRuntimeContractRevision,
  String? hash,
}) =>
    '<script $seoDomFirstLoadableRuntimeAttribute="$owner" '
    '$seoDomFirstApplicationScriptAttribute="$id" '
    '$seoDomFirstRuntimeKindAttribute="$kind" '
    '$seoDomFirstRuntimeContractAttribute="$contract" '
    '$seoDomFirstRuntimeSha256Attribute="${hash ?? _applicationSourceHash}" '
    'nonce="fetched-nonce">$source</script>';

JSFunction _mountEnhanceListener([void Function()? observe]) {
  final listener = ((web.Event _) {
    observe?.call();
    enhanceSeoDomFirstConfigurators(
      interactionIds: const {_interactionId},
      transition: transitionSeoConfigurator,
      project: _pricingView,
    );
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

void _mountNavigationRuntime({String? nonce = 'trusted-nonce'}) {
  final runtime = web.document.createElement('script')
    ..setAttribute('data-esen-seo-dom-first-runtime', '')
    ..textContent = seoDomFirstNavigationApplicationProfileRuntime;
  if (nonce != null) runtime.setAttribute('nonce', nonce);
  web.document.body?.appendChild(runtime);
}

web.HTMLScriptElement _mountApplicationRuntime({String? source, String? hash}) {
  final runtime = web.document.createElement('script') as web.HTMLScriptElement
    ..setAttribute(
      seoDomFirstLoadableRuntimeAttribute,
      seoDomFirstApplicationRuntimeOwner,
    )
    ..setAttribute(seoDomFirstApplicationScriptAttribute, _applicationId)
    ..setAttribute(seoDomFirstRuntimeKindAttribute, 'configurator')
    ..setAttribute(
      seoDomFirstRuntimeContractAttribute,
      '$seoDomFirstRuntimeContractRevision',
    )
    ..setAttribute(
      seoDomFirstRuntimeSha256Attribute,
      hash ?? _applicationSourceHash,
    )
    ..setAttribute('nonce', 'trusted-nonce')
    ..textContent = source ?? _applicationRuntime;
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

String _navigationArmed() {
  _runJavaScript(
    'document.documentElement.dataset.handoffArmed='
    'history.state&&history.state.esenSeoNavigation===1?"1":"0"',
  );
  return web.document.documentElement?.getAttribute('data-handoff-armed') ?? '';
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
    'document.documentElement.dataset.handoffSlowResponse="0";'
    'globalThis.fetch=async function(u,o){'
    'let isSlow=new URL(String(u),location.href).pathname==="/repo/slow";'
    'if(isSlow){await new Promise(r=>setTimeout(r,80));'
    'document.documentElement.dataset.handoffSlowResponse="1"}'
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
  fail('Timed out waiting for the Configurator runtime handoff.');
}

Future<void> _waitForHardFallback(int count) => _waitFor(
      () =>
          web.document.documentElement?.getAttribute('data-handoff-hard') ==
          '$count',
    );

Future<void> _waitForStaleResponse() => _waitFor(
      () =>
          web.document.documentElement
              ?.getAttribute('data-handoff-slow-response') ==
          '1',
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
