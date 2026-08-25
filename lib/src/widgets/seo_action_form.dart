import 'dart:async';

import 'package:flutter/material.dart';

import '../components/seo_action_form.dart';
import '../renderer/seo_node.dart';
import 'seo_block.dart';

typedef SeoActionFormSubmit = FutureOr<SeoActionFormResult> Function(
  SeoActionFormValues values,
);

/// Native Flutter presentation of the curated action-form slice.
///
/// The same [definition] builds the non-interactive Flutter mirror and the
/// real DOM-first form. Only this native presentation owns editable controls.
class SeoActionForm extends StatefulWidget {
  const SeoActionForm({
    super.key,
    required this.definition,
    required this.onSubmit,
    this.invalidMessage = 'Please correct the highlighted fields.',
    this.failureMessage = 'The submission could not be completed.',
    this.resetOnSuccess = true,
  });

  final SeoActionFormDefinition definition;
  final SeoActionFormSubmit onSubmit;
  final String invalidMessage;
  final String failureMessage;
  final bool resetOnSuccess;

  @override
  State<SeoActionForm> createState() => _SeoActionFormState();
}

class _SeoActionFormState extends State<SeoActionForm>
    with SeoBlockState<SeoActionForm> {
  final _formKey = GlobalKey<FormState>();
  final _controllers = <String, TextEditingController>{};
  final _consents = <String, bool>{};
  SeoActionFormPlan? _plan;
  Map<String, String> _fieldErrors = const {};
  String? _status;
  bool _submitting = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _replacePlan(prepareSeoActionForm(widget.definition),
        preserveValues: false);
  }

  @override
  void didUpdateWidget(SeoActionForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = prepareSeoActionForm(widget.definition);
    if (_samePlan(_plan, next)) return;
    _generation++;
    _submitting = false;
    _fieldErrors = const {};
    _status = null;
    _replacePlan(next, preserveValues: _sameControls(_plan, next));
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _replacePlan(
    SeoActionFormPlan? next, {
    required bool preserveValues,
  }) {
    final oldControllers = Map<String, TextEditingController>.of(_controllers);
    final oldConsents = Map<String, bool>.of(_consents);
    _controllers.clear();
    _consents.clear();
    _plan = next;
    if (next != null) {
      for (final field in next.fields) {
        if (field.kind == SeoActionFormFieldKind.consent) {
          _consents[field.name] =
              preserveValues ? oldConsents[field.name] ?? false : false;
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
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(plan.heading, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(plan.description),
          const SizedBox(height: 20),
          for (final field in plan.fields) ...[
            if (field.kind == SeoActionFormFieldKind.consent)
              _consentField(context, field)
            else
              _textField(field),
            const SizedBox(height: 14),
          ],
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: Text(_submitting ? plan.pendingLabel : plan.submitLabel),
          ),
          if (_status case final status?) ...[
            const SizedBox(height: 12),
            Semantics(
              container: true,
              liveRegion: true,
              label: plan.statusLabel,
              value: status,
              child: Text(status),
            ),
          ],
        ],
      ),
    );
  }

  Widget _textField(SeoActionFormPlanField field) {
    return TextFormField(
      controller: _controllers[field.name],
      enabled: !_submitting,
      keyboardType: switch (field.kind) {
        SeoActionFormFieldKind.email => TextInputType.emailAddress,
        SeoActionFormFieldKind.multiline => TextInputType.multiline,
        SeoActionFormFieldKind.text ||
        SeoActionFormFieldKind.consent =>
          TextInputType.text,
      },
      minLines: field.kind == SeoActionFormFieldKind.multiline ? 4 : 1,
      maxLines: field.kind == SeoActionFormFieldKind.multiline ? 8 : 1,
      maxLength: field.maxLength,
      autofillHints: switch (field.autocomplete) {
        SeoActionFormAutocomplete.name => const [AutofillHints.name],
        SeoActionFormAutocomplete.email => const [AutofillHints.email],
        SeoActionFormAutocomplete.organization => const [
            AutofillHints.organizationName
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
  }

  Widget _consentField(BuildContext context, SeoActionFormPlanField field) {
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
            child: Text(error,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
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

  Future<void> _submit() async {
    final plan = _plan;
    if (plan == null || _submitting) return;
    final rawValues = <String, String>{
      for (final field in plan.fields)
        field.name: field.kind == SeoActionFormFieldKind.consent
            ? ((_consents[field.name] ?? false) ? 'accepted' : '')
            : _controllers[field.name]!.text,
    };
    final validation = validateSeoActionFormValues(plan, rawValues);
    if (!validation.isValid) {
      setState(() {
        _fieldErrors = validation.errors;
        _status = _canonicalMessage(widget.invalidMessage) ??
            'Please correct the highlighted fields.';
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
      result = canonicalizeSeoActionFormResult(plan, raw);
    } catch (_) {
      result = null;
    }
    if (!mounted || generation != _generation) return;
    setState(() {
      _submitting = false;
      if (result == null) {
        _status = _canonicalMessage(widget.failureMessage) ??
            'The submission could not be completed.';
        return;
      }
      _status = result.message;
      _fieldErrors = result.fieldErrors;
      if (result.outcome == SeoActionFormOutcome.success &&
          widget.resetOnSuccess) {
        for (final controller in _controllers.values) {
          controller.clear();
        }
        for (final name in _consents.keys) {
          _consents[name] = false;
        }
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
    return plan == null ? const [] : buildSeoActionFormPlanNodes(plan);
  }
}

bool _sameControls(SeoActionFormPlan? left, SeoActionFormPlan? right) {
  if (left == null ||
      right == null ||
      left.fields.length != right.fields.length) {
    return false;
  }
  for (var index = 0; index < left.fields.length; index++) {
    final a = left.fields[index];
    final b = right.fields[index];
    if (a.name != b.name || a.kind != b.kind) return false;
  }
  return true;
}

bool _samePlan(SeoActionFormPlan? left, SeoActionFormPlan? right) {
  if (identical(left, right)) return true;
  if (left == null ||
      right == null ||
      left.actionId != right.actionId ||
      left.returnPath != right.returnPath ||
      left.heading != right.heading ||
      left.description != right.description ||
      left.submitLabel != right.submitLabel ||
      left.pendingLabel != right.pendingLabel ||
      left.failureLabel != right.failureLabel ||
      left.statusLabel != right.statusLabel ||
      left.headingLevel != right.headingLevel ||
      left.fields.length != right.fields.length) {
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
        a.autocomplete != b.autocomplete) {
      return false;
    }
  }
  return left.messages.required == right.messages.required &&
      left.messages.invalidEmail == right.messages.invalidEmail &&
      left.messages.tooShort == right.messages.tooShort &&
      left.messages.tooLong == right.messages.tooLong &&
      left.messages.consentRequired == right.messages.consentRequired;
}
