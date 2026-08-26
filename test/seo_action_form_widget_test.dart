import 'dart:async';

import 'package:esen_seo/form_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders native controls from the shared definition',
      (tester) async {
    await tester.pumpWidget(_app(
      onSubmit: (_) => const SeoActionFormResult.success('Sent.'),
    ));

    expect(find.text('Contact'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.byType(CheckboxListTile), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Send'), findsOneWidget);
  });

  testWidgets('blocks invalid native values before the callback',
      (tester) async {
    var calls = 0;
    await tester.pumpWidget(_app(onSubmit: (_) {
      calls++;
      return const SeoActionFormResult.success('Sent.');
    }));

    await tester.tap(find.widgetWithText(FilledButton, 'Send'));
    await tester.pump();

    expect(calls, 0);
    expect(find.text('This field is required.'), findsNWidgets(2));
    expect(find.text('Consent is required.'), findsOneWidget);
    expect(find.text('Please correct the highlighted fields.'), findsOneWidget);
  });

  testWidgets('submits once, exposes pending state and resets on success',
      (tester) async {
    final completer = Completer<SeoActionFormResult>();
    var calls = 0;
    await tester.pumpWidget(_app(onSubmit: (values) {
      calls++;
      expect(values.text('name'), 'Ada');
      expect(values.text('email'), 'ada@example.com');
      expect(values.consent('consent'), isTrue);
      return completer.future;
    }));
    await _fillValidForm(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Send'));
    await tester.pump();
    expect(find.widgetWithText(FilledButton, 'Sending'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Sending'));
    expect(calls, 1);

    completer.complete(const SeoActionFormResult.success('Message sent.'));
    await tester.pump();

    expect(find.text('Message sent.'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).first)
          .controller!
          .text,
      isEmpty,
    );
    expect(
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
      isFalse,
    );
  });

  testWidgets('keeps values and applies bounded handler field errors',
      (tester) async {
    await tester.pumpWidget(_app(
      onSubmit: (_) => const SeoActionFormResult.rejected(
        'Please check the email.',
        fieldErrors: {'email': 'This address is already registered.'},
      ),
    ));
    await _fillValidForm(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Send'));
    await tester.pump();

    expect(find.text('Please check the email.'), findsOneWidget);
    expect(find.text('This address is already registered.'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).first)
          .controller!
          .text,
      'Ada',
    );
  });

  testWidgets('contains callback exceptions without leaking details',
      (tester) async {
    await tester.pumpWidget(_app(onSubmit: (_) => throw StateError('private')));
    await _fillValidForm(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Send'));
    await tester.pump();

    expect(find.text('The submission could not be completed.'), findsOneWidget);
    expect(find.textContaining('private'), findsNothing);
  });

  testWidgets('submits a closed choice from the native single-step widget',
      (tester) async {
    String? selected;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SeoActionForm(
          definition: _choiceDefinition,
          onSubmit: (values) {
            selected = values.choice('service');
            return const SeoActionFormResult.success('Sent.');
          },
        ),
      ),
    ));

    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Website').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Send'));
    await tester.pump();

    expect(selected, 'website');
  });
}

Future<void> _fillValidForm(WidgetTester tester) async {
  await tester.enterText(find.byType(TextFormField).at(0), 'Ada');
  await tester.enterText(
    find.byType(TextFormField).at(1),
    'ada@example.com',
  );
  await tester.tap(find.byType(CheckboxListTile));
  await tester.pump();
}

Widget _app({required SeoActionFormSubmit onSubmit}) => MaterialApp(
      home: Scaffold(
        body: SeoActionForm(
          definition: _definition,
          onSubmit: onSubmit,
        ),
      ),
    );

const _definition = SeoActionFormDefinition(
  actionId: 'contact',
  returnPath: '/contact/',
  heading: 'Contact',
  description: 'Write to us.',
  submitLabel: 'Send',
  pendingLabel: 'Sending',
  failureLabel: 'Try again later',
  statusLabel: 'Submission status',
  fields: [
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

const _choiceDefinition = SeoActionFormDefinition(
  actionId: 'project',
  returnPath: '/project/',
  heading: 'Project',
  description: 'Choose a service.',
  submitLabel: 'Send',
  pendingLabel: 'Sending',
  failureLabel: 'Try again later',
  statusLabel: 'Submission status',
  fields: [
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
  ],
);
