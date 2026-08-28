import 'dart:async';

import 'package:flutter/material.dart';

import '../components/seo_action_form.dart';
import '../renderer/seo_node.dart';
import 'seo_action_form.dart';
import 'seo_block.dart';

/// Native Flutter presentation of a validated, linear action flow.
///
/// The shared [definition] also produces the complete no-JavaScript DOM-first
/// form. This widget owns only the native Flutter controls and presentation.
class SeoActionFlow extends StatefulWidget {
  const SeoActionFlow({
    super.key,
    required this.definition,
    required this.onSubmit,
    this.invalidMessage = 'Please correct the highlighted fields.',
    this.failureMessage = 'The submission could not be completed.',
    this.resetOnSuccess = true,
  });

  final SeoActionFlowDefinition definition;
  final SeoActionFormSubmit onSubmit;
  final String invalidMessage;
  final String failureMessage;
  final bool resetOnSuccess;

  @override
  State<SeoActionFlow> createState() => _SeoActionFlowState();
}

class _SeoActionFlowState extends State<SeoActionFlow>
    with SeoBlockState<SeoActionFlow> {
  final _formKey = GlobalKey<FormState>();
  final _controllers = <String, TextEditingController>{};
  final _consents = <String, bool>{};
  final _choices = <String, String>{};
  final _stepFocusNodes = <FocusNode>[];
  final _reviewFocusNode = FocusNode();
  SeoActionFlowPlan? _plan;
  Map<String, String> _fieldErrors = const {};
  String? _status;
  int _currentStep = 0;
  bool _showingReview = false;
  int _generation = 0;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _replacePlan(prepareSeoActionFlow(widget.definition),
        preserveValues: false);
  }

  @override
  void didUpdateWidget(SeoActionFlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = prepareSeoActionFlow(widget.definition);
    if (_sameFlowPlan(_plan, next)) return;
    _generation++;
    _submitting = false;
    _fieldErrors = const {};
    _status = null;
    _currentStep = 0;
    _showingReview = false;
    _replacePlan(next, preserveValues: _sameFlowControls(_plan, next));
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    for (final node in _stepFocusNodes) {
      node.dispose();
    }
    _reviewFocusNode.dispose();
    super.dispose();
  }

  void _replacePlan(
    SeoActionFlowPlan? next, {
    required bool preserveValues,
  }) {
    final oldControllers = Map<String, TextEditingController>.of(_controllers);
    final oldConsents = Map<String, bool>.of(_consents);
    final oldChoices = Map<String, String>.of(_choices);
    _controllers.clear();
    _consents.clear();
    _choices.clear();
    for (final node in _stepFocusNodes) {
      node.dispose();
    }
    _stepFocusNodes.clear();
    _plan = next;
    if (next != null) {
      _stepFocusNodes.addAll(
        List.generate(next.steps.length, (_) => FocusNode()),
      );
      for (final field in next.form.fields) {
        if (field.kind == SeoActionFormFieldKind.consent) {
          _consents[field.name] =
              preserveValues ? oldConsents[field.name] ?? false : false;
        } else if (field.kind == SeoActionFormFieldKind.choice) {
          final previous = preserveValues ? oldChoices[field.name] ?? '' : '';
          _choices[field.name] = field.options.any(
            (option) => option.value == previous,
          )
              ? previous
              : '';
        } else {
          final old = oldControllers.remove(field.name);
          _controllers[field.name] =
              preserveValues && old != null ? old : TextEditingController();
        }
      }
    }
    for (final controller in oldControllers.values) {
      controller.dispose();
    }
  }

  @override
  Widget buildFlutter(BuildContext context) {
    final plan = _plan;
    if (plan == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final rawValues = _rawValues(plan.form);
    final activeSteps = activeSeoActionFlowStepIndexes(plan, rawValues);
    final currentPosition = _showingReview
        ? activeSteps.length
        : activeSteps.indexOf(_currentStep).clamp(0, activeSteps.length - 1);
    final stageCount = activeSteps.length + (plan.review == null ? 0 : 1);
    final stageLabel = _showingReview
        ? plan.review!.label
        : plan.steps[activeSteps[currentPosition]].label;
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(plan.form.heading, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(plan.form.description),
          const SizedBox(height: 20),
          Semantics(
            container: true,
            label: plan.progressLabel,
            value: '${currentPosition + 1} / $stageCount: $stageLabel',
            child: Text(
              '${currentPosition + 1} / $stageCount',
              style: theme.textTheme.labelLarge,
            ),
          ),
          const SizedBox(height: 12),
          if (_showingReview)
            _review(context, plan, rawValues)
          else
            _step(context, _currentStep, plan.steps[_currentStep]),
          const SizedBox(height: 20),
          Row(
            children: [
              OutlinedButton(
                onPressed: _submitting || currentPosition == 0
                    ? null
                    : () => _navigate(const SeoActionFlowPrevious()),
                child: Text(plan.previousLabel),
              ),
              const Spacer(),
              if (!_showingReview &&
                  (currentPosition < activeSteps.length - 1 ||
                      plan.review != null))
                FilledButton(
                  onPressed: _submitting ? null : _next,
                  child: Text(plan.nextLabel),
                )
              else
                FilledButton(
                  onPressed: _submitting ? null : _submit,
                  child: Text(
                    _submitting
                        ? plan.form.pendingLabel
                        : plan.form.submitLabel,
                  ),
                ),
            ],
          ),
          if (_status case final status?) ...[
            const SizedBox(height: 12),
            Semantics(
              container: true,
              liveRegion: true,
              label: plan.form.statusLabel,
              value: status,
              child: Text(status),
            ),
          ],
        ],
      ),
    );
  }

  Widget _review(
    BuildContext context,
    SeoActionFlowPlan plan,
    Map<String, String> rawValues,
  ) {
    final validation = validateSeoActionFlowValues(plan, rawValues);
    final entries = validation.isValid
        ? buildSeoActionFlowReviewEntries(plan, validation.values!)
        : const <SeoActionFlowReviewEntry>[];
    final theme = Theme.of(context);
    return Focus(
      focusNode: _reviewFocusNode,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(plan.review!.label, style: theme.textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(plan.review!.description),
          const SizedBox(height: 16),
          for (final entry in entries) ...[
            Text(entry.label, style: theme.textTheme.labelLarge),
            const SizedBox(height: 2),
            Text(entry.value),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _step(
    BuildContext context,
    int index,
    SeoActionFlowPlanStep step,
  ) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Focus(
          focusNode: _stepFocusNodes[index],
          child: Text(step.label, style: theme.textTheme.titleLarge),
        ),
        const SizedBox(height: 6),
        Text(step.description),
        const SizedBox(height: 16),
        for (final field in step.fields) ...[
          if (field.kind == SeoActionFormFieldKind.consent)
            _consentField(context, field)
          else if (field.kind == SeoActionFormFieldKind.choice)
            _choiceField(field)
          else
            _textField(field),
          const SizedBox(height: 14),
        ],
      ],
    );
  }

  Widget _textField(SeoActionFormPlanField field) => TextFormField(
        controller: _controllers[field.name],
        enabled: !_submitting,
        keyboardType: switch (field.kind) {
          SeoActionFormFieldKind.email => TextInputType.emailAddress,
          SeoActionFormFieldKind.multiline => TextInputType.multiline,
          SeoActionFormFieldKind.text ||
          SeoActionFormFieldKind.consent ||
          SeoActionFormFieldKind.choice =>
            TextInputType.text,
        },
        minLines: field.kind == SeoActionFormFieldKind.multiline ? 4 : 1,
        maxLines: field.kind == SeoActionFormFieldKind.multiline ? 8 : 1,
        maxLength: field.maxLength,
        autofillHints: switch (field.autocomplete) {
          SeoActionFormAutocomplete.name => const [AutofillHints.name],
          SeoActionFormAutocomplete.email => const [AutofillHints.email],
          SeoActionFormAutocomplete.organization => const [
              AutofillHints.organizationName,
            ],
          SeoActionFormAutocomplete.off => null,
        },
        decoration: InputDecoration(
          labelText: field.label,
          helperText: field.description,
          errorText: _fieldErrors[field.name],
        ),
        validator: (_) => _fieldErrors[field.name],
        onChanged: (_) => _clearFieldError(field.name),
      );

  Widget _choiceField(SeoActionFormPlanField field) => FormField<String>(
        key: ValueKey((field.name, _choices[field.name])),
        initialValue: _choices[field.name],
        validator: (_) => _fieldErrors[field.name],
        builder: (state) => InputDecorator(
          decoration: InputDecoration(
            labelText: field.label,
            helperText: field.description,
            errorText: _fieldErrors[field.name] ?? state.errorText,
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: (_choices[field.name] ?? '').isEmpty
                  ? null
                  : _choices[field.name],
              isExpanded: true,
              hint: Text(field.choicePrompt!),
              items: [
                for (final option in field.options)
                  DropdownMenuItem(
                    value: option.value,
                    child: Text(option.label),
                  ),
              ],
              onChanged: _submitting
                  ? null
                  : (value) {
                      setState(() {
                        _choices[field.name] = value ?? '';
                        final active = activeSeoActionFlowFieldNames(
                          _plan!,
                          _rawValues(_plan!.form),
                        );
                        _fieldErrors = Map.unmodifiable({
                          for (final entry in _fieldErrors.entries)
                            if (entry.key != field.name &&
                                active.contains(entry.key))
                              entry.key: entry.value,
                        });
                      });
                    },
            ),
          ),
        ),
      );

  Widget _consentField(
    BuildContext context,
    SeoActionFormPlanField field,
  ) {
    final error = _fieldErrors[field.name];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(field.label),
          subtitle: field.description == null ? null : Text(field.description!),
          value: _consents[field.name] ?? false,
          onChanged: _submitting
              ? null
              : (value) {
                  setState(() {
                    _consents[field.name] = value ?? false;
                    _fieldErrors = Map<String, String>.of(_fieldErrors)
                      ..remove(field.name);
                  });
                },
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Text(
              error,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
    );
  }

  void _clearFieldError(String name) {
    if (!_fieldErrors.containsKey(name)) return;
    setState(() {
      _fieldErrors = Map<String, String>.of(_fieldErrors)..remove(name);
    });
  }

  Map<String, String> _rawValues(SeoActionFormPlan form) => {
        for (final field in form.fields)
          field.name: field.kind == SeoActionFormFieldKind.consent
              ? ((_consents[field.name] ?? false) ? 'accepted' : '')
              : field.kind == SeoActionFormFieldKind.choice
                  ? _choices[field.name] ?? ''
                  : _controllers[field.name]!.text,
      };

  void _next() {
    final plan = _plan;
    if (plan == null || _submitting) return;
    final rawValues = _rawValues(plan.form);
    final activeSteps = activeSeoActionFlowStepIndexes(plan, rawValues);
    final currentPosition = activeSteps.indexOf(_currentStep);
    if (currentPosition < 0) return;
    final enteringReview =
        plan.review != null && currentPosition == activeSteps.length - 1;
    final validation = validateSeoActionFlowValues(plan, rawValues);
    final names = {
      for (final field in plan.steps[_currentStep].fields) field.name
    };
    final errors = {
      for (final entry in validation.errors.entries)
        if (enteringReview || names.contains(entry.key)) entry.key: entry.value,
    };
    if (validation.malformed || errors.isNotEmpty) {
      final firstInvalidStep =
          enteringReview ? _firstStepForFields(plan, errors.keys) : null;
      setState(() {
        _fieldErrors = Map.unmodifiable(errors);
        _status = _canonicalMessage(widget.invalidMessage) ??
            'Please correct the highlighted fields.';
        if (firstInvalidStep != null) {
          _currentStep = firstInvalidStep;
          _showingReview = false;
        }
      });
      _formKey.currentState?.validate();
      return;
    }
    setState(() {
      _fieldErrors = const {};
      _status = null;
    });
    _navigate(const SeoActionFlowNext());
  }

  void _navigate(SeoActionFlowAction action) {
    final plan = _plan;
    if (plan == null) return;
    final activeSteps = activeSeoActionFlowStepIndexes(
      plan,
      _rawValues(plan.form),
    );
    final currentPosition =
        _showingReview ? activeSteps.length : activeSteps.indexOf(_currentStep);
    if (currentPosition < 0) return;
    final count = activeSteps.length + (plan.review == null ? 0 : 1);
    final next = transitionSeoActionFlow(
      SeoActionFlowState(index: currentPosition, count: count),
      action,
    );
    _showPosition(next.index, activeSteps);
  }

  void _showPosition(int position, List<int> activeSteps) {
    final plan = _plan;
    if (plan == null || position < 0) return;
    if (position == activeSteps.length && plan.review != null) {
      setState(() => _showingReview = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _reviewFocusNode.requestFocus();
      });
      return;
    }
    if (position >= activeSteps.length) return;
    _showStep(activeSteps[position]);
  }

  void _showStep(int index) {
    final plan = _plan;
    if (plan == null || index < 0 || index >= plan.steps.length) return;
    setState(() {
      _currentStep = index;
      _showingReview = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && index < _stepFocusNodes.length) {
        _stepFocusNodes[index].requestFocus();
      }
    });
  }

  Future<void> _submit() async {
    final plan = _plan;
    if (plan == null || _submitting) return;
    final validation = validateSeoActionFlowValues(
      plan,
      _rawValues(plan.form),
    );
    if (!validation.isValid) {
      final firstInvalidStep = _firstStepForFields(
        plan,
        validation.errors.keys,
      );
      setState(() {
        _fieldErrors = validation.errors;
        _status = _canonicalMessage(widget.invalidMessage) ??
            'Please correct the highlighted fields.';
        if (firstInvalidStep != null) {
          _currentStep = firstInvalidStep;
          _showingReview = false;
        }
      });
      _formKey.currentState?.validate();
      return;
    }

    final generation = ++_generation;
    setState(() {
      _submitting = true;
      _fieldErrors = const {};
      _status = null;
    });
    SeoActionFormResult? result;
    try {
      final raw = await Future<SeoActionFormResult>.sync(
        () => widget.onSubmit(validation.values!),
      );
      result = canonicalizeSeoActionFormResult(
        plan.form,
        raw,
        allowedFieldNames: validation.values!.values.keys.toSet(),
      );
    } catch (_) {
      result = null;
    }
    if (!mounted || generation != _generation) return;
    final firstErrorStep = result == null
        ? null
        : _firstStepForFields(plan, result.fieldErrors.keys);
    setState(() {
      _submitting = false;
      if (result == null) {
        _status = _canonicalMessage(widget.failureMessage) ??
            'The submission could not be completed.';
        return;
      }
      _status = result.message;
      _fieldErrors = result.fieldErrors;
      if (firstErrorStep != null) {
        _currentStep = firstErrorStep;
        _showingReview = false;
      }
      if (result.outcome == SeoActionFormOutcome.success &&
          widget.resetOnSuccess) {
        for (final controller in _controllers.values) {
          controller.clear();
        }
        for (final name in _consents.keys) {
          _consents[name] = false;
        }
        for (final name in _choices.keys) {
          _choices[name] = '';
        }
        _currentStep = 0;
        _showingReview = false;
      }
    });
    _formKey.currentState?.validate();
  }

  String? _canonicalMessage(String value) => canonicalizeSeoActionFormText(
        value,
        maxLength: seoActionFormMaxResultTextLength,
      );

  @override
  List<SeoNode> toSeoNodes() {
    final plan = _plan;
    return plan == null ? const [] : buildSeoActionFlowPlanNodes(plan);
  }
}

int? _firstStepForFields(SeoActionFlowPlan plan, Iterable<String> names) {
  final pending = names.toSet();
  if (pending.isEmpty) return null;
  for (final (index, step) in plan.steps.indexed) {
    if (step.fields.any((field) => pending.contains(field.name))) return index;
  }
  return null;
}

bool _sameFlowControls(SeoActionFlowPlan? left, SeoActionFlowPlan? right) {
  if (left == null || right == null) return false;
  final a = left.form.fields;
  final b = right.form.fields;
  if (a.length != b.length) return false;
  for (var index = 0; index < a.length; index++) {
    if (a[index].name != b[index].name || a[index].kind != b[index].kind) {
      return false;
    }
  }
  return true;
}

bool _sameFlowPlan(SeoActionFlowPlan? left, SeoActionFlowPlan? right) {
  if (identical(left, right)) return true;
  if (left == null ||
      right == null ||
      left.previousLabel != right.previousLabel ||
      left.nextLabel != right.nextLabel ||
      left.progressLabel != right.progressLabel ||
      !_sameReview(left.review, right.review) ||
      left.steps.length != right.steps.length ||
      !_sameFormPlan(left.form, right.form)) {
    return false;
  }
  for (var index = 0; index < left.steps.length; index++) {
    final a = left.steps[index];
    final b = right.steps[index];
    if (a.label != b.label ||
        a.description != b.description ||
        a.firstFieldIndex != b.firstFieldIndex ||
        a.condition?.fieldName != b.condition?.fieldName ||
        a.condition?.fieldIndex != b.condition?.fieldIndex ||
        a.condition?.value != b.condition?.value ||
        a.fields.length != b.fields.length) {
      return false;
    }
  }
  return true;
}

bool _sameReview(
  SeoActionFlowPlanReview? left,
  SeoActionFlowPlanReview? right,
) =>
    identical(left, right) ||
    (left != null &&
        right != null &&
        left.label == right.label &&
        left.description == right.description &&
        left.emptyValueLabel == right.emptyValueLabel &&
        left.consentAcceptedLabel == right.consentAcceptedLabel &&
        left.consentDeclinedLabel == right.consentDeclinedLabel);

bool _sameFormPlan(SeoActionFormPlan left, SeoActionFormPlan right) {
  if (left.actionId != right.actionId ||
      left.returnPath != right.returnPath ||
      left.heading != right.heading ||
      left.description != right.description ||
      left.submitLabel != right.submitLabel ||
      left.pendingLabel != right.pendingLabel ||
      left.failureLabel != right.failureLabel ||
      left.statusLabel != right.statusLabel ||
      left.headingLevel != right.headingLevel ||
      left.fields.length != right.fields.length ||
      left.messages.required != right.messages.required ||
      left.messages.invalidEmail != right.messages.invalidEmail ||
      left.messages.tooShort != right.messages.tooShort ||
      left.messages.tooLong != right.messages.tooLong ||
      left.messages.consentRequired != right.messages.consentRequired) {
    return false;
  }
  for (var index = 0; index < left.fields.length; index++) {
    final a = left.fields[index];
    final b = right.fields[index];
    if (a.name != b.name ||
        a.label != b.label ||
        a.kind != b.kind ||
        a.description != b.description ||
        a.required != b.required ||
        a.minLength != b.minLength ||
        a.maxLength != b.maxLength ||
        a.autocomplete != b.autocomplete ||
        a.choicePrompt != b.choicePrompt ||
        a.options.length != b.options.length) {
      return false;
    }
    for (var optionIndex = 0; optionIndex < a.options.length; optionIndex++) {
      if (a.options[optionIndex].value != b.options[optionIndex].value ||
          a.options[optionIndex].label != b.options[optionIndex].label) {
        return false;
      }
    }
  }
  return true;
}
