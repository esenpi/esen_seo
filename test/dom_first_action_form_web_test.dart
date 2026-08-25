@TestOn('browser')
library;

import 'dart:js_interop';

import 'package:esen_seo/form.dart';
import 'package:esen_seo/src/renderer/seo_dom_first_action_form_runtime.g.dart';
import 'package:esen_seo/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;

void main() {
  late web.HTMLElement fixture;

  setUp(() {
    fixture = web.document.createElement('div') as web.HTMLElement
      ..id = 'action-form-fixture';
    web.document.body?.appendChild(fixture);
  });

  tearDown(() {
    _runJavaScript(
      'if(globalThis.__esenOriginalFetch){globalThis.fetch='
      'globalThis.__esenOriginalFetch;delete globalThis.__esenOriginalFetch}'
      'delete globalThis.__esenResolveFetch',
    );
    web.document.documentElement?.removeAttribute('data-mock-body');
    web.document.documentElement?.removeAttribute('data-mock-fetch-count');
    fixture.remove();
  });

  test('enhances the exact renderer-owned form structure', () {
    final form = _renderForm(fixture);

    _runCandidate();

    expect(form.getAttribute('data-esen-enhanced'), 'true');
    expect(form.querySelectorAll('[data-esen-action-form-control]').length, 3);
    expect(form.querySelectorAll('[data-esen-action-form-error]').length, 3);
  });

  test('applies bounded JSON errors through text content only', () async {
    final form = _renderForm(fixture);
    _mockFetch(
      '{"schema":1,"ok":false,"message":"Please check the form.",'
      '"fieldErrors":{"email":"<img src=x onerror=alert(1)>"}}',
      status: 422,
    );
    _runCandidate();
    final controls = form.querySelectorAll('[data-esen-action-form-control]');
    (controls.item(0)! as web.HTMLInputElement).value = 'Ada';
    (controls.item(1)! as web.HTMLInputElement).value = 'ada@example.com';
    (controls.item(2)! as web.HTMLInputElement).checked = true;

    _submit(form);
    await _settle();

    final error = form.querySelector('[data-esen-action-form-error="1"]')!;
    final email = controls.item(1)! as web.HTMLInputElement;
    expect(error.textContent, '<img src=x onerror=alert(1)>');
    expect(error.hasAttribute('hidden'), isFalse);
    expect(error.querySelectorAll('img').length, 0);
    expect(email.getAttribute('aria-invalid'), 'true');
    expect(
      form.querySelector('[data-esen-action-form-status]')?.textContent,
      'Please check the form.',
    );
    expect(
      web.document.documentElement?.getAttribute('data-mock-body'),
      contains('email=ada%40example.com'),
    );

    email.dispatchEvent(web.Event('input'));
    expect(error.hasAttribute('hidden'), isTrue);
    expect(email.hasAttribute('aria-invalid'), isFalse);
  });

  test('resets native controls only after a successful response', () async {
    final form = _renderForm(fixture);
    _mockFetch(
      '{"schema":1,"ok":true,"message":"Sent.","fieldErrors":{}}',
    );
    _runCandidate();
    final name = form.querySelector('[name="name"]')! as web.HTMLInputElement
      ..value = 'Ada';
    final email = form.querySelector('[name="email"]')! as web.HTMLInputElement
      ..value = 'ada@example.com';
    final consent = form.querySelector('[name="consent"]')!
        as web.HTMLInputElement
      ..checked = true;

    _submit(form);
    await _settle();

    expect(name.value, isEmpty);
    expect(email.value, isEmpty);
    expect(consent.checked, isFalse);
    expect(
      form.querySelector('[data-esen-action-form-status]')?.textContent,
      'Sent.',
    );
    expect(form.parentElement?.hasAttribute('aria-busy'), isFalse);
  });

  test('prevents a second submission while one request is in flight', () async {
    final form = _renderForm(fixture);
    _fillValid(form);
    _runJavaScript(
      'globalThis.__esenOriginalFetch=globalThis.fetch;'
      'document.documentElement.dataset.mockFetchCount="0";'
      'globalThis.fetch=function(){'
      'document.documentElement.dataset.mockFetchCount=String('
      'Number(document.documentElement.dataset.mockFetchCount)+1);'
      'return new Promise(r=>globalThis.__esenResolveFetch=r)}',
    );
    _runCandidate();

    final first = web.Event(
      'submit',
      web.EventInit(bubbles: true, cancelable: true),
    );
    final second = web.Event(
      'submit',
      web.EventInit(bubbles: true, cancelable: true),
    );
    form.dispatchEvent(first);
    form.dispatchEvent(second);

    expect(first.defaultPrevented, isTrue);
    expect(second.defaultPrevented, isTrue);
    expect(
      web.document.documentElement?.getAttribute('data-mock-fetch-count'),
      '1',
    );
    _runJavaScript(
      'globalThis.__esenResolveFetch(new Response('
      "'{\"schema\":1,\"ok\":true,\"message\":\"Sent.\","
      "\"fieldErrors\":{}}',{headers:{'content-type':'application/json'}}))",
    );
    await _settle();
  });

  test('contains malformed responses and does not create markup', () async {
    final form = _renderForm(fixture);
    _mockFetch(
      '{"schema":1,"ok":true,"message":"<svg onload=alert(1)>",'
      '"fieldErrors":{},"extra":"not closed"}',
    );
    _runCandidate();
    _fillValid(form);

    _submit(form);
    await _settle();

    final status = form.querySelector('[data-esen-action-form-status]')!;
    expect(status.textContent, 'Try again later');
    expect(status.querySelectorAll('svg').length, 0);
    expect(form.querySelectorAll('[onload]').length, 0);
  });

  test('reports a network failure without retrying', () async {
    final form = _renderForm(fixture);
    _fillValid(form);
    _runJavaScript(
      'globalThis.__esenOriginalFetch=globalThis.fetch;'
      'document.documentElement.dataset.mockFetchCount="0";'
      'globalThis.fetch=function(){'
      'document.documentElement.dataset.mockFetchCount=String('
      'Number(document.documentElement.dataset.mockFetchCount)+1);'
      'return Promise.reject(new Error("offline"))}',
    );
    _runCandidate();

    _submit(form);
    await _settle();

    expect(
      web.document.documentElement?.getAttribute('data-mock-fetch-count'),
      '1',
    );
    expect(
      form.querySelector('[data-esen-action-form-status]')?.textContent,
      'Try again later',
    );
  });

  test('leaves altered, duplicate-id and inert structures native', () {
    final altered = _renderForm(fixture, actionId: 'altered');
    altered.setAttribute('action', '/somewhere-else');
    final duplicate = _renderForm(fixture, actionId: 'duplicate');
    final duplicateId = web.document.createElement('div')
      ..id = duplicate.parentElement!.id;
    fixture.appendChild(duplicateId);
    final inert = _renderForm(fixture, actionId: 'inert');
    inert.parentElement!.setAttribute('inert', '');

    _runCandidate();

    expect(altered.hasAttribute('data-esen-enhanced'), isFalse);
    expect(duplicate.hasAttribute('data-esen-enhanced'), isFalse);
    expect(inert.hasAttribute('data-esen-enhanced'), isFalse);
  });

  test('feature remains an explicit route opt-in', () {
    expect(seoDomFirstFeatureScriptHtml(const {}), isEmpty);
    expect(seoDomFirstFeatureStyleHtml(const {}), isEmpty);
    expect(
      seoDomFirstFeatureScriptHtml(const {SeoDomFirstFeature.actionForm}),
      contains('data-esen-seo-dom-first-runtime'),
    );
    expect(
      seoDomFirstFeatureStyleHtml(const {SeoDomFirstFeature.actionForm}),
      contains('[data-esen-component="action-form"]'),
    );
  });
}

web.HTMLFormElement _renderForm(
  web.HTMLElement fixture, {
  String actionId = 'contact',
}) {
  var container = fixture.querySelector('#esen-seo-content');
  if (container == null) {
    container = web.document.createElement('div')
      ..id = 'esen-seo-content'
      ..setAttribute('data-esen-seo-dom-first', 'true');
    fixture.appendChild(container);
  }
  final nodes = buildSeoActionFormNodes(_definition(actionId));
  final holder = web.document.createElement('div');
  holder.setHTMLUnsafe(const HtmlRenderer.domFirst().render(nodes).toJS);
  final root = holder.firstElementChild!;
  container.appendChild(root);
  return root.querySelector('form')! as web.HTMLFormElement;
}

void _fillValid(web.HTMLFormElement form) {
  (form.querySelector('[name="name"]')! as web.HTMLInputElement).value = 'Ada';
  (form.querySelector('[name="email"]')! as web.HTMLInputElement).value =
      'ada@example.com';
  (form.querySelector('[name="consent"]')! as web.HTMLInputElement).checked =
      true;
}

void _submit(web.HTMLFormElement form) {
  form.dispatchEvent(web.Event(
    'submit',
    web.EventInit(bubbles: true, cancelable: true),
  ));
}

Future<void> _settle() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void _mockFetch(String json, {int status = 200}) {
  final encoded = json.replaceAll(r'\', r'\\').replaceAll("'", r"\'");
  _runJavaScript(
    'globalThis.__esenOriginalFetch=globalThis.fetch;'
    'globalThis.fetch=async function(_u,o){'
    'document.documentElement.dataset.mockBody=String(o.body);'
    "return new Response('$encoded',{status:$status,headers:{"
    "'content-type':'application/json; charset=utf-8'}})}",
  );
}

void _runCandidate() => _runJavaScript(seoDomFirstActionFormRuntime);

void _runJavaScript(String source) {
  final script = web.document.createElement('script')..textContent = source;
  web.document.body?.appendChild(script);
  script.remove();
}

SeoActionFormDefinition _definition(String actionId) => SeoActionFormDefinition(
      actionId: actionId,
      returnPath: '/contact/',
      heading: 'Contact',
      description: 'Write to us.',
      submitLabel: 'Send',
      pendingLabel: 'Sending',
      failureLabel: 'Try again later',
      statusLabel: 'Submission status',
      fields: const [
        SeoActionFormField(
          name: 'name',
          label: 'Name',
          kind: SeoActionFormFieldKind.text,
          required: true,
        ),
        SeoActionFormField(
          name: 'email',
          label: 'Email',
          kind: SeoActionFormFieldKind.email,
          required: true,
        ),
        SeoActionFormField(
          name: 'consent',
          label: 'Consent',
          kind: SeoActionFormFieldKind.consent,
          required: true,
        ),
      ],
    );
