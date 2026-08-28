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

    test('projects only branches selected by an earlier unconditional choice',
        () {
      final plan = prepareSeoActionFlow(_branchedFlow)!;

      expect(
        activeSeoActionFlowStepIndexes(plan, const {'service': 'website'}),
        [0, 1, 3],
      );
      expect(
        activeSeoActionFlowStepIndexes(plan, const {'service': 'shop'}),
        [0, 2, 3],
      );
      expect(
        activeSeoActionFlowStepIndexes(plan, const {'service': ''}),
        [0, 3],
      );
    });

    test('rejects later, conditional and undeclared branch controllers', () {
      final cases = <SeoActionFlowDefinition>[
        _branchedWithCondition(
          1,
          const SeoActionFlowCondition.choiceEquals(
            fieldName: 'email',
            value: 'website',
          ),
        ),
        _branchedWithCondition(
          2,
          const SeoActionFlowCondition.choiceEquals(
            fieldName: 'website_goal',
            value: 'shop',
          ),
        ),
        _branchedWithCondition(
          1,
          const SeoActionFlowCondition.choiceEquals(
            fieldName: 'missing',
            value: 'website',
          ),
        ),
        _branchedWithCondition(
          1,
          const SeoActionFlowCondition.choiceEquals(
            fieldName: 'service',
            value: 'forged',
          ),
        ),
      ];

      for (final definition in cases) {
        expect(prepareSeoActionFlow(definition), isNull);
      }
    });

    test('validates active fields but drops inactive values from the handler',
        () {
      final plan = prepareSeoActionFlow(_branchedFlow)!;
      final raw = <String, String>{
        'name': 'Ada',
        'service': 'website',
        'website_goal': 'A fast product site',
        'shop_catalog': 'This inactive value must not cross the boundary',
        'email': 'ada@example.com',
        'consent': 'accepted',
      };

      final valid = validateSeoActionFlowValues(plan, raw);
      final missingActive = validateSeoActionFlowValues(plan, {
        ...raw,
        'website_goal': '',
      });
      final missingInactive = validateSeoActionFlowValues(plan, {
        ...raw,
        'shop_catalog': '',
      });

      expect(valid.isValid, isTrue);
      expect(valid.values!.contains('website_goal'), isTrue);
      expect(valid.values!.contains('shop_catalog'), isFalse);
      expect(missingActive.errors, contains('website_goal'));
      expect(missingInactive.isValid, isTrue);
    });

    test('still rejects malformed content supplied for an inactive field', () {
      final plan = prepareSeoActionFlow(_branchedFlow)!;
      final validation = validateSeoActionFlowValues(plan, const {
        'name': 'Ada',
        'service': 'website',
        'website_goal': 'A fast product site',
        'shop_catalog': 'hidden\u202evalue',
        'email': 'ada@example.com',
        'consent': 'accepted',
      });

      expect(validation.malformed, isTrue);
      expect(validation.values, isNull);
    });

    test('builds review entries only from canonical active values', () {
      final plan = prepareSeoActionFlow(_branchedFlow)!;
      final validation = validateSeoActionFlowValues(plan, const {
        'name': '  Ada  ',
        'service': 'website',
        'website_goal': '  A fast product site  ',
        'shop_catalog': 'Inactive',
        'email': 'ada@example.com',
        'consent': 'accepted',
      });

      final entries = buildSeoActionFlowReviewEntries(
        plan,
        validation.values!,
      );

      expect(entries.map((entry) => entry.fieldName), [
        'name',
        'service',
        'website_goal',
        'email',
        'consent',
      ]);
      expect(entries.first.value, 'Ada');
      expect(entries[1].value, 'Website');
      expect(entries.last.value, 'Confirmed');
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

    test('conditional No-JS rendering stays complete and review starts empty',
        () {
      final html = const HtmlRenderer.domFirst().render(
        buildSeoActionFlowNodes(_branchedFlow),
      );

      expect(html, contains('data-esen-action-flow-when-field="service"'));
      expect(html, contains('data-esen-action-flow-when-value="website"'));
      expect(html, contains('data-esen-action-flow-when-value="shop"'));
      expect(html, contains('name="website_goal"'));
      expect(html, contains('name="shop_catalog"'));
      expect(
        html,
        contains('data-esen-action-flow-required="true"'),
      );
      expect(
        RegExp(r'name="website_goal"[^>]* required').hasMatch(html),
        isFalse,
      );
      expect(html, contains('data-esen-action-flow-review hidden'));
      expect(html, contains('data-esen-action-flow-review-value="0"></dd>'));
      expect(html, isNot(contains('A fast product site')));
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
        seoDomFirstFeatureStyleHtml(const {SeoDomFirstFeature.actionFlow}),
        contains(
          '.esen-seo-action-flow-review dl>div[hidden]{display:none}',
        ),
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

    test('flow registration exposes only active values to its handler',
        () async {
      SeoActionFormValues? received;
      final handler = seoActionFormMiddleware(
        publicOrigin: 'https://example.com',
        registrations: [
          SeoActionFormRegistration.flow(
            definition: _branchedFlow,
            handler: (values) {
              received = values;
              return const SeoActionFormResult.success('Received.');
            },
          ),
        ],
      )((request) => Response.notFound('fallback'));

      final response = await handler(_branchedRequest(
        'name=Ada&service=website&website_goal=Fast&shop_catalog=Secret&'
        'email=ada%40example.com&consent=accepted',
      ));

      expect(response.statusCode, 200);
      expect(received!.text('website_goal'), 'Fast');
      expect(received!.contains('shop_catalog'), isFalse);
    });

    test('flow registration rejects handler errors for inactive fields',
        () async {
      final handler = seoActionFormMiddleware(
        publicOrigin: 'https://example.com',
        registrations: [
          SeoActionFormRegistration.flow(
            definition: _branchedFlow,
            handler: (_) => const SeoActionFormResult.rejected(
              'Invalid result.',
              fieldErrors: {'shop_catalog': 'Must not be addressed.'},
            ),
          ),
        ],
      )((request) => Response.notFound('fallback'));

      final response = await handler(_branchedRequest(
        'name=Ada&service=website&website_goal=Fast&shop_catalog=&'
        'email=ada%40example.com&consent=accepted',
      ));

      expect(response.statusCode, 500);
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

Request _branchedRequest(String body) => Request(
      'POST',
      Uri.parse('https://example.com/_esen_seo/forms/branched-enquiry'),
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

SeoActionFlowDefinition _branchedWithCondition(
  int stepIndex,
  SeoActionFlowCondition condition,
) {
  final steps = [..._branchedFlow.steps];
  final step = steps[stepIndex];
  steps[stepIndex] = SeoActionFlowStep(
    label: step.label,
    description: step.description,
    fieldNames: step.fieldNames,
    condition: condition,
  );
  return SeoActionFlowDefinition(
    form: _branchedFlow.form,
    steps: steps,
    previousLabel: _branchedFlow.previousLabel,
    nextLabel: _branchedFlow.nextLabel,
    progressLabel: _branchedFlow.progressLabel,
    review: _branchedFlow.review,
  );
}

const _branchedFlow = SeoActionFlowDefinition(
  form: SeoActionFormDefinition(
    actionId: 'branched-enquiry',
    returnPath: '/contact/',
    heading: 'Plan a project',
    description: 'Follow the relevant project branch.',
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
        label: 'I consent',
        kind: SeoActionFormFieldKind.consent,
        required: true,
      ),
    ],
  ),
  steps: [
    SeoActionFlowStep(
      label: 'Project',
      description: 'Choose the project type.',
      fieldNames: ['name', 'service'],
    ),
    SeoActionFlowStep(
      label: 'Website',
      description: 'Describe the website.',
      fieldNames: ['website_goal'],
      condition: SeoActionFlowCondition.choiceEquals(
        fieldName: 'service',
        value: 'website',
      ),
    ),
    SeoActionFlowStep(
      label: 'Shop',
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
  progressLabel: 'Project enquiry progress',
  review: SeoActionFlowReview(
    label: 'Review',
    description: 'Check the active project details.',
    emptyValueLabel: 'Not provided',
    consentAcceptedLabel: 'Confirmed',
    consentDeclinedLabel: 'Not confirmed',
  ),
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
