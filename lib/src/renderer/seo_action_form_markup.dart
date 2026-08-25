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

enum SeoActionFormMarkupFieldKind { text, email, multiline, consent }

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
  });

  final String name;
  final String label;
  final SeoActionFormMarkupFieldKind kind;
  final bool required;
  final int minLength;
  final int maxLength;
  final String autocomplete;
  final String? description;
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
        !_autocompletes.contains(field.autocomplete)) {
      return false;
    }
    final maximum = switch (field.kind) {
      SeoActionFormMarkupFieldKind.text => internalSeoActionFormMaxTextLength,
      SeoActionFormMarkupFieldKind.email => internalSeoActionFormMaxEmailLength,
      SeoActionFormMarkupFieldKind.multiline =>
        internalSeoActionFormMaxMultilineLength,
      SeoActionFormMarkupFieldKind.consent => 0,
    };
    if (field.kind == SeoActionFormMarkupFieldKind.consent) {
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
    if (field.kind == SeoActionFormMarkupFieldKind.multiline &&
        field.autocomplete != 'off') {
      return false;
    }
  }
  return true;
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
const Set<String> _autocompletes = {
  'off',
  'name',
  'email',
  'organization',
};
