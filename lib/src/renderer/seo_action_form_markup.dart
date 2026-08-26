/// Opaque package-owned markup plan for one DOM-first action form.
library;

const String internalSeoActionFormEndpointPrefix = '/_esen_seo/forms/';

const int internalSeoActionFormMaxFields = 8;
const int internalSeoActionFormMaxLabelLength = 120;
const int internalSeoActionFormMaxDescriptionLength = 512;
const int internalSeoActionFormMaxFieldNameLength = 32;
const int internalSeoActionFormMaxTextLength = 512;
const int internalSeoActionFormMaxEmailLength = 254;
const int internalSeoActionFormMaxMultilineLength = 4096;
const int internalSeoActionFormMaxOptions = 12;
const int internalSeoActionFlowMaxSteps = 6;

enum SeoActionFormMarkupFieldKind { text, email, multiline, consent, choice }

final class SeoActionFormMarkupOption {
  const SeoActionFormMarkupOption({required this.value, required this.label});

  final String value;
  final String label;
}

final class SeoActionFormMarkupField {
  const SeoActionFormMarkupField({
    required this.name,
    required this.label,
    required this.kind,
    required this.required,
    required this.minLength,
    required this.maxLength,
    required this.autocomplete,
    this.description,
    this.choicePrompt,
    this.options = const [],
  });

  final String name;
  final String label;
  final SeoActionFormMarkupFieldKind kind;
  final bool required;
  final int minLength;
  final int maxLength;
  final String autocomplete;
  final String? description;
  final String? choicePrompt;
  final List<SeoActionFormMarkupOption> options;
}

final class SeoActionFlowMarkupStep {
  const SeoActionFlowMarkupStep({
    required this.label,
    required this.description,
    required this.firstFieldIndex,
    required this.fieldCount,
  });

  final String label;
  final String description;
  final int firstFieldIndex;
  final int fieldCount;
}

final class SeoActionFlowMarkup {
  const SeoActionFlowMarkup({
    required this.steps,
    required this.previousLabel,
    required this.nextLabel,
    required this.progressLabel,
  });

  final List<SeoActionFlowMarkupStep> steps;
  final String previousLabel;
  final String nextLabel;
  final String progressLabel;
}

final class SeoActionFormMarkup {
  const SeoActionFormMarkup({
    required this.actionId,
    required this.headingLevel,
    required this.heading,
    required this.description,
    required this.submitLabel,
    required this.pendingLabel,
    required this.failureLabel,
    required this.statusLabel,
    required this.fields,
    this.flow,
  });

  final String actionId;
  final int headingLevel;
  final String heading;
  final String description;
  final String submitLabel;
  final String pendingLabel;
  final String failureLabel;
  final String statusLabel;
  final List<SeoActionFormMarkupField> fields;
  final SeoActionFlowMarkup? flow;
}

bool isValidInternalSeoActionFormMarkup(SeoActionFormMarkup markup) {
  if (!_interactionId.hasMatch(markup.actionId) ||
      markup.headingLevel < 1 ||
      markup.headingLevel > 6 ||
      !_validText(markup.heading, internalSeoActionFormMaxLabelLength) ||
      !_validText(
        markup.description,
        internalSeoActionFormMaxDescriptionLength,
      ) ||
      !_validText(markup.submitLabel, internalSeoActionFormMaxLabelLength) ||
      !_validText(markup.pendingLabel, internalSeoActionFormMaxLabelLength) ||
      !_validText(markup.failureLabel, internalSeoActionFormMaxLabelLength) ||
      !_validText(markup.statusLabel, internalSeoActionFormMaxLabelLength) ||
      markup.fields.isEmpty ||
      markup.fields.length > internalSeoActionFormMaxFields) {
    return false;
  }

  final names = <String>{};
  for (final field in markup.fields) {
    if (!_fieldName.hasMatch(field.name) ||
        !names.add(field.name) ||
        !_validText(field.label, internalSeoActionFormMaxLabelLength) ||
        (field.description != null &&
            !_validText(
              field.description!,
              internalSeoActionFormMaxDescriptionLength,
            )) ||
        !_autocompletes.contains(field.autocomplete) ||
        !_validOptions(field)) {
      return false;
    }
    final maximum = switch (field.kind) {
      SeoActionFormMarkupFieldKind.text => internalSeoActionFormMaxTextLength,
      SeoActionFormMarkupFieldKind.email => internalSeoActionFormMaxEmailLength,
      SeoActionFormMarkupFieldKind.multiline =>
        internalSeoActionFormMaxMultilineLength,
      SeoActionFormMarkupFieldKind.consent ||
      SeoActionFormMarkupFieldKind.choice =>
        0,
    };
    if (field.kind == SeoActionFormMarkupFieldKind.consent ||
        field.kind == SeoActionFormMarkupFieldKind.choice) {
      if (field.minLength != 0 ||
          field.maxLength != 0 ||
          field.autocomplete != 'off') {
        return false;
      }
    } else if (field.minLength < 0 ||
        field.maxLength < 1 ||
        field.minLength > field.maxLength ||
        field.maxLength > maximum) {
      return false;
    }
    if (field.kind == SeoActionFormMarkupFieldKind.email &&
        field.autocomplete != 'off' &&
        field.autocomplete != 'email') {
      return false;
    }
    if ((field.kind == SeoActionFormMarkupFieldKind.multiline ||
            field.kind == SeoActionFormMarkupFieldKind.choice ||
            field.kind == SeoActionFormMarkupFieldKind.consent) &&
        field.autocomplete != 'off') {
      return false;
    }
  }
  return _validFlow(markup);
}

bool _validOptions(SeoActionFormMarkupField field) {
  if (field.kind != SeoActionFormMarkupFieldKind.choice) {
    return field.options.isEmpty && field.choicePrompt == null;
  }
  if (field.choicePrompt == null ||
      !_validText(field.choicePrompt!, internalSeoActionFormMaxLabelLength) ||
      field.options.length < 2 ||
      field.options.length > internalSeoActionFormMaxOptions) {
    return false;
  }
  final values = <String>{};
  for (final option in field.options) {
    if (!_optionValue.hasMatch(option.value) ||
        !values.add(option.value) ||
        !_validText(option.label, internalSeoActionFormMaxLabelLength)) {
      return false;
    }
  }
  return true;
}

bool _validFlow(SeoActionFormMarkup markup) {
  final flow = markup.flow;
  if (flow == null) return true;
  if (flow.steps.length < 2 ||
      flow.steps.length > internalSeoActionFlowMaxSteps ||
      !_validText(flow.previousLabel, internalSeoActionFormMaxLabelLength) ||
      !_validText(flow.nextLabel, internalSeoActionFormMaxLabelLength) ||
      !_validText(flow.progressLabel, internalSeoActionFormMaxLabelLength)) {
    return false;
  }
  var expectedField = 0;
  for (final step in flow.steps) {
    if (!_validText(step.label, internalSeoActionFormMaxLabelLength) ||
        !_validText(
          step.description,
          internalSeoActionFormMaxDescriptionLength,
        ) ||
        step.firstFieldIndex != expectedField ||
        step.fieldCount < 1 ||
        step.firstFieldIndex + step.fieldCount > markup.fields.length) {
      return false;
    }
    expectedField += step.fieldCount;
  }
  return expectedField == markup.fields.length;
}

bool _validText(String value, int maxLength) =>
    value.isNotEmpty &&
    value.length <= maxLength &&
    !_hasForbiddenCodeUnit(value);

bool _hasForbiddenCodeUnit(String value) {
  for (var index = 0; index < value.length; index++) {
    final unit = value.codeUnitAt(index);
    if (unit < 0x20 || unit == 0x7f) {
      return true;
    }
    if (unit >= 0xd800 && unit <= 0xdbff) {
      if (++index >= value.length) return true;
      final low = value.codeUnitAt(index);
      if (low < 0xdc00 || low > 0xdfff) return true;
    } else if (unit >= 0xdc00 && unit <= 0xdfff) {
      return true;
    }
  }
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

final RegExp _interactionId = RegExp(r'^[a-z][a-z0-9_-]{0,63}$');
final RegExp _fieldName = RegExp(r'^[a-z][a-z0-9_]{0,31}$');
final RegExp _optionValue = RegExp(r'^[a-z][a-z0-9_-]{0,31}$');
const Set<String> _autocompletes = {
  'off',
  'name',
  'email',
  'organization',
};
