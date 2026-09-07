@TestOn('browser')
library;

import 'dart:convert';
import 'dart:js_interop';

import 'package:crypto/crypto.dart';
import 'package:esen_seo/server.dart';
import 'package:esen_seo/src/components/seo_editorial_workflow_component.dart';
import 'package:esen_seo/src/components/seo_editorial_workflow_transition.dart';
import 'package:esen_seo/src/renderer/dom_first_editorial_workflow_adapter_web.dart';
import 'package:esen_seo/src/renderer/seo_dom_first_navigation_application_profile_runtime.g.dart';
import 'package:esen_seo/src/renderer/seo_dom_first_runtime_handoff.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;

const _profile = 'applicationRuntimeHandoff.navigation.application.'
    'editorial-workflow.article-workflow';
const _applicationId = 'article-workflow';
const _interactionId = 'editorial-process';
const _enhanceEvent = 'esen-seo:test-editorial-workflow-handoff';
const _applicationSource =
    'document.dispatchEvent(new Event("$_enhanceEvent"))';
final _applicationSourceBytes = utf8.encode(_applicationSource).length;
final _applicationSourceHash =
    sha256.convert(utf8.encode(_applicationSource)).toString();
final _applicationRuntime = seoDomFirstApplicationHandoffEnvelope(
  _applicationSource,
  kind: 'editorial-workflow',
);

void main() {
  test('hands one Editorial Workflow artifact across fresh route documents',
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
      ['/draft', _profile, _descriptor()],
      ['/approved', _profile, _descriptor()],
    ]);
    final overviewDocument = _document(
      title: 'Overview',
      body: _overviewBody(),
      manifest: manifest,
    );
    final draftDocument = _document(
      title: 'Draft',
      body: _workflowBody(
        title: 'Draft',
        initialState: initialSeoEditorialWorkflowState,
        nextPath: '/repo/approved',
      ),
      manifest: manifest,
      runtime: _runtimeTag(),
    );
    final approvedDocument = _document(
      title: 'Approved',
      body: _workflowBody(
        title: 'Approved',
        initialState: const SeoEditorialWorkflowState(
          stage: SeoEditorialWorkflowStage.approved,
          history: [
            SeoEditorialWorkflowStage.draft,
            SeoEditorialWorkflowStage.review,
            SeoEditorialWorkflowStage.approved,
          ],
        ),
        nextPath: '/repo/overview',
      ),
      manifest: manifest,
      runtime: _runtimeTag(),
    );

    _mountHead('Overview', manifest);
    final overview = _mountBody(_overviewBody());
    _mockDocuments({
      '/repo/overview': overviewDocument,
      '/repo/draft': draftDocument,
      '/repo/approved': approvedDocument,
    });
    _mountNavigationRuntime();

    (overview.querySelector('a')! as web.HTMLElement).click();
    await _waitFor(
      () =>
          web.window.location.pathname == '/repo/draft' &&
          _enhancedWorkflow() != null,
    );
    final draft = _enhancedWorkflow()!;
    expect(_activeStage(draft), 0);
    expect(_history(draft), [0]);
    _control(draft, 'submit').click();
    expect(_activeStage(draft), 1);
    expect(_history(draft), [0, 1]);
    final firstRuntime = web.document.querySelector(
      'script[$seoDomFirstLoadableRuntimeAttribute]',
    )! as web.HTMLScriptElement;
    expect(
      firstRuntime.getAttribute(seoDomFirstRuntimeKindAttribute),
      'editorial-workflow',
    );
    expect(
      firstRuntime.getAttribute(seoDomFirstRuntimeReadyAttribute),
      'true',
    );
    expect(firstRuntime.nonce, 'trusted-nonce');

    (web.document.querySelector('#next-route')! as web.HTMLElement).click();
    await _waitFor(
      () =>
          web.window.location.pathname == '/repo/approved' &&
          _enhancedWorkflow() != null &&
          _enhancedWorkflow() != draft,
    );
    final approved = _enhancedWorkflow()!;
    expect(draft.isConnected, isFalse);
    expect(_activeStage(approved), 2);
    expect(_history(approved), [0, 1, 2]);
    _control(approved, 'reject').click();
    expect(_activeStage(approved), 0);
    expect(_history(approved), [0, 1, 2, 0]);
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
    expect(approved.isConnected, isFalse);
    expect(_enhancedWorkflow(), isNull);
    expect(
      web.document
          .querySelectorAll('script[$seoDomFirstLoadableRuntimeAttribute]')
          .length,
      0,
    );

    web.window.history.back();
    await _waitFor(
      () =>
          web.window.location.pathname == '/repo/approved' &&
          _enhancedWorkflow() != null,
    );
    final restored = _enhancedWorkflow()!;
    expect(restored, isNot(same(approved)));
    expect(_activeStage(restored), 2);
    expect(_history(restored), [0, 1, 2]);
  });
}

List<Object?> _descriptor() => [
      seoDomFirstApplicationRuntimeOwner,
      'editorial-workflow',
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
    '<a href="/repo/draft">Open workflow</a>'
    '</main></div>';

String _workflowBody({
  required String title,
  required SeoEditorialWorkflowState initialState,
  required String nextPath,
}) {
  final workflow = const HtmlRenderer.domFirst().render(
    buildSeoEditorialWorkflowNodes(
      stages: _stages(),
      initialState: initialState,
      project: _workflowView,
      interactionId: _interactionId,
      heading: '$title workflow',
      interactionLabel: '$title workflow',
      statusLabel: 'Status',
      progressLabel: 'Progress',
      historyLabel: 'History',
      submitLabel: 'Submit',
      approveLabel: 'Approve',
      rejectLabel: 'Reject',
      publishLabel: 'Publish',
    ),
  );
  return '<div id="esen-seo-content" data-esen-seo-dom-first="true">'
      '<main><h1>$title</h1>$workflow'
      '<a id="next-route" href="$nextPath">Next route</a>'
      '</main></div>';
}

List<SeoEditorialWorkflowStageEntry> _stages() => [
      (
        label: 'Draft',
        nodes: [SeoNode(tag: 'p', text: 'Edit content')],
      ),
      (
        label: 'Review',
        nodes: [SeoNode(tag: 'p', text: 'Review content')],
      ),
      (
        label: 'Approved',
        nodes: [SeoNode(tag: 'p', text: 'Approval recorded')],
      ),
      (
        label: 'Published',
        nodes: [SeoNode(tag: 'p', text: 'Content is public')],
      ),
    ];

SeoEditorialWorkflowView _workflowView(SeoEditorialWorkflowState state) {
  const labels = ['Draft', 'Review', 'Approved', 'Published'];
  final label = labels[state.stage.index];
  return SeoEditorialWorkflowView(
    statusText: label,
    summaryText: '$label, ${state.history.length} stages',
    announcementText: 'Status $label',
    activeStageRegion: state.stage.index,
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
    '$seoDomFirstRuntimeKindAttribute="editorial-workflow" '
    '$seoDomFirstRuntimeContractAttribute="'
    '$seoDomFirstRuntimeContractRevision" '
    '$seoDomFirstRuntimeSha256Attribute="$_applicationSourceHash" '
    'nonce="fetched-nonce">$_applicationRuntime</script>';

JSFunction _mountEnhanceListener() {
  final listener = ((web.Event _) {
    enhanceSeoDomFirstEditorialWorkflows(
      interactionIds: const {_interactionId},
      transition: transitionSeoEditorialWorkflow,
      project: _workflowView,
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

void _mountNavigationRuntime() {
  final runtime = web.document.createElement('script')
    ..setAttribute('data-esen-seo-dom-first-runtime', '')
    ..setAttribute('nonce', 'trusted-nonce')
    ..textContent = seoDomFirstNavigationApplicationProfileRuntime;
  web.document.body?.appendChild(runtime);
}

web.Element? _enhancedWorkflow() {
  final workflow = web.document.querySelector(
    '[data-esen-component="editorial-workflow"]',
  );
  return workflow?.getAttribute('data-esen-enhanced') == 'true'
      ? workflow
      : null;
}

web.HTMLElement _control(web.Element root, String action) =>
    root.querySelector('[data-esen-workflow-$action]')! as web.HTMLElement;

int _activeStage(web.Element root) {
  final current = root.querySelector(
    '[data-esen-workflow-progress-stage][aria-current="step"]',
  );
  return int.tryParse(
        current?.getAttribute('data-esen-workflow-progress-stage') ?? '',
      ) ??
      -1;
}

List<int> _history(web.Element root) {
  final items = root.querySelectorAll('[data-esen-workflow-history-stage]');
  return [
    for (var index = 0; index < items.length; index++)
      int.parse((items.item(index) as web.Element)
          .getAttribute('data-esen-workflow-history-stage')!),
  ];
}

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
    'delete globalThis.__esenHandoffDocuments',
  );
}

Future<void> _waitFor(bool Function() condition) async {
  for (var index = 0; index < 250; index++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('Timed out waiting for the Editorial Workflow runtime handoff.');
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
