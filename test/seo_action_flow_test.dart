import 'dart:convert';

import 'package:esen_seo/server.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shelf/shelf.dart';

void main() {
  group('action flow plan', () {
    test('prepares an exact ordered partition and closed choice options', () {
      final plan = prepareSeoActionFlow(_flow);

      expect(plan, isNotNull);
      expect(plan!.steps, hasLength(3));
      expect(plan.steps[1].firstFieldIndex, 1);
      expect(plan.steps[1].fields.single.name, 'service');
      expect(
        plan.form.fields[1].options.map((option) => option.value),
        ['website', 'shop'],
      );
    });

    test('rejects missing, repeated, reordered and empty step fields', () {
      for (final steps in <List<SeoActionFlowStep>>[
        const [
          SeoActionFlowStep(
            label: 'One',
            description: 'One.',
            fieldNames: ['name'],
          ),
          SeoActionFlowStep(
            label: 'Two',
            description: 'Two.',
            fieldNames: ['service', 'email'],
          ),
        ],
        const [
          SeoActionFlowStep(
            label: 'One',
            description: 'One.',
            fieldNames: ['service'],
          ),
          SeoActionFlowStep(
            label: 'Two',
            description: 'Two.',
            fieldNames: ['name', 'email', 'consent'],
          ),
        ],
        const [
          SeoActionFlowStep(
            label: 'One',
            description: 'One.',
            fieldNames: ['name'],
          ),
          SeoActionFlowStep(
            label: 'Two',
            description: 'Two.',
            fieldNames: ['name', 'email', 'consent'],
          ),
        ],
        const [
          SeoActionFlowStep(
            label: 'One',
            description: 'One.',
            fieldNames: [],
          ),
          SeoActionFlowStep(
            label: 'Two',
            description: 'Two.',
            fieldNames: ['name', 'service', 'email', 'consent'],
          ),
        ],
      ]) {
        expect(
          prepareSeoActionFlow(_withSteps(steps)),
          isNull,
          reason: '$steps',
        );
      }
    });

    test('rejects open or ambiguous choice vocabularies', () {
      final cases = <List<SeoActionFormOption>>[
        const [SeoActionFormOption(value: 'one', label: 'One')],
        const [
          SeoActionFormOption(value: 'same', label: 'One'),
          SeoActionFormOption(value: 'same', label: 'Two'),
        ],
        const [
          SeoActionFormOption(value: '../one', label: 'One'),
          SeoActionFormOption(value: 'two', label: 'Two'),
        ],
      ];
      for (final (index, options) in cases.indexed) {
        expect(
          prepareSeoActionFlow(_withOptions(options)),
          isNull,
          reason: 'case $index',
        );
      }
    });

    test('strips bidi controls from bounded option labels', () {
      final plan = prepareSeoActionFlow(_withOptions(const [
        SeoActionFormOption(value: 'one', label: 'One\u202e'),
        SeoActionFormOption(value: 'two', label: 'Two'),
      ]));

      expect(plan, isNotNull);
      expect(plan!.form.fields[1].options.first.label, 'One');
    });

    test('treats an unknown submitted choice as malformed', () {
      final form = prepareSeoActionFlow(_flow)!.form;

      final valid = validateSeoActionFormValues(form, const {
        'name': 'Ada',
        'service': 'website',
        'email': 'ada@example.com',
        'consent': 'accepted',
      });
      final forged = validateSeoActionFormValues(form, const {
        'name': 'Ada',
        'service': 'admin-only',
        'email': 'ada@example.com',
        'consent': 'accepted',
      });

      expect(valid.isValid, isTrue);
      expect(valid.values!.choice('service'), 'website');
      expect(forged.malformed, isTrue);
      expect(forged.values, isNull);
    });

    test('uses a bounded non-wrapping pure navigation transition', () {
      var state = initialSeoActionFlowState(count: 3);
      state = transitionSeoActionFlow(state, const SeoActionFlowPrevious());
      expect(state.index, 0);
      state = transitionSeoActionFlow(state, const SeoActionFlowNext());
      state = transitionSeoActionFlow(state, const SeoActionFlowNext());
      state = transitionSeoActionFlow(state, const SeoActionFlowNext());
      expect(state, const SeoActionFlowState(index: 2, count: 3));
      expect(
        transitionSeoActionFlow(
          const SeoActionFlowState(index: 20, count: 3),
          const SeoActionFlowPrevious(),
        ).index,
        1,
      );
    });
  });

  group('action flow rendering and delivery', () {
    test('normal rendering remains a complete non-interactive summary', () {
      final html = const HtmlRenderer().render(buildSeoActionFlowNodes(_flow));

      expect(html, contains('class="esen-seo-action-flow-summary"'));
      expect(html, contains('Website'));
      expect(html, isNot(contains('<form')));
      expect(html, isNot(contains('<select')));
      expect(html, isNot(contains('<button')));
    });

    test('DOM-first rendering emits one complete ordinary POST form', () {
      final html = const HtmlRenderer.domFirst().render(
        buildSeoActionFlowNodes(_flow),
      );

      expect(_occurrences(html, '<form '), 1);
      expect(_occurrences(html, 'data-esen-action-flow-step="'), 3);
      expect(html, contains('action="/_esen_seo/forms/project-enquiry"'));
      expect(html, contains('<select id="esen-action-flow-project-enquiry'));
      expect(html, contains('<option value="website">Website</option>'));
      expect(html, contains('data-esen-action-flow-navigation hidden'));
      expect(html, contains('data-esen-action-form-submit'));
      expect(
        RegExp(r'data-esen-action-flow-step="[^"]+"[^>]* hidden')
            .hasMatch(html),
        isFalse,
      );
      expect(html, isNot(contains('<script')));
    });

    test('action flow assets are isolated behind their own route opt-in', () {
      expect(seoDomFirstFeatureScriptHtml(const {}), isEmpty);
      expect(
        seoDomFirstFeatureScriptHtml(const {SeoDomFirstFeature.actionFlow}),
        contains('data-esen-seo-dom-first-runtime'),
      );
      expect(
        seoDomFirstFeatureStyleHtml(const {SeoDomFirstFeature.actionFlow}),
        contains('[data-esen-component="action-flow"]'),
      );
      expect(
        seoDomFirstFeatureBootstrapScriptHtml(
          const {SeoDomFirstFeature.actionFlow},
        ),
        contains('esenInteractionPending'),
      );
      expect(
        seoDomFirstFeatureScriptHtml(const {SeoDomFirstFeature.actionForm}),
        isNot(contains('data-esen-action-flow-step')),
      );
    });

    test('the existing middleware validates the same flat flow form', () async {
      SeoActionFormValues? received;
      final handler = seoActionFormMiddleware(
        publicOrigin: 'https://example.com',
        registrations: [
          SeoActionFormRegistration(
            definition: _flow.form,
            handler: (values) {
              received = values;
              return const SeoActionFormResult.success('Received.');
            },
          ),
        ],
      )((request) => Response.notFound('fallback'));

      final accepted = await handler(_request(
        'name=Ada&service=shop&email=ada%40example.com&consent=accepted',
      ));
      final forged = await handler(_request(
        'name=Ada&service=other&email=ada%40example.com&consent=accepted',
      ));

      expect(accepted.statusCode, 200);
      expect(received!.choice('service'), 'shop');
      expect(forged.statusCode, 400);
      expect(
        jsonDecode(await forged.readAsString()),
        containsPair('message', isNotEmpty),
      );
    });
  });
}

Request _request(String body) => Request(
      'POST',
      Uri.parse('https://example.com/_esen_seo/forms/project-enquiry'),
      headers: const {
        'content-type': 'application/x-www-form-urlencoded; charset=UTF-8',
        'accept': 'application/json',
        'origin': 'https://example.com',
      },
      body: body,
    );

int _occurrences(String source, String pattern) =>
    pattern.allMatches(source).length;

SeoActionFlowDefinition _withSteps(List<SeoActionFlowStep> steps) =>
    SeoActionFlowDefinition(
      form: _flow.form,
      steps: steps,
      previousLabel: 'Previous',
      nextLabel: 'Next',
      progressLabel: 'Project enquiry progress',
    );

SeoActionFlowDefinition _withOptions(List<SeoActionFormOption> options) =>
    SeoActionFlowDefinition(
      form: SeoActionFormDefinition(
        actionId: _flow.form.actionId,
        returnPath: _flow.form.returnPath,
        heading: _flow.form.heading,
        description: _flow.form.description,
        submitLabel: _flow.form.submitLabel,
        pendingLabel: _flow.form.pendingLabel,
        failureLabel: _flow.form.failureLabel,
        statusLabel: _flow.form.statusLabel,
        fields: [
          _flow.form.fields[0],
          SeoActionFormField(
            name: 'service',
            label: 'Service',
            kind: SeoActionFormFieldKind.choice,
            required: true,
            choicePrompt: 'Choose a service',
            options: options,
          ),
          _flow.form.fields[2],
          _flow.form.fields[3],
        ],
      ),
      steps: _flow.steps,
      previousLabel: _flow.previousLabel,
      nextLabel: _flow.nextLabel,
      progressLabel: _flow.progressLabel,
    );

const _flow = SeoActionFlowDefinition(
  form: SeoActionFormDefinition(
    actionId: 'project-enquiry',
    returnPath: '/contact/',
    heading: 'Start a project',
    description: 'Tell us what you need.',
    submitLabel: 'Send enquiry',
    pendingLabel: 'Sending enquiry',
    failureLabel: 'Please try again later',
    statusLabel: 'Enquiry status',
    fields: [
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
        label: 'I consent',
        kind: SeoActionFormFieldKind.consent,
        required: true,
      ),
    ],
  ),
  steps: [
    SeoActionFlowStep(
      label: 'About you',
      description: 'Your contact name.',
      fieldNames: ['name'],
    ),
    SeoActionFlowStep(
      label: 'Project',
      description: 'The service you need.',
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
  progressLabel: 'Project enquiry progress',
);
