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
const int seoActionFormMaxOptions = 12;
const int seoActionFlowMaxSteps = 6;

final RegExp _fieldName = RegExp(r'^[a-z][a-z0-9_]{0,31}$');
final RegExp _optionValue = RegExp(r'^[a-z][a-z0-9_-]{0,31}$');

enum SeoActionFormFieldKind { text, email, multiline, consent, choice }

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

final class SeoActionFormOption {
  const SeoActionFormOption({required this.value, required this.label});

  final String value;
  final String label;
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
    this.choicePrompt,
    this.options = const [],
  });

  final String name;
  final String label;
  final SeoActionFormFieldKind kind;
  final String? description;
  final bool required;
  final int minLength;
  final int? maxLength;
  final SeoActionFormAutocomplete autocomplete;
  final String? choicePrompt;
  final List<SeoActionFormOption> options;
}

final class SeoActionFormPlanOption {
  const SeoActionFormPlanOption({required this.value, required this.label});

  final String value;
  final String label;
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
    this.choicePrompt,
    this.options = const [],
  });

  final String name;
  final String label;
  final SeoActionFormFieldKind kind;
  final String? description;
  final bool required;
  final int minLength;
  final int maxLength;
  final SeoActionFormAutocomplete autocomplete;
  final String? choicePrompt;
  final List<SeoActionFormPlanOption> options;
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

final class SeoActionFlowStep {
  const SeoActionFlowStep({
    required this.label,
    required this.description,
    required this.fieldNames,
    this.condition,
  });

  final String label;
  final String description;
  final List<String> fieldNames;
  final SeoActionFlowCondition? condition;
}

/// A closed branch condition evaluated against an earlier choice field.
final class SeoActionFlowCondition {
  const SeoActionFlowCondition.choiceEquals({
    required this.fieldName,
    required this.value,
  });

  final String fieldName;
  final String value;
}

/// Labels for the optional package-generated final review stage.
final class SeoActionFlowReview {
  const SeoActionFlowReview({
    required this.label,
    required this.description,
    required this.emptyValueLabel,
    required this.consentAcceptedLabel,
    required this.consentDeclinedLabel,
  });

  final String label;
  final String description;
  final String emptyValueLabel;
  final String consentAcceptedLabel;
  final String consentDeclinedLabel;
}

final class SeoActionFlowDefinition {
  const SeoActionFlowDefinition({
    required this.form,
    required this.steps,
    required this.previousLabel,
    required this.nextLabel,
    required this.progressLabel,
    this.review,
  });

  final SeoActionFormDefinition form;
  final List<SeoActionFlowStep> steps;
  final String previousLabel;
  final String nextLabel;
  final String progressLabel;
  final SeoActionFlowReview? review;
}

final class SeoActionFlowPlanCondition {
  const SeoActionFlowPlanCondition({
    required this.fieldName,
    required this.fieldIndex,
    required this.value,
  });

  final String fieldName;
  final int fieldIndex;
  final String value;
}

final class SeoActionFlowPlanStep {
  const SeoActionFlowPlanStep({
    required this.label,
    required this.description,
    required this.firstFieldIndex,
    required this.fields,
    this.condition,
  });

  final String label;
  final String description;
  final int firstFieldIndex;
  final List<SeoActionFormPlanField> fields;
  final SeoActionFlowPlanCondition? condition;
}

final class SeoActionFlowPlanReview {
  const SeoActionFlowPlanReview({
    required this.label,
    required this.description,
    required this.emptyValueLabel,
    required this.consentAcceptedLabel,
    required this.consentDeclinedLabel,
  });

  final String label;
  final String description;
  final String emptyValueLabel;
  final String consentAcceptedLabel;
  final String consentDeclinedLabel;
}

final class SeoActionFlowPlan {
  const SeoActionFlowPlan._({
    required this.form,
    required this.steps,
    required this.previousLabel,
    required this.nextLabel,
    required this.progressLabel,
    required this.review,
  });

  final SeoActionFormPlan form;
  final List<SeoActionFlowPlanStep> steps;
  final String previousLabel;
  final String nextLabel;
  final String progressLabel;
  final SeoActionFlowPlanReview? review;
}

/// Pure navigation state shared by native and DOM-first action flows.
final class SeoActionFlowState {
  const SeoActionFlowState({required this.index, required this.count});

  final int index;
  final int count;

  @override
  bool operator ==(Object other) =>
      other is SeoActionFlowState &&
      other.index == index &&
      other.count == count;

  @override
  int get hashCode => Object.hash(index, count);
}

/// A user navigation intent admitted by the linear action flow.
sealed class SeoActionFlowAction {
  const SeoActionFlowAction();
}

/// Moves to the next step without wrapping at the final step.
final class SeoActionFlowNext extends SeoActionFlowAction {
  const SeoActionFlowNext();
}

/// Moves to the previous step without wrapping at the first step.
final class SeoActionFlowPrevious extends SeoActionFlowAction {
  const SeoActionFlowPrevious();
}

/// Returns a normalized initial state for an action flow.
SeoActionFlowState initialSeoActionFlowState({required int count}) {
  final normalizedCount = count < 0 ? 0 : count;
  return SeoActionFlowState(index: 0, count: normalizedCount);
}

/// Computes the next linear action-flow state without retaining state.
SeoActionFlowState transitionSeoActionFlow(
  SeoActionFlowState state,
  SeoActionFlowAction action,
) {
  final count = state.count < 0 ? 0 : state.count;
  if (count == 0) return const SeoActionFlowState(index: 0, count: 0);
  final current = state.index.clamp(0, count - 1);
  final next = switch (action) {
    SeoActionFlowNext() => (current + 1).clamp(0, count - 1),
    SeoActionFlowPrevious() => (current - 1).clamp(0, count - 1),
  };
  return SeoActionFlowState(index: next, count: count);
}

final class SeoActionFormValues {
  SeoActionFormValues._(Map<String, Object> values)
      : values = Map.unmodifiable(values);

  final Map<String, Object> values;

  String text(String name) =>
      values[name] is String ? values[name]! as String : '';

  String choice(String name) => text(name);

  bool consent(String name) => values[name] == true;

  bool contains(String name) => values.containsKey(name);
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

final class SeoActionFlowReviewEntry {
  const SeoActionFlowReviewEntry({
    required this.fieldName,
    required this.label,
    required this.value,
  });

  final String fieldName;
  final String label;
  final String value;
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
    final choicePrompt = raw.choicePrompt == null
        ? null
        : _canonicalText(raw.choicePrompt!, seoActionFormMaxLabelLength);
    final options = <SeoActionFormPlanOption>[];
    final optionValues = <String>{};
    for (final option in raw.options) {
      final value = option.value.trim();
      final optionLabel =
          _canonicalText(option.label, seoActionFormMaxLabelLength);
      if (!_optionValue.hasMatch(value) ||
          !optionValues.add(value) ||
          optionLabel == null) {
        return null;
      }
      options.add(SeoActionFormPlanOption(value: value, label: optionLabel));
    }
    if (!_fieldName.hasMatch(name) ||
        !names.add(name) ||
        label == null ||
        (raw.description != null && fieldDescription == null) ||
        !_validChoice(raw.kind, choicePrompt, options) ||
        !_validFieldBounds(raw.kind, raw.minLength, maxLength) ||
        !_validAutocomplete(raw.kind, raw.autocomplete)) {
      return null;
    }
    aggregate += name.length +
        label.length +
        (fieldDescription?.length ?? 0) +
        (choicePrompt?.length ?? 0) +
        options.fold<int>(
          0,
          (sum, option) => sum + option.value.length + option.label.length,
        );
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
      choicePrompt: choicePrompt,
      options: List.unmodifiable(options),
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
                if (field.kind == SeoActionFormFieldKind.choice)
                  SeoNode(
                    tag: 'ul',
                    children: [
                      for (final option in field.options)
                        SeoNode(tag: 'li', text: option.label),
                    ],
                  ),
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
          for (final field in plan.fields) _actionFormMarkupField(field),
        ]),
      ),
    ),
  ];
}

SeoActionFlowPlan? prepareSeoActionFlow(SeoActionFlowDefinition definition) {
  final form = prepareSeoActionForm(definition.form);
  if (form == null ||
      definition.steps.length < 2 ||
      definition.steps.length > seoActionFlowMaxSteps) {
    return null;
  }
  final previousLabel = canonicalizeSeoActionFormText(
    definition.previousLabel,
    maxLength: seoActionFormMaxLabelLength,
  );
  final nextLabel = canonicalizeSeoActionFormText(
    definition.nextLabel,
    maxLength: seoActionFormMaxLabelLength,
  );
  final progressLabel = canonicalizeSeoActionFormText(
    definition.progressLabel,
    maxLength: seoActionFormMaxLabelLength,
  );
  if (previousLabel == null || nextLabel == null || progressLabel == null) {
    return null;
  }

  SeoActionFlowPlanReview? review;
  if (definition.review case final rawReview?) {
    final label = canonicalizeSeoActionFormText(
      rawReview.label,
      maxLength: seoActionFormMaxLabelLength,
    );
    final description = canonicalizeSeoActionFormText(
      rawReview.description,
      maxLength: seoActionFormMaxDescriptionLength,
    );
    final emptyValueLabel = canonicalizeSeoActionFormText(
      rawReview.emptyValueLabel,
      maxLength: seoActionFormMaxLabelLength,
    );
    final consentAcceptedLabel = canonicalizeSeoActionFormText(
      rawReview.consentAcceptedLabel,
      maxLength: seoActionFormMaxLabelLength,
    );
    final consentDeclinedLabel = canonicalizeSeoActionFormText(
      rawReview.consentDeclinedLabel,
      maxLength: seoActionFormMaxLabelLength,
    );
    if (label == null ||
        description == null ||
        emptyValueLabel == null ||
        consentAcceptedLabel == null ||
        consentDeclinedLabel == null) {
      return null;
    }
    review = SeoActionFlowPlanReview(
      label: label,
      description: description,
      emptyValueLabel: emptyValueLabel,
      consentAcceptedLabel: consentAcceptedLabel,
      consentDeclinedLabel: consentDeclinedLabel,
    );
  }

  final steps = <SeoActionFlowPlanStep>[];
  var fieldIndex = 0;
  for (final rawStep in definition.steps) {
    final label = canonicalizeSeoActionFormText(
      rawStep.label,
      maxLength: seoActionFormMaxLabelLength,
    );
    final description = canonicalizeSeoActionFormText(
      rawStep.description,
      maxLength: seoActionFormMaxDescriptionLength,
    );
    if (label == null ||
        description == null ||
        rawStep.fieldNames.isEmpty ||
        fieldIndex + rawStep.fieldNames.length > form.fields.length) {
      return null;
    }
    final fields = <SeoActionFormPlanField>[];
    for (final rawName in rawStep.fieldNames) {
      final name = rawName.trim();
      final expected = form.fields[fieldIndex];
      if (name != expected.name) return null;
      fields.add(expected);
      fieldIndex++;
    }
    SeoActionFlowPlanCondition? condition;
    if (rawStep.condition case final rawCondition?) {
      final conditionName = rawCondition.fieldName.trim();
      final conditionValue = rawCondition.value.trim();
      final conditionIndex = form.fields.indexWhere(
        (field) => field.name == conditionName,
      );
      if (conditionIndex < 0 || conditionIndex >= fieldIndex - fields.length) {
        return null;
      }
      final conditionField = form.fields[conditionIndex];
      final owner = steps.cast<SeoActionFlowPlanStep?>().firstWhere(
            (step) =>
                step!.fields.any((field) => field.name == conditionField.name),
            orElse: () => null,
          );
      if (conditionField.kind != SeoActionFormFieldKind.choice ||
          owner == null ||
          owner.condition != null ||
          !conditionField.options.any(
            (option) => option.value == conditionValue,
          )) {
        return null;
      }
      condition = SeoActionFlowPlanCondition(
        fieldName: conditionField.name,
        fieldIndex: conditionIndex,
        value: conditionValue,
      );
    }
    steps.add(SeoActionFlowPlanStep(
      label: label,
      description: description,
      firstFieldIndex: fieldIndex - fields.length,
      fields: List.unmodifiable(fields),
      condition: condition,
    ));
  }
  if (fieldIndex != form.fields.length) return null;
  return SeoActionFlowPlan._(
    form: form,
    steps: List.unmodifiable(steps),
    previousLabel: previousLabel,
    nextLabel: nextLabel,
    progressLabel: progressLabel,
    review: review,
  );
}

/// Returns the authored step indices active for the supplied raw choice values.
List<int> activeSeoActionFlowStepIndexes(
  SeoActionFlowPlan plan,
  Map<String, String> rawValues,
) =>
    List.unmodifiable([
      for (final (index, step) in plan.steps.indexed)
        if (step.condition == null ||
            rawValues[step.condition!.fieldName] == step.condition!.value)
          index,
    ]);

Set<String> activeSeoActionFlowFieldNames(
  SeoActionFlowPlan plan,
  Map<String, String> rawValues,
) =>
    Set.unmodifiable({
      for (final stepIndex in activeSeoActionFlowStepIndexes(plan, rawValues))
        for (final field in plan.steps[stepIndex].fields) field.name,
    });

List<SeoNode> buildSeoActionFlowNodes(SeoActionFlowDefinition definition) {
  final plan = prepareSeoActionFlow(definition);
  return plan == null ? const [] : buildSeoActionFlowPlanNodes(plan);
}

List<SeoNode> buildSeoActionFlowPlanNodes(SeoActionFlowPlan plan) {
  final form = plan.form;
  final stepHeadingLevel = form.headingLevel < 6 ? form.headingLevel + 1 : 6;
  final fallback = SeoNode(
    tag: 'section',
    attributes: const {'class': 'esen-seo-action-flow-summary'},
    children: [
      SeoNode(tag: 'h${form.headingLevel}', text: form.heading),
      SeoNode(tag: 'p', text: form.description),
      SeoNode(
        tag: 'ol',
        children: [
          for (final step in plan.steps)
            SeoNode(
              tag: 'li',
              children: [
                SeoNode(tag: 'h$stepHeadingLevel', text: step.label),
                SeoNode(tag: 'p', text: step.description),
                SeoNode(
                  tag: 'ul',
                  children: [
                    for (final field in step.fields)
                      _actionFormFieldSummaryNode(field),
                  ],
                ),
              ],
            ),
          if (plan.review case final review?)
            SeoNode(
              tag: 'li',
              children: [
                SeoNode(tag: 'h$stepHeadingLevel', text: review.label),
                SeoNode(tag: 'p', text: review.description),
                SeoNode(
                  tag: 'ul',
                  children: [
                    for (final field in form.fields)
                      SeoNode(tag: 'li', text: field.label),
                  ],
                ),
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
        actionId: form.actionId,
        headingLevel: form.headingLevel,
        heading: form.heading,
        description: form.description,
        submitLabel: form.submitLabel,
        pendingLabel: form.pendingLabel,
        failureLabel: form.failureLabel,
        statusLabel: form.statusLabel,
        fields: List.unmodifiable([
          for (final field in form.fields) _actionFormMarkupField(field),
        ]),
        flow: SeoActionFlowMarkup(
          steps: List.unmodifiable([
            for (final step in plan.steps)
              SeoActionFlowMarkupStep(
                label: step.label,
                description: step.description,
                firstFieldIndex: step.firstFieldIndex,
                fieldCount: step.fields.length,
                condition: step.condition == null
                    ? null
                    : SeoActionFlowMarkupCondition(
                        fieldName: step.condition!.fieldName,
                        fieldIndex: step.condition!.fieldIndex,
                        value: step.condition!.value,
                      ),
              ),
          ]),
          previousLabel: plan.previousLabel,
          nextLabel: plan.nextLabel,
          progressLabel: plan.progressLabel,
          review: plan.review == null
              ? null
              : SeoActionFlowMarkupReview(
                  label: plan.review!.label,
                  description: plan.review!.description,
                  emptyValueLabel: plan.review!.emptyValueLabel,
                  consentAcceptedLabel: plan.review!.consentAcceptedLabel,
                  consentDeclinedLabel: plan.review!.consentDeclinedLabel,
                ),
        ),
      ),
    ),
  ];
}

SeoActionFormValidation validateSeoActionFormValues(
  SeoActionFormPlan plan,
  Map<String, String> rawValues,
) =>
    _validateSeoActionFormValues(plan, rawValues);

/// Validates one conditional flow and exposes only values from active steps.
SeoActionFormValidation validateSeoActionFlowValues(
  SeoActionFlowPlan plan,
  Map<String, String> rawValues,
) =>
    _validateSeoActionFormValues(
      plan.form,
      rawValues,
      activeFieldNames: activeSeoActionFlowFieldNames(plan, rawValues),
    );

List<SeoActionFlowReviewEntry> buildSeoActionFlowReviewEntries(
  SeoActionFlowPlan plan,
  SeoActionFormValues values,
) {
  final review = plan.review;
  if (review == null) return const [];
  return List.unmodifiable([
    for (final field in plan.form.fields)
      if (values.contains(field.name))
        SeoActionFlowReviewEntry(
          fieldName: field.name,
          label: field.label,
          value: switch (field.kind) {
            SeoActionFormFieldKind.consent => values.consent(field.name)
                ? review.consentAcceptedLabel
                : review.consentDeclinedLabel,
            SeoActionFormFieldKind.choice => field.options
                .firstWhere(
                  (option) => option.value == values.choice(field.name),
                  orElse: () => SeoActionFormPlanOption(
                    value: '',
                    label: review.emptyValueLabel,
                  ),
                )
                .label,
            SeoActionFormFieldKind.text ||
            SeoActionFormFieldKind.email ||
            SeoActionFormFieldKind.multiline =>
              values.text(field.name).isEmpty
                  ? review.emptyValueLabel
                  : values.text(field.name),
          },
        ),
  ]);
}

SeoActionFormValidation _validateSeoActionFormValues(
  SeoActionFormPlan plan,
  Map<String, String> rawValues, {
  Set<String>? activeFieldNames,
}) {
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
    final active =
        activeFieldNames == null || activeFieldNames.contains(field.name);
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
      if (!active) continue;
      normalized[field.name] = accepted;
      if (field.required && !accepted) {
        errors[field.name] = plan.messages.consentRequired;
      }
      continue;
    }

    if (field.kind == SeoActionFormFieldKind.choice) {
      if (raw.isNotEmpty &&
          !field.options.any((option) => option.value == raw)) {
        return const SeoActionFormValidation._(
          malformed: true,
          errors: {},
        );
      }
      if (!active) continue;
      normalized[field.name] = raw;
      if (field.required && raw.isEmpty) {
        errors[field.name] = plan.messages.required;
      }
      continue;
    }

    final canonical = (field.kind == SeoActionFormFieldKind.multiline
            ? raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n')
            : raw)
        .trim();
    if (!active) continue;
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
  SeoActionFormResult raw, {
  Set<String>? allowedFieldNames,
}) {
  final message = _canonicalText(raw.message, seoActionFormMaxResultTextLength);
  if (message == null ||
      raw.fieldErrors.length > plan.fields.length ||
      (raw.outcome == SeoActionFormOutcome.success &&
          raw.fieldErrors.isNotEmpty)) {
    return null;
  }
  final names =
      allowedFieldNames ?? {for (final field in plan.fields) field.name};
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

SeoNode _actionFormFieldSummaryNode(SeoActionFormPlanField field) => SeoNode(
      tag: 'li',
      children: [
        SeoNode(tag: 'strong', text: field.label),
        if (field.description case final description?)
          SeoNode(tag: 'p', text: description),
        if (field.kind == SeoActionFormFieldKind.choice)
          SeoNode(
            tag: 'ul',
            children: [
              for (final option in field.options)
                SeoNode(tag: 'li', text: option.label),
            ],
          ),
      ],
    );

SeoActionFormMarkupField _actionFormMarkupField(
  SeoActionFormPlanField field,
) =>
    SeoActionFormMarkupField(
      name: field.name,
      label: field.label,
      kind: switch (field.kind) {
        SeoActionFormFieldKind.text => SeoActionFormMarkupFieldKind.text,
        SeoActionFormFieldKind.email => SeoActionFormMarkupFieldKind.email,
        SeoActionFormFieldKind.multiline =>
          SeoActionFormMarkupFieldKind.multiline,
        SeoActionFormFieldKind.consent => SeoActionFormMarkupFieldKind.consent,
        SeoActionFormFieldKind.choice => SeoActionFormMarkupFieldKind.choice,
      },
      required: field.required,
      minLength: field.minLength,
      maxLength: field.maxLength,
      autocomplete: field.autocomplete.value,
      description: field.description,
      choicePrompt: field.choicePrompt,
      options: List.unmodifiable([
        for (final option in field.options)
          SeoActionFormMarkupOption(
            value: option.value,
            label: option.label,
          ),
      ]),
    );

bool _validChoice(
  SeoActionFormFieldKind kind,
  String? prompt,
  List<SeoActionFormPlanOption> options,
) {
  if (kind != SeoActionFormFieldKind.choice) {
    return prompt == null && options.isEmpty;
  }
  return prompt != null &&
      options.length >= 2 &&
      options.length <= seoActionFormMaxOptions;
}

bool _validFieldBounds(
  SeoActionFormFieldKind kind,
  int minLength,
  int maxLength,
) {
  if (kind == SeoActionFormFieldKind.consent ||
      kind == SeoActionFormFieldKind.choice) {
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
      SeoActionFormFieldKind.consent || SeoActionFormFieldKind.choice => 0,
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
      SeoActionFormFieldKind.consent ||
      SeoActionFormFieldKind.choice =>
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
  if (value == null ||
      _hasUnpairedSurrogate(value) ||
      _hasBidiControl(value) ||
      _hasForbiddenControl(value, multiline: false)) {
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
