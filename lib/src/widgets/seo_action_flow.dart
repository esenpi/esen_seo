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
  SeoActionFlowPlan? _plan;
  Map<String, String> _fieldErrors = const {};
  String? _status;
  int _currentStep = 0;
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
    final step = plan.steps[_currentStep];
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
            value: '${_currentStep + 1} / ${plan.steps.length}: ${step.label}',
            child: Text(
              '${_currentStep + 1} / ${plan.steps.length}',
              style: theme.textTheme.labelLarge,
            ),
          ),
          const SizedBox(height: 12),
          IndexedStack(
            index: _currentStep,
            sizing: StackFit.loose,
            children: [
              for (final (index, candidate) in plan.steps.indexed)
                _step(context, index, candidate),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              OutlinedButton(
                onPressed: _submitting || _currentStep == 0
                    ? null
                    : () => _navigate(const SeoActionFlowPrevious()),
                child: Text(plan.previousLabel),
              ),
              const Spacer(),
              if (_currentStep < plan.steps.length - 1)
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
            errorText: state.errorText,
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
                        _fieldErrors = Map<String, String>.of(_fieldErrors)
                          ..remove(field.name);
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
    final validation = validateSeoActionFormValues(
      plan.form,
      _rawValues(plan.form),
    );
    final names = {
      for (final field in plan.steps[_currentStep].fields) field.name
    };
    final errors = {
      for (final entry in validation.errors.entries)
        if (names.contains(entry.key)) entry.key: entry.value,
    };
    if (validation.malformed || errors.isNotEmpty) {
      setState(() {
        _fieldErrors = Map.unmodifiable(errors);
        _status = _canonicalMessage(widget.invalidMessage) ??
            'Please correct the highlighted fields.';
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
    final next = transitionSeoActionFlow(
      SeoActionFlowState(index: _currentStep, count: plan.steps.length),
      action,
    );
    _showStep(next.index);
  }

  void _showStep(int index) {
    final plan = _plan;
    if (plan == null || index < 0 || index >= plan.steps.length) return;
    setState(() => _currentStep = index);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && index < _stepFocusNodes.length) {
        _stepFocusNodes[index].requestFocus();
      }
    });
  }

  Future<void> _submit() async {
    final plan = _plan;
    if (plan == null || _submitting) return;
    final validation = validateSeoActionFormValues(
      plan.form,
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
        if (firstInvalidStep != null) _currentStep = firstInvalidStep;
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
      result = canonicalizeSeoActionFormResult(plan.form, raw);
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
      if (firstErrorStep != null) _currentStep = firstErrorStep;
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
        a.fields.length != b.fields.length) {
      return false;
    }
  }
  return true;
}

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
