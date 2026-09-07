@TestOn('browser')
library;

import 'dart:convert';
import 'dart:js_interop';

import 'package:crypto/crypto.dart';
import 'package:esen_seo/server.dart';
import 'package:esen_seo/src/components/seo_approval_checklist_component.dart';
import 'package:esen_seo/src/components/seo_approval_checklist_transition.dart';
import 'package:esen_seo/src/renderer/dom_first_approval_checklist_adapter_web.dart';
import 'package:esen_seo/src/renderer/seo_dom_first_navigation_application_profile_runtime.g.dart';
import 'package:esen_seo/src/renderer/seo_dom_first_runtime_handoff.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;

const _profile = 'applicationRuntimeHandoff.navigation.application.'
    'approval-checklist.review-checklist';
const _applicationId = 'review-checklist';
const _interactionId = 'review-items';
const _enhanceEvent = 'esen-seo:test-approval-checklist-handoff';
const _applicationSource =
    'document.dispatchEvent(new Event("$_enhanceEvent"))';
final _applicationSourceBytes = utf8.encode(_applicationSource).length;
final _applicationSourceHash =
    sha256.convert(utf8.encode(_applicationSource)).toString();
final _applicationRuntime = seoDomFirstApplicationHandoffEnvelope(
  _applicationSource,
  kind: 'approval-checklist',
);

void main() {
  test('hands one Approval Checklist artifact across fresh route documents',
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

    web.window.history.replaceState(null, '', '/repo/overview');
    final manifest = _manifest([
      ['/overview', _profile, null],
      ['/draft-review', _profile, _descriptor()],
      ['/final-review', _profile, _descriptor()],
    ]);
    final overviewDocument = _document(
      title: 'Overview',
      body: _overviewBody(),
      manifest: manifest,
    );
    final draftDocument = _document(
      title: 'Draft review',
      body: _checklistBody(
        title: 'Draft review',
        initialFlags: const [false, false, false],
        nextPath: '/repo/final-review',
      ),
      manifest: manifest,
      runtime: _runtimeTag(),
    );
    final finalDocument = _document(
      title: 'Final review',
      body: _checklistBody(
        title: 'Final review',
        initialFlags: const [true, true, false],
        nextPath: '/repo/overview',
      ),
      manifest: manifest,
      runtime: _runtimeTag(),
    );

    _mountHead('Overview', manifest);
    final overview = _mountBody(_overviewBody());
    _mockDocuments({
      '/repo/overview': overviewDocument,
      '/repo/draft-review': draftDocument,
      '/repo/final-review': finalDocument,
    });
    _mountNavigationRuntime();

    (overview.querySelector('a')! as web.HTMLElement).click();
    await _waitFor(
      () =>
          web.window.location.pathname == '/repo/draft-review' &&
          _enhancedChecklist() != null,
    );
    final draft = _enhancedChecklist()!;
    expect(_flags(draft), [false, false, false]);
    _control(draft, 0).click();
    expect(_flags(draft), [true, false, false]);
    final firstRuntime = web.document.querySelector(
      'script[$seoDomFirstLoadableRuntimeAttribute]',
    )! as web.HTMLScriptElement;
    expect(
      firstRuntime.getAttribute(seoDomFirstRuntimeKindAttribute),
      'approval-checklist',
    );
    expect(
      firstRuntime.getAttribute(seoDomFirstRuntimeReadyAttribute),
      'true',
    );
    expect(firstRuntime.nonce, 'trusted-nonce');

    (web.document.querySelector('#next-route')! as web.HTMLElement).click();
    await _waitFor(
      () =>
          web.window.location.pathname == '/repo/final-review' &&
          _enhancedChecklist() != null &&
          _enhancedChecklist() != draft,
    );
    final finalReview = _enhancedChecklist()!;
    expect(draft.isConnected, isFalse);
    expect(_flags(finalReview), [true, true, false]);
    _control(finalReview, 2).click();
    expect(_flags(finalReview), [true, true, true]);
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
    expect(finalReview.isConnected, isFalse);
    expect(_enhancedChecklist(), isNull);
    expect(
      web.document
          .querySelectorAll('script[$seoDomFirstLoadableRuntimeAttribute]')
          .length,
      0,
    );

    web.window.history.back();
    await _waitFor(
      () =>
          web.window.location.pathname == '/repo/final-review' &&
          _enhancedChecklist() != null,
    );
    final restored = _enhancedChecklist()!;
    expect(restored, isNot(same(finalReview)));
    expect(_flags(restored), [true, true, false]);
  });

  test('initializes a direct Checklist document before navigation starts',
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

    web.window.history.replaceState(null, '', '/repo/direct-review');
    final manifest = _manifest([
      ['/direct-review', _profile, _descriptor()],
      ['/overview', _profile, null],
    ]);
    final body = _checklistBody(
      title: 'Direct review',
      initialFlags: const [false, true, false],
      nextPath: '/repo/overview',
    );
    final overviewDocument = _document(
      title: 'Overview',
      body: _overviewBody(),
      manifest: manifest,
    );
    _mountHead('Direct review', manifest);
    final direct = _mountBody(body);

    expect(direct.querySelectorAll('button'), isEmpty);
    expect(direct.textContent, contains('Verify article text'));
    expect(direct.textContent, contains('Confirm metadata'));
    final runtime = _mountApplicationRuntime();
    final checklist = _enhancedChecklist()!;
    expect(_flags(checklist), [false, true, false]);
    expect(
      runtime.getAttribute(seoDomFirstRuntimeReadyAttribute),
      'true',
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
    expect(checklist.isConnected, isFalse);
    expect(_enhancedChecklist(), isNull);
  });
}

List<Object?> _descriptor() => [
      seoDomFirstApplicationRuntimeOwner,
      'approval-checklist',
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
    '<a href="/repo/draft-review">Open checklist</a>'
    '</main></div>';

String _checklistBody({
  required String title,
  required List<bool> initialFlags,
  required String nextPath,
}) {
  final checklist = const HtmlRenderer.domFirst().render(
    buildSeoApprovalChecklistNodes(
      items: _items(),
      initialState: SeoApprovalChecklistState(checked: initialFlags),
      project: _checklistView,
      interactionId: _interactionId,
      heading: '$title checklist',
      interactionLabel: '$title checklist',
      statusLabel: 'Status',
      progressLabel: 'Progress',
    ),
  );
  return '<div id="esen-seo-content" data-esen-seo-dom-first="true">'
      '<main><h1>$title</h1>$checklist'
      '<a id="next-route" href="$nextPath">Next route</a>'
      '</main></div>';
}

List<SeoApprovalChecklistItemEntry> _items() => [
      (
        label: 'Content',
        nodes: [SeoNode(tag: 'p', text: 'Verify article text')],
      ),
      (
        label: 'Sources',
        nodes: [SeoNode(tag: 'p', text: 'Check source references')],
      ),
      (
        label: 'SEO',
        nodes: [SeoNode(tag: 'p', text: 'Confirm metadata')],
      ),
    ];

SeoApprovalChecklistView _checklistView(SeoApprovalChecklistState state) {
  final count = seoApprovalChecklistCheckedCount(state);
  return SeoApprovalChecklistView(
    statusText: isSeoApprovalChecklistComplete(state) ? 'Ready' : 'Open',
    summaryText: '$count / ${state.checked.length} complete',
    announcementText: '$count review items complete',
  );
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

String _runtimeTag() => '<script $seoDomFirstLoadableRuntimeAttribute="'
    '$seoDomFirstApplicationRuntimeOwner" '
    '$seoDomFirstApplicationScriptAttribute="$_applicationId" '
    '$seoDomFirstRuntimeKindAttribute="approval-checklist" '
    '$seoDomFirstRuntimeContractAttribute="'
    '$seoDomFirstRuntimeContractRevision" '
    '$seoDomFirstRuntimeSha256Attribute="$_applicationSourceHash" '
    'nonce="fetched-nonce">$_applicationRuntime</script>';

JSFunction _mountEnhanceListener() {
  final listener = ((web.Event _) {
    enhanceSeoDomFirstApprovalChecklists(
      interactionIds: const {_interactionId},
      transition: transitionSeoApprovalChecklist,
      project: _checklistView,
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

web.HTMLScriptElement _mountApplicationRuntime() {
  final runtime = web.document.createElement('script') as web.HTMLScriptElement
    ..setAttribute(
      seoDomFirstLoadableRuntimeAttribute,
      seoDomFirstApplicationRuntimeOwner,
    )
    ..setAttribute(seoDomFirstApplicationScriptAttribute, _applicationId)
    ..setAttribute(seoDomFirstRuntimeKindAttribute, 'approval-checklist')
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
    'document.documentElement.dataset.approvalHandoffArmed='
    'history.state&&history.state.esenSeoNavigation===1?"1":"0"',
  );
  return web.document.documentElement
          ?.getAttribute('data-approval-handoff-armed') ==
      '1';
}

web.Element? _enhancedChecklist() {
  final checklist = web.document.querySelector(
    '[data-esen-component="approval-checklist"]',
  );
  return checklist?.getAttribute('data-esen-enhanced') == 'true'
      ? checklist
      : null;
}

web.HTMLElement _control(web.Element root, int index) => root.querySelector(
      '[data-esen-checklist-control="$index"]',
    )! as web.HTMLElement;

List<bool> _flags(web.Element root) => [
      for (var index = 0; index < _items().length; index++)
        _control(root, index).getAttribute('aria-checked') == 'true',
    ];

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

void _restoreFetch() {
  _runJavaScript(
    'if(globalThis.__esenOriginalFetch)'
    'globalThis.fetch=globalThis.__esenOriginalFetch;'
    'delete globalThis.__esenOriginalFetch;'
    'delete globalThis.__esenHandoffDocuments;'
    'delete document.documentElement.dataset.approvalHandoffArmed',
  );
}

Future<void> _waitFor(bool Function() condition) async {
  for (var index = 0; index < 250; index++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('Timed out waiting for the Approval Checklist runtime handoff.');
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
