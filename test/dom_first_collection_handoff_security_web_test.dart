@TestOn('browser')
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:esen_seo/core.dart';
import 'package:esen_seo/src/renderer/seo_dom_first_navigation_handoff_runtime.g.dart';
import 'package:esen_seo/src/renderer/seo_dom_first_runtime_handoff.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;

const _profile = 'navigation.runtimeHandoff';
const _notReadyRuntime = 'void 0';
const _forgedHash =
    '0000000000000000000000000000000000000000000000000000000000000000';

final _notReadyHash = sha256.convert(utf8.encode(_notReadyRuntime)).toString();
final _notReadyBytes = utf8.encode(_notReadyRuntime).length;

void main() {
  test('rejects unbound runtimes and reloads after readiness failure',
      () async {
    _cleanDocument();
    final originalHref = web.window.location.href;
    addTearDown(() {
      _runJavaScript(
        'globalThis.fetch=globalThis.__esenOriginalFetch;'
        'delete globalThis.__esenOriginalFetch',
      );
      web.window.history.replaceState(null, '', originalHref);
      _cleanDocument();
      web.document.documentElement?.removeAttribute('data-handoff-hard');
      web.document.documentElement?.removeAttribute('data-handoff-hard-url');
      web.document.documentElement?.removeAttribute('data-handoff-hard-mode');
      web.document.documentElement
          ?.removeAttribute('data-handoff-disable-crypto');
      _runJavaScript('delete globalThis.__esenHandoffDocuments');
    });

    web.window.history.replaceState(null, '', '/handoff-security');
    final manifest = jsonEncode({
      'schema': seoDomFirstRuntimeHandoffManifestSchema,
      'base': '/',
      'profile': _profile,
      'routes': [
        ['/handoff-security', _profile, null],
        [
          '/handoff-security/articles',
          _profile,
          [
            seoDomFirstCollectionRuntimeKind,
            seoDomFirstCollectionHandoffRuntimeSha256,
            seoDomFirstCollectionHandoffRuntimeBytes,
          ],
        ],
        [
          '/handoff-security/forged',
          _profile,
          [
            seoDomFirstCollectionRuntimeKind,
            _forgedHash,
            seoDomFirstCollectionHandoffRuntimeBytes,
          ],
        ],
        [
          '/handoff-security/no-ready',
          _profile,
          [
            seoDomFirstCollectionRuntimeKind,
            _notReadyHash,
            _notReadyBytes,
          ],
        ],
      ],
    });
    _mountHead(manifest);
    final initial = _mountBody();

    final tampered = '${seoDomFirstCollectionHandoffRuntime.substring(
      0,
      seoDomFirstCollectionHandoffRuntime.length - 1,
    )}x';
    expect(utf8.encode(tampered),
        hasLength(seoDomFirstCollectionHandoffRuntimeBytes));
    final tamperedDocument = _targetDocument(
      manifest,
      _runtimeTag(tampered),
    );
    final duplicateDocument = _targetDocument(
      manifest,
      '${_runtimeTag(seoDomFirstCollectionHandoffRuntime)}'
      '${_runtimeTag(seoDomFirstCollectionHandoffRuntime)}',
    );
    final validDocument = _targetDocument(
      manifest,
      _runtimeTag(seoDomFirstCollectionHandoffRuntime),
    );
    final missingDocument = _targetDocument(manifest, '');
    final wrongMarkerDocument = _targetDocument(
      manifest,
      _runtimeTag(seoDomFirstCollectionHandoffRuntime, kind: 'tabs'),
    );
    final forgedDocument = _targetDocument(
      manifest,
      _runtimeTag(
        seoDomFirstCollectionHandoffRuntime,
        hash: _forgedHash,
      ),
    );
    final noReadyDocument = _targetDocument(
      manifest,
      _runtimeTag(_notReadyRuntime, hash: _notReadyHash),
    );
    _mockFetch({
      'valid': validDocument,
      'tampered': tamperedDocument,
      'duplicate': duplicateDocument,
      'missing': missingDocument,
      'wrong-marker': wrongMarkerDocument,
      'forged': forgedDocument,
      'no-ready': noReadyDocument,
    });

    const hard =
        'hard=(url,pop)=>{delete d.documentElement.dataset.esenNavigationPending;if(pop)location.reload();else location.assign(url.href)}';
    const observedHard =
        'hard=(url,pop)=>{delete d.documentElement.dataset.esenNavigationPending;d.documentElement.dataset.handoffHard=String(Number(d.documentElement.dataset.handoffHard||0)+1);d.documentElement.dataset.handoffHardUrl=url.href;d.documentElement.dataset.handoffHardMode=pop?"reload":"assign"}';
    const subtle = 'let subtle=globalThis.crypto&&globalThis.crypto.subtle';
    const observedSubtle =
        'let subtle=d.documentElement.hasAttribute("data-handoff-disable-crypto")?null:globalThis.crypto&&globalThis.crypto.subtle';
    final instrumented = seoDomFirstNavigationHandoffRuntime
        .replaceFirst(hard, observedHard)
        .replaceFirst(subtle, observedSubtle);
    expect(instrumented, isNot(seoDomFirstNavigationHandoffRuntime));
    expect(instrumented, contains(observedHard));
    expect(instrumented, contains(observedSubtle));
    final runtime = web.document.createElement('script')
      ..setAttribute('data-esen-seo-dom-first-runtime', '')
      ..textContent = instrumented;
    web.document.body?.appendChild(runtime);

    final link = initial.querySelector('a')! as web.HTMLAnchorElement;
    var fallbackCount = 0;

    Future<void> expectRejected(String href) async {
      link.href = href;
      link.click();
      await _waitForHardFallback(++fallbackCount);
      expect(initial.isConnected, isTrue, reason: href);
      expect(web.document.title, 'Security source', reason: href);
      expect(
        web.document
            .querySelectorAll(
              'script[$seoDomFirstLoadableRuntimeAttribute]',
            )
            .length,
        0,
        reason: href,
      );
      expect(
        web.document.documentElement?.getAttribute('data-handoff-hard-mode'),
        'assign',
        reason: href,
      );
    }

    web.document.documentElement
        ?.setAttribute('data-handoff-disable-crypto', '');
    await expectRejected('/handoff-security/articles?case=valid');
    web.document.documentElement
        ?.removeAttribute('data-handoff-disable-crypto');
    await expectRejected('/handoff-security/articles?case=tampered');
    await expectRejected('/handoff-security/articles?case=duplicate');
    await expectRejected('/handoff-security/articles?case=missing');
    await expectRejected('/handoff-security/articles?case=wrong-marker');
    await expectRejected('/handoff-security/forged?case=forged');

    link.href = '/handoff-security/no-ready?case=no-ready';
    link.click();
    await _waitForHardFallback(++fallbackCount);
    expect(initial.isConnected, isFalse);
    expect(web.document.title, 'Rejected target');
    expect(
      web.document.documentElement?.getAttribute('data-handoff-hard-mode'),
      'reload',
    );
    final notReady = web.document.querySelector(
      'script[$seoDomFirstLoadableRuntimeAttribute]',
    );
    expect(notReady, isNotNull);
    expect(
      notReady?.getAttribute(seoDomFirstRuntimeReadyAttribute),
      isNull,
    );
    expect(
      web.document.documentElement?.getAttribute('data-handoff-hard-url'),
      contains('/handoff-security/no-ready?case=no-ready'),
    );
  });
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

void _mountHead(String manifest) {
  final title = web.document.createElement('title')
    ..setAttribute(seoDomFirstNavigationHeadAttribute, '')
    ..textContent = 'Security source';
  final manifestNode = web.document.createElement('script')
    ..setAttribute('type', 'application/json')
    ..setAttribute(seoDomFirstNavigationManifestAttribute, '')
    ..setAttribute('data-esen-navigation-profile', _profile)
    ..textContent = manifest;
  web.document.head
    ?..appendChild(title)
    ..appendChild(manifestNode);
}

web.HTMLElement _mountBody() {
  final content = web.document.createElement('div') as web.HTMLElement
    ..id = 'esen-seo-content'
    ..setAttribute('data-esen-seo-dom-first', 'true');
  final main = web.document.createElement('main');
  main
    ..appendChild(
        web.document.createElement('h1')..textContent = 'Security source')
    ..appendChild(web.document.createElement('a')..textContent = 'Open');
  content.appendChild(main);
  web.document.body?.appendChild(content);
  return content;
}

String _targetDocument(String manifest, String runtimeTags) =>
    '<!DOCTYPE html><html lang="en"><head>'
    '<title $seoDomFirstNavigationHeadAttribute>Rejected target</title>'
    '<script type="application/json" '
    '$seoDomFirstNavigationManifestAttribute '
    'data-esen-navigation-profile="$_profile">$manifest</script>'
    '</head><body>'
    '<div id="esen-seo-content" data-esen-seo-dom-first="true">'
    '<main><h1>Rejected target</h1></main></div>'
    '$runtimeTags<script data-esen-seo-dom-first-runtime></script>'
    '</body></html>';

String _runtimeTag(
  String source, {
  String kind = seoDomFirstCollectionRuntimeKind,
  String? hash,
}) {
  final effectiveHash = hash ?? seoDomFirstCollectionHandoffRuntimeSha256;
  return '<script $seoDomFirstLoadableRuntimeAttribute="$kind" '
      '$seoDomFirstRuntimeSha256Attribute="'
      '$effectiveHash">$source</script>';
}

void _mockFetch(Map<String, String> documents) {
  _runJavaScript(
    'globalThis.__esenOriginalFetch=globalThis.fetch;'
    'globalThis.__esenHandoffDocuments=${jsonEncode(documents)};'
    'globalThis.fetch=async function(u,o){'
    'let key=new URL(String(u),location.href).searchParams.get("case");'
    'let body=globalThis.__esenHandoffDocuments[key];'
    'return new Response(body,{headers:{'
    '"content-type":"text/html; charset=utf-8"}})}',
  );
}

Future<void> _waitForHardFallback(int count) async {
  for (var index = 0; index < 200; index++) {
    if (web.document.documentElement?.getAttribute('data-handoff-hard') ==
        '$count') {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('Timed out waiting for hard-navigation fallback $count.');
}

void _runJavaScript(String source) {
  final script = web.document.createElement('script')..textContent = source;
  web.document.body?.appendChild(script);
  script.remove();
}
