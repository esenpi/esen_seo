import 'dart:async';

import 'package:esen_seo/form_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('validates each native step before advancing', (tester) async {
    var calls = 0;
    await tester.pumpWidget(_app(onSubmit: (_) {
      calls++;
      return const SeoActionFormResult.success('Sent.');
    }));

    expect(find.text('About you'), findsOneWidget);
    expect(find.text('1 / 3'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await tester.pump();
    expect(find.text('This field is required.'), findsOneWidget);
    expect(find.text('About you'), findsOneWidget);
    expect(calls, 0);

    await tester.enterText(find.byType(TextFormField), 'Ada');
    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await tester.pump();
    expect(find.text('Project'), findsOneWidget);
    expect(find.text('2 / 3'), findsOneWidget);
  });

  testWidgets('submits all typed values only from the final step',
      (tester) async {
    final completer = Completer<SeoActionFormResult>();
    var calls = 0;
    await tester.pumpWidget(_app(onSubmit: (values) {
      calls++;
      expect(values.text('name'), 'Ada');
      expect(values.choice('service'), 'website');
      expect(values.text('email'), 'ada@example.com');
      expect(values.consent('consent'), isTrue);
      return completer.future;
    }));

    await _reachFinalStep(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Send enquiry'));
    await tester.pump();

    expect(calls, 1);
    expect(
        find.widgetWithText(FilledButton, 'Sending enquiry'), findsOneWidget);
    completer.complete(const SeoActionFormResult.success('Enquiry sent.'));
    await tester.pump();
    expect(find.text('Enquiry sent.'), findsOneWidget);
    expect(find.text('1 / 3'), findsOneWidget);
  });

  testWidgets('reveals the owning step for a bounded server field error',
      (tester) async {
    await tester.pumpWidget(_app(
      onSubmit: (_) => const SeoActionFormResult.rejected(
        'Please choose another service.',
        fieldErrors: {'service': 'This service is unavailable.'},
      ),
    ));
    await _reachFinalStep(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Send enquiry'));
    await tester.pump();

    expect(find.text('2 / 3'), findsOneWidget);
    expect(find.text('Project'), findsOneWidget);
    expect(find.text('This service is unavailable.'), findsOneWidget);
  });

  testWidgets('blocks duplicate submits while the callback is pending',
      (tester) async {
    final completer = Completer<SeoActionFormResult>();
    var calls = 0;
    await tester.pumpWidget(_app(onSubmit: (_) {
      calls++;
      return completer.future;
    }));
    await _reachFinalStep(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Send enquiry'));
    await tester.tap(find.widgetWithText(FilledButton, 'Send enquiry'));
    await tester.pump();

    expect(calls, 1);
    completer.complete(const SeoActionFormResult.success('Sent.'));
    await tester.pump();
  });

  testWidgets('contains callback failures without leaking details',
      (tester) async {
    await tester.pumpWidget(_app(
      onSubmit: (_) => throw StateError('private detail'),
    ));
    await _reachFinalStep(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Send enquiry'));
    await tester.pump();

    expect(find.text('The submission could not be completed.'), findsOneWidget);
    expect(find.textContaining('private detail'), findsNothing);
  });

  testWidgets('recomputes later steps when an earlier choice branch changes',
      (tester) async {
    await tester.pumpWidget(_branchedApp(
        onSubmit: (_) => const SeoActionFormResult.success('Sent.')));

    await tester.enterText(find.byType(TextFormField), 'Ada');
    await _selectChoice(tester, 'Website');
    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await tester.pump();
    expect(find.text('Website details'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Previous'));
    await tester.pump();
    await _selectChoice(tester, 'Online shop');
    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await tester.pump();

    expect(find.text('Shop details'), findsOneWidget);
    expect(find.text('Website details'), findsNothing);
  });

  testWidgets(
      'reviews and submits only canonical values from the active branch',
      (tester) async {
    SeoActionFormValues? received;
    await tester.pumpWidget(_branchedApp(onSubmit: (values) {
      received = values;
      return const SeoActionFormResult.success('Sent.');
    }));

    await tester.enterText(find.byType(TextFormField), '  Ada  ');
    await _selectChoice(tester, 'Website');
    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await tester.pump();
    await tester.enterText(find.byType(TextFormField), 'Fast product site');
    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await tester.pump();
    await tester.enterText(find.byType(TextFormField), 'ada@example.com');
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await tester.pump();

    expect(find.text('Review enquiry'), findsOneWidget);
    expect(find.text('4 / 4'), findsOneWidget);
    expect(find.text('Ada'), findsOneWidget);
    expect(find.text('Fast product site'), findsOneWidget);
    expect(find.text('Confirmed'), findsOneWidget);
    expect(find.text('Catalog size'), findsNothing);

    await tester.tap(find.widgetWithText(FilledButton, 'Send enquiry'));
    await tester.pump();
    expect(received, isNotNull);
    expect(received!.text('name'), 'Ada');
    expect(received!.contains('website_goal'), isTrue);
    expect(received!.contains('shop_catalog'), isFalse);
  });
}

Future<void> _reachFinalStep(WidgetTester tester) async {
  await tester.enterText(find.byType(TextFormField), 'Ada');
  await tester.tap(find.widgetWithText(FilledButton, 'Next'));
  await tester.pump();
  await tester.tap(find.byType(DropdownButton<String>));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Website').last);
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FilledButton, 'Next'));
  await tester.pump();
  await tester.enterText(find.byType(TextFormField), 'ada@example.com');
  await tester.tap(find.byType(CheckboxListTile));
  await tester.pump();
}

Future<void> _selectChoice(WidgetTester tester, String label) async {
  await tester.tap(find.byType(DropdownButton<String>));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Widget _app({required SeoActionFormSubmit onSubmit}) => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: SeoActionFlow(definition: _flow, onSubmit: onSubmit),
        ),
      ),
    );

Widget _branchedApp({required SeoActionFormSubmit onSubmit}) => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: SeoActionFlow(definition: _branchedFlow, onSubmit: onSubmit),
        ),
      ),
    );

const _branchedFlow = SeoActionFlowDefinition(
  form: SeoActionFormDefinition(
    actionId: 'branched-enquiry',
    returnPath: '/contact/',
    heading: 'Plan a project',
    description: 'Follow the relevant branch.',
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
  review: SeoActionFlowReview(
    label: 'Review enquiry',
    description: 'Check the active values.',
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
