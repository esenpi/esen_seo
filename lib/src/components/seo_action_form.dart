/// Pure action-form model, validation and semantic component builder.
library;

import '../renderer/seo_action_form_markup.dart';
import '../renderer/seo_node.dart';
import 'seo_component_format.dart';
import 'seo_configurator_transition.dart' show canonicalizeSeoConfiguratorText;

const int seoActionFormMaxFields = 8;
const int seoActionFormMaxFieldNameLength = 32;
const int seoActionFormMaxLabelLength = 120;
const int seoActionFormMaxDescriptionLength = 512;
const int seoActionFormMaxResultTextLength = 512;
const int seoActionFormMaxFieldErrorLength = 256;
const int seoActionFormMaxAggregateInputLength = 8192;
const int seoActionFormMaxAggregateResultLength = 2048;
const int seoActionFormMaxTextLength = 512;
const int seoActionFormMaxEmailLength = 254;
const int seoActionFormMaxMultilineLength = 4096;

final RegExp _fieldName = RegExp(r'^[a-z][a-z0-9_]{0,31}$');

enum SeoActionFormFieldKind { text, email, multiline, consent }

enum SeoActionFormAutocomplete {
  off('off'),
  name('name'),
  email('email'),
  organization('organization');

  const SeoActionFormAutocomplete(this.value);
  final String value;
}

final class SeoActionFormMessages {
  const SeoActionFormMessages({
    this.required = 'This field is required.',
    this.invalidEmail = 'Enter a valid email address.',
    this.tooShort = 'This value is too short.',
    this.tooLong = 'This value is too long.',
    this.consentRequired = 'Consent is required.',
  });

  final String required;
  final String invalidEmail;
  final String tooShort;
  final String tooLong;
  final String consentRequired;
}

final class SeoActionFormField {
  const SeoActionFormField({
    required this.name,
    required this.label,
    required this.kind,
    this.description,
    this.required = false,
    this.minLength = 0,
    this.maxLength,
    this.autocomplete = SeoActionFormAutocomplete.off,
  });

  final String name;
  final String label;
  final SeoActionFormFieldKind kind;
  final String? description;
  final bool required;
  final int minLength;
  final int? maxLength;
  final SeoActionFormAutocomplete autocomplete;
}

final class SeoActionFormPlanField {
  const SeoActionFormPlanField({
    required this.name,
    required this.label,
    required this.kind,
    required this.required,
    required this.minLength,
    required this.maxLength,
    required this.autocomplete,
    this.description,
  });

  final String name;
  final String label;
  final SeoActionFormFieldKind kind;
  final String? description;
  final bool required;
  final int minLength;
  final int maxLength;
  final SeoActionFormAutocomplete autocomplete;
}

final class SeoActionFormDefinition {
  const SeoActionFormDefinition({
    required this.actionId,
    required this.returnPath,
    required this.heading,
    required this.description,
    required this.submitLabel,
    required this.pendingLabel,
    required this.failureLabel,
    required this.statusLabel,
    required this.fields,
    this.headingLevel = 2,
    this.messages = const SeoActionFormMessages(),
  });

  final String actionId;
  final String returnPath;
  final String heading;
  final String description;
  final String submitLabel;
  final String pendingLabel;
  final String failureLabel;
  final String statusLabel;
  final List<SeoActionFormField> fields;
  final int headingLevel;
  final SeoActionFormMessages messages;
}

final class SeoActionFormPlan {
  const SeoActionFormPlan._({
    required this.actionId,
    required this.returnPath,
    required this.heading,
    required this.description,
    required this.submitLabel,
    required this.pendingLabel,
    required this.failureLabel,
    required this.statusLabel,
    required this.fields,
    required this.headingLevel,
    required this.messages,
  });

  final String actionId;
  final String returnPath;
  final String heading;
  final String description;
  final String submitLabel;
  final String pendingLabel;
  final String failureLabel;
  final String statusLabel;
  final List<SeoActionFormPlanField> fields;
  final int headingLevel;
  final SeoActionFormMessages messages;

  String get endpointPath => '$internalSeoActionFormEndpointPrefix$actionId';
}

final class SeoActionFormValues {
  SeoActionFormValues._(Map<String, Object> values)
      : values = Map.unmodifiable(values);

  final Map<String, Object> values;

  String text(String name) =>
      values[name] is String ? values[name]! as String : '';

  bool consent(String name) => values[name] == true;
}

final class SeoActionFormValidation {
  const SeoActionFormValidation._({
    required this.malformed,
    required this.errors,
    this.values,
  });

  final bool malformed;
  final Map<String, String> errors;
  final SeoActionFormValues? values;

  bool get isValid => !malformed && errors.isEmpty && values != null;
}

enum SeoActionFormOutcome { success, rejected }

final class SeoActionFormResult {
  const SeoActionFormResult({
    required this.outcome,
    required this.message,
    this.fieldErrors = const {},
  });

  const SeoActionFormResult.success(String message)
      : this(outcome: SeoActionFormOutcome.success, message: message);

  const SeoActionFormResult.rejected(
    String message, {
    Map<String, String> fieldErrors = const {},
  }) : this(
          outcome: SeoActionFormOutcome.rejected,
          message: message,
          fieldErrors: fieldErrors,
        );

  final SeoActionFormOutcome outcome;
  final String message;
  final Map<String, String> fieldErrors;
}

SeoActionFormPlan? prepareSeoActionForm(SeoActionFormDefinition definition) {
  final actionId = definition.actionId.trim();
  final returnPath = _canonicalReturnPath(definition.returnPath);
  if (!isValidSeoInteractionId(actionId) ||
      returnPath == null ||
      definition.fields.isEmpty ||
      definition.fields.length > seoActionFormMaxFields ||
      definition.headingLevel < 1 ||
      definition.headingLevel > 6) {
    return null;
  }

  final heading =
      _canonicalText(definition.heading, seoActionFormMaxLabelLength);
  final description =
      _canonicalText(definition.description, seoActionFormMaxDescriptionLength);
  final submitLabel =
      _canonicalText(definition.submitLabel, seoActionFormMaxLabelLength);
  final pendingLabel =
      _canonicalText(definition.pendingLabel, seoActionFormMaxLabelLength);
  final failureLabel =
      _canonicalText(definition.failureLabel, seoActionFormMaxLabelLength);
  final statusLabel =
      _canonicalText(definition.statusLabel, seoActionFormMaxLabelLength);
  final messages = _canonicalMessages(definition.messages);
  if (heading == null ||
      description == null ||
      submitLabel == null ||
      pendingLabel == null ||
      failureLabel == null ||
      statusLabel == null ||
      messages == null) {
    return null;
  }

  final names = <String>{};
  final fields = <SeoActionFormPlanField>[];
  var aggregate = 0;
  for (final raw in definition.fields) {
    final name = raw.name.trim();
    final label = _canonicalText(raw.label, seoActionFormMaxLabelLength);
    final fieldDescription = raw.description == null
        ? null
        : _canonicalText(
            raw.description!,
            seoActionFormMaxDescriptionLength,
          );
    final maxLength = raw.maxLength ?? _defaultMaxLength(raw.kind);
    if (!_fieldName.hasMatch(name) ||
        !names.add(name) ||
        label == null ||
        (raw.description != null && fieldDescription == null) ||
        !_validFieldBounds(raw.kind, raw.minLength, maxLength) ||
        !_validAutocomplete(raw.kind, raw.autocomplete)) {
      return null;
    }
    aggregate += name.length + label.length + (fieldDescription?.length ?? 0);
    if (aggregate > seoActionFormMaxAggregateResultLength) return null;
    fields.add(SeoActionFormPlanField(
      name: name,
      label: label,
      kind: raw.kind,
      description: fieldDescription,
      required: raw.required,
      minLength: raw.minLength,
      maxLength: maxLength,
      autocomplete: raw.autocomplete,
    ));
  }

  return SeoActionFormPlan._(
    actionId: actionId,
    returnPath: returnPath,
    heading: heading,
    description: description,
    submitLabel: submitLabel,
    pendingLabel: pendingLabel,
    failureLabel: failureLabel,
    statusLabel: statusLabel,
    fields: List.unmodifiable(fields),
    headingLevel: definition.headingLevel,
    messages: messages,
  );
}

List<SeoNode> buildSeoActionFormNodes(SeoActionFormDefinition definition) {
  final plan = prepareSeoActionForm(definition);
  return plan == null ? const [] : buildSeoActionFormPlanNodes(plan);
}

List<SeoNode> buildSeoActionFormPlanNodes(SeoActionFormPlan plan) {
  final fallback = SeoNode(
    tag: 'section',
    attributes: const {'class': 'esen-seo-action-form-summary'},
    children: [
      SeoNode(tag: 'h${plan.headingLevel}', text: plan.heading),
      SeoNode(tag: 'p', text: plan.description),
      SeoNode(
        tag: 'ul',
        children: [
          for (final field in plan.fields)
            SeoNode(
              tag: 'li',
              children: [
                SeoNode(tag: 'strong', text: field.label),
                if (field.description case final description?)
                  SeoNode(tag: 'p', text: description),
              ],
            ),
        ],
      ),
    ],
  );
  return [
    buildInternalSeoActionFormNode(
      fallback: fallback,
      markup: SeoActionFormMarkup(
        actionId: plan.actionId,
        headingLevel: plan.headingLevel,
        heading: plan.heading,
        description: plan.description,
        submitLabel: plan.submitLabel,
        pendingLabel: plan.pendingLabel,
        failureLabel: plan.failureLabel,
        statusLabel: plan.statusLabel,
        fields: List.unmodifiable([
          for (final field in plan.fields)
            SeoActionFormMarkupField(
              name: field.name,
              label: field.label,
              kind: switch (field.kind) {
                SeoActionFormFieldKind.text =>
                  SeoActionFormMarkupFieldKind.text,
                SeoActionFormFieldKind.email =>
                  SeoActionFormMarkupFieldKind.email,
                SeoActionFormFieldKind.multiline =>
                  SeoActionFormMarkupFieldKind.multiline,
                SeoActionFormFieldKind.consent =>
                  SeoActionFormMarkupFieldKind.consent,
              },
              required: field.required,
              minLength: field.minLength,
              maxLength: field.maxLength,
              autocomplete: field.autocomplete.value,
              description: field.description,
            ),
        ]),
      ),
    ),
  ];
}

SeoActionFormValidation validateSeoActionFormValues(
  SeoActionFormPlan plan,
  Map<String, String> rawValues,
) {
  final names = {for (final field in plan.fields) field.name};
  if (rawValues.keys.any((name) => !names.contains(name))) {
    return const SeoActionFormValidation._(
      malformed: true,
      errors: {},
    );
  }

  var aggregate = 0;
  final normalized = <String, Object>{};
  final errors = <String, String>{};
  for (final field in plan.fields) {
    final raw = rawValues[field.name] ?? '';
    aggregate += raw.length;
    if (aggregate > seoActionFormMaxAggregateInputLength ||
        _hasUnpairedSurrogate(raw) ||
        _hasBidiControl(raw) ||
        _hasForbiddenControl(raw,
            multiline: field.kind == SeoActionFormFieldKind.multiline)) {
      return const SeoActionFormValidation._(
        malformed: true,
        errors: {},
      );
    }

    if (field.kind == SeoActionFormFieldKind.consent) {
      if (raw.isNotEmpty && raw != 'accepted') {
        return const SeoActionFormValidation._(
          malformed: true,
          errors: {},
        );
      }
      final accepted = raw == 'accepted';
      normalized[field.name] = accepted;
      if (field.required && !accepted) {
        errors[field.name] = plan.messages.consentRequired;
      }
      continue;
    }

    final canonical = (field.kind == SeoActionFormFieldKind.multiline
            ? raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n')
            : raw)
        .trim();
    normalized[field.name] = canonical;
    if (canonical.isEmpty) {
      if (field.required) errors[field.name] = plan.messages.required;
      continue;
    }
    if (raw.length > field.maxLength) {
      errors[field.name] = plan.messages.tooLong;
    } else if (canonical.length < field.minLength) {
      errors[field.name] = plan.messages.tooShort;
    } else if (field.kind == SeoActionFormFieldKind.email &&
        !_validEmail(canonical)) {
      errors[field.name] = plan.messages.invalidEmail;
    }
  }
  return SeoActionFormValidation._(
    malformed: false,
    errors: Map.unmodifiable(errors),
    values: errors.isEmpty ? SeoActionFormValues._(normalized) : null,
  );
}

SeoActionFormResult? canonicalizeSeoActionFormResult(
  SeoActionFormPlan plan,
  SeoActionFormResult raw,
) {
  final message = _canonicalText(raw.message, seoActionFormMaxResultTextLength);
  if (message == null ||
      raw.fieldErrors.length > plan.fields.length ||
      (raw.outcome == SeoActionFormOutcome.success &&
          raw.fieldErrors.isNotEmpty)) {
    return null;
  }
  final names = {for (final field in plan.fields) field.name};
  final errors = <String, String>{};
  var aggregate = message.length;
  for (final entry in raw.fieldErrors.entries) {
    final value = _canonicalText(entry.value, seoActionFormMaxFieldErrorLength);
    if (!names.contains(entry.key) || value == null) return null;
    aggregate += entry.key.length + value.length;
    if (aggregate > seoActionFormMaxAggregateResultLength) return null;
    errors[entry.key] = value;
  }
  return SeoActionFormResult(
    outcome: raw.outcome,
    message: message,
    fieldErrors: Map.unmodifiable(errors),
  );
}

String? canonicalizeSeoActionFormText(
  String raw, {
  required int maxLength,
}) =>
    _canonicalText(raw, maxLength);

bool _validFieldBounds(
  SeoActionFormFieldKind kind,
  int minLength,
  int maxLength,
) {
  if (kind == SeoActionFormFieldKind.consent) {
    return minLength == 0 && maxLength == 0;
  }
  final maximum = _defaultMaxLength(kind);
  return minLength >= 0 &&
      maxLength >= 1 &&
      minLength <= maxLength &&
      maxLength <= maximum;
}

int _defaultMaxLength(SeoActionFormFieldKind kind) => switch (kind) {
      SeoActionFormFieldKind.text => seoActionFormMaxTextLength,
      SeoActionFormFieldKind.email => seoActionFormMaxEmailLength,
      SeoActionFormFieldKind.multiline => seoActionFormMaxMultilineLength,
      SeoActionFormFieldKind.consent => 0,
    };

bool _validAutocomplete(
  SeoActionFormFieldKind kind,
  SeoActionFormAutocomplete autocomplete,
) =>
    switch (kind) {
      SeoActionFormFieldKind.text =>
        autocomplete != SeoActionFormAutocomplete.email,
      SeoActionFormFieldKind.email =>
        autocomplete == SeoActionFormAutocomplete.off ||
            autocomplete == SeoActionFormAutocomplete.email,
      SeoActionFormFieldKind.multiline ||
      SeoActionFormFieldKind.consent =>
        autocomplete == SeoActionFormAutocomplete.off,
    };

SeoActionFormMessages? _canonicalMessages(SeoActionFormMessages raw) {
  final values = [
    _canonicalText(raw.required, seoActionFormMaxFieldErrorLength),
    _canonicalText(raw.invalidEmail, seoActionFormMaxFieldErrorLength),
    _canonicalText(raw.tooShort, seoActionFormMaxFieldErrorLength),
    _canonicalText(raw.tooLong, seoActionFormMaxFieldErrorLength),
    _canonicalText(raw.consentRequired, seoActionFormMaxFieldErrorLength),
  ];
  if (values.any((value) => value == null)) return null;
  return SeoActionFormMessages(
    required: values[0]!,
    invalidEmail: values[1]!,
    tooShort: values[2]!,
    tooLong: values[3]!,
    consentRequired: values[4]!,
  );
}

String? _canonicalText(String raw, int maxLength) {
  final value = canonicalizeSeoConfiguratorText(raw, maxLength: maxLength);
  if (value == null || _hasForbiddenControl(value, multiline: false)) {
    return null;
  }
  return value;
}

String? _canonicalReturnPath(String raw) {
  if (raw.length > 1024 || _hasUnpairedSurrogate(raw)) return null;
  final value = raw.trim();
  final uri = Uri.tryParse(value);
  if (uri == null ||
      uri.hasScheme ||
      uri.hasAuthority ||
      uri.hasQuery ||
      uri.hasFragment ||
      !value.startsWith('/') ||
      value.startsWith('//') ||
      value.contains('\\') ||
      value.codeUnits.any((unit) => unit < 0x20 || unit == 0x7f)) {
    return null;
  }
  return value;
}

bool _validEmail(String value) {
  if (value.length > seoActionFormMaxEmailLength ||
      value.contains(RegExp(r'\s'))) {
    return false;
  }
  final at = value.indexOf('@');
  if (at < 1 || at != value.lastIndexOf('@') || at > 64) return false;
  final local = value.substring(0, at);
  final domain = value.substring(at + 1);
  if (local.startsWith('.') ||
      local.endsWith('.') ||
      local.contains('..') ||
      domain.isEmpty ||
      domain.length > 253 ||
      domain.startsWith('.') ||
      domain.endsWith('.')) {
    return false;
  }
  final labels = domain.split('.');
  return labels.every((label) =>
      label.isNotEmpty &&
      label.length <= 63 &&
      !label.startsWith('-') &&
      !label.endsWith('-') &&
      RegExp(r'^[A-Za-z0-9-]+$').hasMatch(label));
}

bool _hasForbiddenControl(String value, {required bool multiline}) {
  for (final unit in value.codeUnits) {
    if (unit == 0x7f) return true;
    if (unit < 0x20 &&
        !(multiline && (unit == 0x09 || unit == 0x0a || unit == 0x0d))) {
      return true;
    }
  }
  return false;
}

bool _hasBidiControl(String value) {
  for (final rune in value.runes) {
    if (rune == 0x061c ||
        rune == 0x200e ||
        rune == 0x200f ||
        (rune >= 0x202a && rune <= 0x202e) ||
        (rune >= 0x2066 && rune <= 0x2069)) {
      return true;
    }
  }
  return false;
}

bool _hasUnpairedSurrogate(String value) {
  for (var index = 0; index < value.length; index++) {
    final unit = value.codeUnitAt(index);
    if (unit >= 0xd800 && unit <= 0xdbff) {
      if (++index >= value.length) return true;
      final low = value.codeUnitAt(index);
      if (low < 0xdc00 || low > 0xdfff) return true;
    } else if (unit >= 0xdc00 && unit <= 0xdfff) {
      return true;
    }
  }
  return false;
}
