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

Widget _app({required SeoActionFormSubmit onSubmit}) => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: SeoActionFlow(definition: _flow, onSubmit: onSubmit),
        ),
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
