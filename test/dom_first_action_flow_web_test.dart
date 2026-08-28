@TestOn('browser')
library;

import 'dart:js_interop';

import 'package:esen_seo/core.dart';
import 'package:esen_seo/form.dart';
import 'package:esen_seo/src/renderer/seo_dom_first_action_flow_runtime.g.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;

void main() {
  late web.HTMLElement fixture;

  setUp(() {
    fixture = web.document.createElement('div') as web.HTMLElement
      ..id = 'action-flow-fixture';
    web.document.body?.appendChild(fixture);
  });

  tearDown(() {
    _runJavaScript(
      'if(globalThis.__esenOriginalFetch){globalThis.fetch='
      'globalThis.__esenOriginalFetch;delete globalThis.__esenOriginalFetch}'
      'delete globalThis.__esenResolveFetch',
    );
    web.document.documentElement?.removeAttribute('data-mock-fetch-count');
    fixture.remove();
  });

  test('enhances only the exact complete package structure', () {
    final root = _renderFlow(fixture);
    final steps = root.querySelectorAll('[data-esen-action-flow-step]');

    _runCandidate();

    expect(root.getAttribute('data-esen-enhanced'), 'true');
    expect((steps.item(0)! as web.Element).hasAttribute('hidden'), isFalse);
    expect((steps.item(1)! as web.Element).hasAttribute('hidden'), isTrue);
    expect((steps.item(2)! as web.Element).hasAttribute('hidden'), isTrue);
    expect(
      root
          .querySelector('[data-esen-action-flow-progress="0"]')
          ?.getAttribute('aria-current'),
      'step',
    );
    expect(
      root
          .querySelector('[data-esen-action-flow-navigation]')
          ?.hasAttribute('hidden'),
      isFalse,
    );
    expect(
      root
          .querySelector('[data-esen-action-form-submit]')
          ?.hasAttribute('hidden'),
      isTrue,
    );
  });

  test('validates the current step and focuses only after user navigation', () {
    final root = _renderFlow(fixture);
    _runCandidate();
    final next = root.querySelector('[data-esen-action-flow-next]')!
        as web.HTMLButtonElement;

    next.click();
    expect(
      root
          .querySelector('[data-esen-action-flow-step="0"]')
          ?.hasAttribute('hidden'),
      isFalse,
    );

    (root.querySelector('[name="name"]')! as web.HTMLInputElement).value =
        'Ada';
    next.click();

    final heading =
        root.querySelector('#esen-action-flow-project-step-1-heading');
    expect(
      root
          .querySelector('[data-esen-action-flow-step="1"]')
          ?.hasAttribute('hidden'),
      isFalse,
    );
    expect(web.document.activeElement, heading);
  });

  test('reveals a hidden invalid field before any request', () async {
    final root = _renderFlow(fixture);
    _mockFetch('{"schema":1,"ok":true,"message":"Sent.","fieldErrors":{}}');
    _runCandidate();
    _fillAndReachFinal(root);
    (root.querySelector('[name="name"]')! as web.HTMLInputElement).value = '';

    _submit(root.querySelector('form')! as web.HTMLFormElement);
    await _settle();

    expect(
      root
          .querySelector('[data-esen-action-flow-step="0"]')
          ?.hasAttribute('hidden'),
      isFalse,
    );
    expect(
      web.document.documentElement?.getAttribute('data-mock-fetch-count'),
      '0',
    );
  });

  test('applies bounded server errors and reveals their owning step', () async {
    final root = _renderFlow(fixture);
    _mockFetch(
      '{"schema":1,"ok":false,"message":"Choose another service.",'
      '"fieldErrors":{"service":"Unavailable."}}',
    );
    _runCandidate();
    _fillAndReachFinal(root);

    _submit(root.querySelector('form')! as web.HTMLFormElement);
    await _settle();

    expect(
      root
          .querySelector('[data-esen-action-flow-step="1"]')
          ?.hasAttribute('hidden'),
      isFalse,
    );
    expect(
      root.querySelector('[data-esen-action-form-error="1"]')?.textContent,
      'Unavailable.',
    );
    expect(
        root.querySelectorAll('[data-esen-action-form-error] img').length, 0);
  });

  test('prevents duplicate requests while one response is pending', () async {
    final root = _renderFlow(fixture);
    _runJavaScript(
      'globalThis.__esenOriginalFetch=globalThis.fetch;'
      'document.documentElement.dataset.mockFetchCount="0";'
      'globalThis.fetch=function(){'
      'document.documentElement.dataset.mockFetchCount=String('
      'Number(document.documentElement.dataset.mockFetchCount)+1);'
      'return new Promise(r=>globalThis.__esenResolveFetch=r)}',
    );
    _runCandidate();
    _fillAndReachFinal(root);
    final form = root.querySelector('form')! as web.HTMLFormElement;

    _submit(form);
    _submit(form);
    expect(
      web.document.documentElement?.getAttribute('data-mock-fetch-count'),
      '1',
    );
    _runJavaScript(
      'globalThis.__esenResolveFetch(new Response('
      '\'{"schema":1,"ok":true,"message":"Sent.","fieldErrors":{}}\','
      '{headers:{"content-type":"application/json"}}))',
    );
    await _settle();
  });

  test('activates only the selected branch and updates native constraints', () {
    final root =
        _renderFlow(fixture, definition: _branchedDefinition('branch'));
    _runCandidate();
    final service =
        root.querySelector('[name="service"]')! as web.HTMLSelectElement;
    final website =
        root.querySelector('[name="website_goal"]')! as web.HTMLInputElement;
    final shop =
        root.querySelector('[name="shop_catalog"]')! as web.HTMLInputElement;

    expect(website.disabled, isTrue);
    expect(shop.disabled, isTrue);
    _setChoice(service, 'website');
    (root.querySelector('[name="name"]')! as web.HTMLInputElement).value =
        'Ada';
    (root.querySelector('[data-esen-action-flow-next]')!
            as web.HTMLButtonElement)
        .click();

    expect(
      root
          .querySelector('[data-esen-action-flow-step="1"]')
          ?.hasAttribute('hidden'),
      isFalse,
    );
    expect(website.disabled, isFalse);
    expect(website.required, isTrue);
    expect(shop.disabled, isTrue);

    (root.querySelector('[data-esen-action-flow-previous]')!
            as web.HTMLButtonElement)
        .click();
    _setChoice(service, 'shop');
    (root.querySelector('[data-esen-action-flow-next]')!
            as web.HTMLButtonElement)
        .click();

    expect(
      root
          .querySelector('[data-esen-action-flow-step="2"]')
          ?.hasAttribute('hidden'),
      isFalse,
    );
    expect(website.disabled, isTrue);
    expect(website.required, isFalse);
    expect(shop.disabled, isFalse);
    expect(shop.required, isTrue);
  });

  test('fills review text only for validated fields in the active branch', () {
    final root =
        _renderFlow(fixture, definition: _branchedDefinition('review'));
    _runCandidate();
    (root.querySelector('[name="name"]')! as web.HTMLInputElement).value =
        '<b>Ada</b>';
    _setChoice(
      root.querySelector('[name="service"]')! as web.HTMLSelectElement,
      'website',
    );
    final next = root.querySelector('[data-esen-action-flow-next]')!
        as web.HTMLButtonElement;
    next.click();
    (root.querySelector('[name="website_goal"]')! as web.HTMLInputElement)
        .value = 'Fast product site';
    next.click();
    (root.querySelector('[name="email"]')! as web.HTMLInputElement).value =
        'ada@example.com';
    (root.querySelector('[name="consent"]')! as web.HTMLInputElement).checked =
        true;
    next.click();

    final review = root.querySelector('[data-esen-action-flow-review]')!;
    expect(review.hasAttribute('hidden'), isFalse);
    expect(
      root
          .querySelector('[data-esen-action-flow-review-value="0"]')
          ?.textContent,
      '<b>Ada</b>',
    );
    expect(
      root
          .querySelector('[data-esen-action-flow-review-value="1"]')
          ?.textContent,
      'Website',
    );
    expect(
      root
          .querySelector('[data-esen-action-flow-review-row="3"]')
          ?.hasAttribute('hidden'),
      isTrue,
    );
    expect(review.querySelectorAll('b').length, 0);
  });

  test('leaves forged branch metadata as complete static HTML', () {
    final root =
        _renderFlow(fixture, definition: _branchedDefinition('branch-forged'));
    root
        .querySelector('[data-esen-action-flow-step="1"]')!
        .setAttribute('data-esen-action-flow-when-value', 'admin');

    _runCandidate();

    expect(root.hasAttribute('data-esen-enhanced'), isFalse);
    expect(
      root
          .querySelector('[data-esen-action-flow-step="1"]')
          ?.hasAttribute('hidden'),
      isFalse,
    );
  });

  test('leaves altered, duplicate-id and forged choice structures native', () {
    final altered = _renderFlow(fixture, actionId: 'altered');
    altered.querySelector('form')!.setAttribute('action', '/elsewhere');
    final duplicate = _renderFlow(fixture, actionId: 'duplicate');
    fixture.appendChild(web.document.createElement('div')..id = duplicate.id);
    final forged = _renderFlow(fixture, actionId: 'forged');
    final select = forged.querySelector('select')!;
    select.appendChild(
      web.document.createElement('option')
        ..setAttribute('value', 'website')
        ..textContent = 'Duplicate',
    );

    _runCandidate();

    expect(altered.hasAttribute('data-esen-enhanced'), isFalse);
    expect(duplicate.hasAttribute('data-esen-enhanced'), isFalse);
    expect(forged.hasAttribute('data-esen-enhanced'), isFalse);
  });
}

web.HTMLElement _renderFlow(
  web.HTMLElement fixture, {
  String actionId = 'project',
  SeoActionFlowDefinition? definition,
}) {
  var container = fixture.querySelector('#esen-seo-content');
  if (container == null) {
    container = web.document.createElement('div')
      ..id = 'esen-seo-content'
      ..setAttribute('data-esen-seo-dom-first', 'true');
    fixture.appendChild(container);
  }
  final holder = web.document.createElement('div');
  holder.setHTMLUnsafe(
    const HtmlRenderer.domFirst()
        .render(buildSeoActionFlowNodes(definition ?? _definition(actionId)))
        .toJS,
  );
  final root = holder.firstElementChild! as web.HTMLElement;
  container.appendChild(root);
  return root;
}

void _setChoice(web.HTMLSelectElement select, String value) {
  select.value = value;
  select.dispatchEvent(web.Event(
    'change',
    web.EventInit(bubbles: true, cancelable: true),
  ));
}

void _fillAndReachFinal(web.HTMLElement root) {
  (root.querySelector('[name="name"]')! as web.HTMLInputElement).value = 'Ada';
  (root.querySelector('[data-esen-action-flow-next]')! as web.HTMLButtonElement)
      .click();
  (root.querySelector('[name="service"]')! as web.HTMLSelectElement).value =
      'website';
  (root.querySelector('[data-esen-action-flow-next]')! as web.HTMLButtonElement)
      .click();
  (root.querySelector('[name="email"]')! as web.HTMLInputElement).value =
      'ada@example.com';
  (root.querySelector('[name="consent"]')! as web.HTMLInputElement).checked =
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
  await Future<void>.delayed(Duration.zero);
}

void _mockFetch(String json) {
  final encoded = json.replaceAll(r'\', r'\\').replaceAll("'", r"\'");
  _runJavaScript(
    'globalThis.__esenOriginalFetch=globalThis.fetch;'
    'document.documentElement.dataset.mockFetchCount="0";'
    'globalThis.fetch=async function(){'
    'document.documentElement.dataset.mockFetchCount=String('
    'Number(document.documentElement.dataset.mockFetchCount)+1);'
    "return new Response('$encoded',{headers:{"
    "'content-type':'application/json; charset=utf-8'}})}",
  );
}

void _runCandidate() => _runJavaScript(seoDomFirstActionFlowRuntime);

void _runJavaScript(String source) {
  final script = web.document.createElement('script')..textContent = source;
  web.document.body?.appendChild(script);
  script.remove();
}

SeoActionFlowDefinition _definition(String actionId) => SeoActionFlowDefinition(
      form: SeoActionFormDefinition(
        actionId: actionId,
        returnPath: '/contact/',
        heading: 'Start a project',
        description: 'Tell us what you need.',
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
            name: 'service',
            label: 'Service',
            kind: SeoActionFormFieldKind.choice,
            required: true,
            choicePrompt: 'Choose a service',
            options: [
              SeoActionFormOption(value: 'website', label: 'Website'),
              SeoActionFormOption(value: 'shop', label: 'Online shop'),
            ],
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
      ),
      steps: const [
        SeoActionFlowStep(
          label: 'About you',
          description: 'Your name.',
          fieldNames: ['name'],
        ),
        SeoActionFlowStep(
          label: 'Project',
          description: 'Choose a service.',
          fieldNames: ['service'],
        ),
        SeoActionFlowStep(
          label: 'Contact',
          description: 'Where we can reply.',
          fieldNames: ['email', 'consent'],
        ),
      ],
      previousLabel: 'Previous',
      nextLabel: 'Next',
      progressLabel: 'Project progress',
    );

SeoActionFlowDefinition _branchedDefinition(String actionId) =>
    SeoActionFlowDefinition(
      form: SeoActionFormDefinition(
        actionId: actionId,
        returnPath: '/contact/',
        heading: 'Plan a project',
        description: 'Follow the relevant branch.',
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
            name: 'service',
            label: 'Service',
            kind: SeoActionFormFieldKind.choice,
            required: true,
            choicePrompt: 'Choose a service',
            options: [
              SeoActionFormOption(value: 'website', label: 'Website'),
              SeoActionFormOption(value: 'shop', label: 'Online shop'),
            ],
          ),
          SeoActionFormField(
            name: 'website_goal',
            label: 'Website goal',
            kind: SeoActionFormFieldKind.text,
            required: true,
          ),
          SeoActionFormField(
            name: 'shop_catalog',
            label: 'Catalog size',
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
      ),
      steps: const [
        SeoActionFlowStep(
          label: 'Project',
          description: 'Choose a project type.',
          fieldNames: ['name', 'service'],
        ),
        SeoActionFlowStep(
          label: 'Website details',
          description: 'Describe the website.',
          fieldNames: ['website_goal'],
          condition: SeoActionFlowCondition.choiceEquals(
            fieldName: 'service',
            value: 'website',
          ),
        ),
        SeoActionFlowStep(
          label: 'Shop details',
          description: 'Describe the catalog.',
          fieldNames: ['shop_catalog'],
          condition: SeoActionFlowCondition.choiceEquals(
            fieldName: 'service',
            value: 'shop',
          ),
        ),
        SeoActionFlowStep(
          label: 'Contact',
          description: 'Where we can reply.',
          fieldNames: ['email', 'consent'],
        ),
      ],
      previousLabel: 'Previous',
      nextLabel: 'Next',
      progressLabel: 'Project progress',
      review: const SeoActionFlowReview(
        label: 'Review',
        description: 'Check the active values.',
        emptyValueLabel: 'Not provided',
        consentAcceptedLabel: 'Confirmed',
        consentDeclinedLabel: 'Not confirmed',
      ),
    );
