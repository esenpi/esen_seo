import 'dart:convert';

import 'package:esen_seo/server.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shelf/shelf.dart';

void main() {
  late int calls;
  late SeoActionFormValues? received;
  late Handler handler;

  setUp(() {
    calls = 0;
    received = null;
    handler = seoActionFormMiddleware(
      publicOrigin: 'https://example.com/site/',
      registrations: [
        SeoActionFormRegistration(
          definition: _definition,
          handler: (values) {
            calls++;
            received = values;
            return const SeoActionFormResult.success('Message sent.');
          },
        ),
      ],
    )((request) => Response.ok('fallback'));
  });

  test('passes unrelated paths through unchanged', () async {
    final response =
        await handler(Request('GET', Uri.parse('https://x.test/')));

    expect(response.statusCode, 200);
    expect(await response.readAsString(), 'fallback');
  });

  test('delivers only validated values to the handler', () async {
    final response = await handler(_request(
      body: 'name=Ada+Lovelace&email=ada%40example.com&consent=accepted',
      accept: 'application/json',
    ));

    expect(response.statusCode, 200);
    expect(calls, 1);
    expect(received!.text('name'), 'Ada Lovelace');
    expect(received!.text('email'), 'ada@example.com');
    expect(received!.consent('consent'), isTrue);
    expect(
      jsonDecode(await response.readAsString()),
      {
        'schema': 1,
        'ok': true,
        'message': 'Message sent.',
        'fieldErrors': <String, Object?>{},
      },
    );
    expect(response.headers['cache-control'], 'no-store');
  });

  test('keeps native no-JavaScript submission usable and non-indexable',
      () async {
    final response = await handler(_request(
      body: 'name=Ada&email=ada%40example.com&consent=accepted',
      accept: 'text/html',
    ));
    final body = await response.readAsString();

    expect(response.statusCode, 200);
    expect(response.headers['x-robots-tag'], 'noindex, nofollow');
    expect(body, contains('<meta name="robots" content="noindex,nofollow"/>'));
    expect(body, contains('Message sent.'));
    expect(body, contains('<a href="/contact/">'));
    expect(body, isNot(contains('<script')));
  });

  test('rejects missing, foreign and path-bearing origins before parsing',
      () async {
    for (final origin in <String?>[
      null,
      'https://evil.test',
      'https://example.com/forged',
      'null',
    ]) {
      final response = await handler(_request(
        body: 'name=Ada',
        origin: origin,
        accept: 'application/json',
      ));
      expect(response.statusCode, 403, reason: '$origin');
    }
    expect(calls, 0);
  });

  test('rejects unsupported content types and methods', () async {
    final unsupported = await handler(_request(
      body: '{}',
      contentType: 'application/json',
    ));
    final method = await handler(Request(
      'GET',
      Uri.parse('https://example.com/_esen_seo/forms/contact'),
    ));

    expect(unsupported.statusCode, 415);
    expect(method.statusCode, 405);
    expect(method.headers['allow'], 'POST');
    expect(calls, 0);
  });

  test('rejects encoded bodies and ambiguous content-type parameters',
      () async {
    final encoded = await handler(_request(
      body: 'name=Ada',
      extraHeaders: const {'content-encoding': 'gzip'},
    ));
    final duplicateCharset = await handler(_request(
      body: 'name=Ada',
      contentType:
          'application/x-www-form-urlencoded; charset=utf-8; charset=utf-8',
    ));

    expect(encoded.statusCode, 415);
    expect(duplicateCharset.statusCode, 415);
    expect(calls, 0);
  });

  test('rejects duplicate, unknown and malformed encoded fields', () async {
    for (final body in [
      'name=Ada&name=Grace',
      'name=Ada&unknown=value',
      'name=%ZZ',
      'name',
      'name=Ada&&email=a%40b.test',
    ]) {
      final response = await handler(_request(
        body: body,
        accept: 'application/json',
      ));
      expect(response.statusCode, 400, reason: body);
    }
    expect(calls, 0);
  });

  test('rejects invalid UTF-8 and bodies over the configured limit', () async {
    final strict = seoActionFormMiddleware(
      publicOrigin: 'https://example.com',
      maxBodyBytes: 1024,
      registrations: [
        SeoActionFormRegistration(
          definition: _definition,
          handler: (_) => const SeoActionFormResult.success('No.'),
        ),
      ],
    )((request) => Response.ok('fallback'));
    final invalidUtf8 = await strict(_request(body: [0xff, 0xfe]));
    final tooLarge = await strict(_request(body: 'name=${'a' * 1100}'));

    expect(invalidUtf8.statusCode, 400);
    expect(tooLarge.statusCode, 413);
  });

  test('returns field validation errors without calling the handler', () async {
    final response = await handler(_request(
      body: 'name=&email=wrong',
      accept: 'application/json',
    ));
    final body = jsonDecode(await response.readAsString()) as Map;

    expect(response.statusCode, 422);
    expect(body['fieldErrors'], contains('name'));
    expect(body['fieldErrors'], contains('email'));
    expect(body['fieldErrors'], contains('consent'));
    expect(calls, 0);
  });

  test('contains handler failures and malformed handler results', () async {
    final errors = <Object>[];
    Handler throwing(SeoActionFormHandler callback) => seoActionFormMiddleware(
          publicOrigin: 'https://example.com',
          onError: (error, _) => errors.add(error),
          registrations: [
            SeoActionFormRegistration(
              definition: _definition,
              handler: callback,
            ),
          ],
        )((request) => Response.ok('fallback'));

    final thrown = await throwing((_) => throw StateError('private'))(
      _request(body: 'name=Ada&email=a%40b.test&consent=accepted'),
    );
    final malformed = await throwing(
      (_) => const SeoActionFormResult(
        outcome: SeoActionFormOutcome.success,
        message: 'Sent.',
        fieldErrors: {'email': 'Impossible'},
      ),
    )(_request(body: 'name=Ada&email=a%40b.test&consent=accepted'));

    expect(thrown.statusCode, 500);
    expect(malformed.statusCode, 500);
    expect(await thrown.readAsString(), isNot(contains('private')));
    expect(errors, hasLength(2));
  });

  test('refuses duplicate registrations and invalid setup', () {
    final registration = SeoActionFormRegistration(
      definition: _definition,
      handler: (_) => const SeoActionFormResult.success('Sent.'),
    );

    expect(
      () => seoActionFormMiddleware(
        publicOrigin: 'javascript:alert(1)',
        registrations: [registration],
      ),
      throwsArgumentError,
    );
    expect(
      () => seoActionFormMiddleware(
        publicOrigin: 'https://example.com',
        registrations: [registration, registration],
      ),
      throwsArgumentError,
    );
  });
}

Request _request({
  Object body = '',
  String? origin = 'https://example.com',
  String contentType = 'application/x-www-form-urlencoded; charset=UTF-8',
  String accept = 'text/html',
  Map<String, String> extraHeaders = const {},
}) {
  final headers = <String, String>{
    'content-type': contentType,
    'accept': accept,
    if (origin != null) 'origin': origin,
    ...extraHeaders,
  };
  return Request(
    'POST',
    Uri.parse('https://example.com/_esen_seo/forms/contact'),
    headers: headers,
    body: body,
  );
}

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
