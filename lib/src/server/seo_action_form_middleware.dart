import 'dart:async';
import 'dart:convert';

import 'package:shelf/shelf.dart';

import '../components/seo_action_form.dart';
import '../renderer/html_renderer.dart';
import '../renderer/seo_action_form_markup.dart';

typedef SeoActionFormHandler = FutureOr<SeoActionFormResult> Function(
  SeoActionFormValues values,
);

typedef SeoActionFormErrorHandler = void Function(
  Object error,
  StackTrace stackTrace,
);

final class SeoActionFormServerMessages {
  const SeoActionFormServerMessages({
    this.invalidSubmission = 'Please correct the highlighted fields.',
    this.malformedRequest = 'The submission could not be read.',
    this.forbiddenRequest = 'This submission was not accepted.',
    this.internalError = 'The submission could not be completed.',
    this.resultTitle = 'Form submission',
    this.returnLabel = 'Return to the form',
  });

  final String invalidSubmission;
  final String malformedRequest;
  final String forbiddenRequest;
  final String internalError;
  final String resultTitle;
  final String returnLabel;
}

final class SeoActionFormRegistration {
  SeoActionFormRegistration({
    required SeoActionFormDefinition definition,
    required this.handler,
    this.messages = const SeoActionFormServerMessages(),
    this.lang = 'en',
  })  : plan = _requirePlan(definition),
        _preparedMessages = _requireMessages(messages) {
    if (!_languageTag.hasMatch(lang)) {
      throw ArgumentError.value(lang, 'lang', 'must be a simple language tag');
    }
  }

  final SeoActionFormPlan plan;
  final SeoActionFormHandler handler;
  final SeoActionFormServerMessages messages;
  final String lang;
  final SeoActionFormServerMessages _preparedMessages;
}

/// Handles the package-owned POST endpoint for registered action forms.
///
/// Place this middleware before [seoBotMiddleware]. Requests outside the fixed
/// action-form namespace are passed through unchanged. The application handler
/// receives only bounded, decoded and schema-validated values.
Middleware seoActionFormMiddleware({
  required String publicOrigin,
  required List<SeoActionFormRegistration> registrations,
  int maxBodyBytes = 32768,
  SeoActionFormErrorHandler? onError,
}) {
  final expectedOrigin = _canonicalOrigin(publicOrigin, siteUrl: true);
  if (expectedOrigin == null) {
    throw ArgumentError.value(
      publicOrigin,
      'publicOrigin',
      'must be an absolute HTTP(S) origin or site URL',
    );
  }
  if (maxBodyBytes < 1024 || maxBodyBytes > 1024 * 1024) {
    throw RangeError.range(maxBodyBytes, 1024, 1024 * 1024, 'maxBodyBytes');
  }
  final byPath = <String, SeoActionFormRegistration>{};
  for (final registration in registrations) {
    if (byPath.containsKey(registration.plan.endpointPath)) {
      throw ArgumentError.value(
        registration.plan.actionId,
        'registrations',
        'contains a duplicate action id',
      );
    }
    byPath[registration.plan.endpointPath] = registration;
  }
  final frozen = Map<String, SeoActionFormRegistration>.unmodifiable(byPath);

  return (innerHandler) {
    return (request) async {
      final path = '/${request.url.path}';
      if (!path.startsWith(internalSeoActionFormEndpointPrefix)) {
        return innerHandler(request);
      }
      final registration = frozen[path];
      if (registration == null) {
        return _plainResponse(404, 'Not found.');
      }
      if (request.method != 'POST') {
        return _plainResponse(405, 'Method not allowed.', extraHeaders: {
          'allow': 'POST',
        });
      }
      if (_canonicalOrigin(request.headers['origin']) != expectedOrigin) {
        return _resultResponse(
          request,
          registration,
          403,
          registration._preparedMessages.forbiddenRequest,
        );
      }
      if (!_validFormContentType(request.headers['content-type'])) {
        return _resultResponse(
          request,
          registration,
          415,
          registration._preparedMessages.malformedRequest,
        );
      }
      final contentEncoding = request.headers['content-encoding'];
      if (contentEncoding != null &&
          contentEncoding.trim().toLowerCase() != 'identity') {
        return _resultResponse(
          request,
          registration,
          415,
          registration._preparedMessages.malformedRequest,
        );
      }
      final declared = request.headers['content-length'];
      final declaredLength = declared == null ? null : int.tryParse(declared);
      if (declared != null && (declaredLength == null || declaredLength < 0)) {
        return _resultResponse(
          request,
          registration,
          400,
          registration._preparedMessages.malformedRequest,
        );
      }
      if (declaredLength != null && declaredLength > maxBodyBytes) {
        return _resultResponse(
          request,
          registration,
          413,
          registration._preparedMessages.malformedRequest,
        );
      }

      Map<String, String>? rawValues;
      try {
        final bytes = <int>[];
        await for (final chunk in request.read()) {
          if (bytes.length + chunk.length > maxBodyBytes) {
            return _resultResponse(
              request,
              registration,
              413,
              registration._preparedMessages.malformedRequest,
            );
          }
          bytes.addAll(chunk);
        }
        rawValues = _decodeForm(bytes);
      } on FormatException {
        rawValues = null;
      } on ArgumentError {
        rawValues = null;
      }
      if (rawValues == null) {
        return _resultResponse(
          request,
          registration,
          400,
          registration._preparedMessages.malformedRequest,
        );
      }

      final validation = validateSeoActionFormValues(
        registration.plan,
        rawValues,
      );
      if (validation.malformed) {
        return _resultResponse(
          request,
          registration,
          400,
          registration._preparedMessages.malformedRequest,
        );
      }
      if (!validation.isValid) {
        return _resultResponse(
          request,
          registration,
          422,
          registration._preparedMessages.invalidSubmission,
          fieldErrors: validation.errors,
        );
      }

      try {
        final rawResult = await registration.handler(validation.values!);
        final result = canonicalizeSeoActionFormResult(
          registration.plan,
          rawResult,
        );
        if (result == null) {
          throw const FormatException('Invalid action-form handler result');
        }
        return _resultResponse(
          request,
          registration,
          result.outcome == SeoActionFormOutcome.success ? 200 : 422,
          result.message,
          fieldErrors: result.fieldErrors,
          success: result.outcome == SeoActionFormOutcome.success,
        );
      } catch (error, stackTrace) {
        try {
          onError?.call(error, stackTrace);
        } catch (_) {
          // Diagnostics must not turn a contained application failure into an
          // unhandled request failure.
        }
        return _resultResponse(
          request,
          registration,
          500,
          registration._preparedMessages.internalError,
        );
      }
    };
  };
}

Map<String, String>? _decodeForm(List<int> bytes) {
  final encoded = utf8.decode(bytes, allowMalformed: false);
  if (encoded.isEmpty) return <String, String>{};
  final result = <String, String>{};
  for (final pair in encoded.split('&')) {
    if (pair.isEmpty) return null;
    final separator = pair.indexOf('=');
    if (separator < 0) return null;
    final name = Uri.decodeQueryComponent(pair.substring(0, separator));
    final value = Uri.decodeQueryComponent(pair.substring(separator + 1));
    if (name.isEmpty || result.containsKey(name)) return null;
    result[name] = value;
  }
  return result;
}

Response _resultResponse(
  Request request,
  SeoActionFormRegistration registration,
  int status,
  String message, {
  Map<String, String> fieldErrors = const {},
  bool success = false,
}) {
  if (_acceptsJson(request.headers['accept'])) {
    return Response(
      status,
      body: jsonEncode({
        'schema': 1,
        'ok': success,
        'message': message,
        'fieldErrors': fieldErrors,
      }),
      headers: _responseHeaders('application/json; charset=utf-8'),
    );
  }
  final title = registration._preparedMessages.resultTitle;
  final errors = fieldErrors.isEmpty
      ? ''
      : '<ul>${fieldErrors.values.map((error) => '<li>${HtmlRenderer.escapeText(error)}</li>').join()}</ul>';
  final html = '<!DOCTYPE html><html lang="${registration.lang}"><head>'
      '<meta charset="utf-8"/><meta name="viewport" '
      'content="width=device-width, initial-scale=1"/>'
      '<meta name="robots" content="noindex,nofollow"/>'
      '<title>${HtmlRenderer.escapeText(title)}</title></head><body><main>'
      '<h1>${HtmlRenderer.escapeText(title)}</h1>'
      '<p>${HtmlRenderer.escapeText(message)}</p>$errors'
      '<p><a href="${HtmlRenderer.escapeAttribute(registration.plan.returnPath)}">'
      '${HtmlRenderer.escapeText(registration._preparedMessages.returnLabel)}'
      '</a></p></main></body></html>';
  return Response(
    status,
    body: html,
    headers: {
      ..._responseHeaders('text/html; charset=utf-8'),
      'content-security-policy':
          "default-src 'none'; base-uri 'none'; form-action 'self'; frame-ancestors 'none'",
      'x-frame-options': 'DENY',
      'x-robots-tag': 'noindex, nofollow',
    },
  );
}

Response _plainResponse(
  int status,
  String body, {
  Map<String, String> extraHeaders = const {},
}) =>
    Response(
      status,
      body: body,
      headers: {
        ..._responseHeaders('text/plain; charset=utf-8'),
        ...extraHeaders,
      },
    );

Map<String, String> _responseHeaders(String contentType) => {
      'content-type': contentType,
      'cache-control': 'no-store',
      'x-content-type-options': 'nosniff',
      'referrer-policy': 'no-referrer',
    };

bool _acceptsJson(String? accept) =>
    accept
        ?.split(',')
        .map((value) => value.split(';').first.trim().toLowerCase())
        .contains('application/json') ??
    false;

bool _validFormContentType(String? raw) {
  if (raw == null) return false;
  final parts = raw.split(';');
  if (parts.first.trim().toLowerCase() != 'application/x-www-form-urlencoded') {
    return false;
  }
  var sawCharset = false;
  for (final parameter in parts.skip(1)) {
    final separator = parameter.indexOf('=');
    if (separator < 1) return false;
    final name = parameter.substring(0, separator).trim().toLowerCase();
    var value = parameter.substring(separator + 1).trim().toLowerCase();
    if (value.length >= 2 && value.startsWith('"') && value.endsWith('"')) {
      value = value.substring(1, value.length - 1);
    }
    if (name != 'charset' || sawCharset || value != 'utf-8') {
      return false;
    }
    sawCharset = true;
  }
  return true;
}

String? _canonicalOrigin(String? raw, {bool siteUrl = false}) {
  if (raw == null || raw.length > 2048) return null;
  final uri = Uri.tryParse(raw.trim());
  if (uri == null ||
      !uri.hasAuthority ||
      (uri.scheme != 'http' && uri.scheme != 'https') ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment ||
      (!siteUrl && uri.path.isNotEmpty && uri.path != '/')) {
    return null;
  }
  final defaultPort = uri.scheme == 'http' ? 80 : 443;
  final port = uri.hasPort && uri.port != defaultPort ? ':${uri.port}' : '';
  return '${uri.scheme.toLowerCase()}://${uri.host.toLowerCase()}$port';
}

SeoActionFormPlan _requirePlan(SeoActionFormDefinition definition) {
  final plan = prepareSeoActionForm(definition);
  if (plan == null) {
    throw ArgumentError.value(definition, 'definition', 'is not valid');
  }
  return plan;
}

SeoActionFormServerMessages _requireMessages(
  SeoActionFormServerMessages messages,
) {
  String require(String value, String name) {
    final canonical = canonicalizeSeoActionFormText(
      value,
      maxLength: seoActionFormMaxResultTextLength,
    );
    if (canonical == null) {
      throw ArgumentError.value(value, name, 'is not valid display text');
    }
    return canonical;
  }

  return SeoActionFormServerMessages(
    invalidSubmission: require(messages.invalidSubmission, 'invalidSubmission'),
    malformedRequest: require(messages.malformedRequest, 'malformedRequest'),
    forbiddenRequest: require(messages.forbiddenRequest, 'forbiddenRequest'),
    internalError: require(messages.internalError, 'internalError'),
    resultTitle: require(messages.resultTitle, 'resultTitle'),
    returnLabel: require(messages.returnLabel, 'returnLabel'),
  );
}

final RegExp _languageTag = RegExp(r'^[A-Za-z]{2,8}(?:-[A-Za-z0-9]{1,8})*$');
