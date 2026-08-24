import 'package:flutter/material.dart';

import '../components/seo_configurator_component.dart';
import '../components/seo_configurator_transition.dart';
import '../renderer/seo_node.dart';
import 'seo_block.dart';

/// One choice shared by the native and semantic configurator presentations.
class SeoConfiguratorChoice {
  const SeoConfiguratorChoice({
    required this.label,
    required this.content,
    required this.nodes,
  });

  final String label;
  final Widget content;
  final List<SeoNode> nodes;
}

/// Native Flutter presentation of the curated configurator slice.
///
/// This widget is intentionally internal while the pricing use case proves the
/// component boundary. It owns Flutter state and controls, while all accepted
/// actions pass through the same pure transition and view projection used by
/// the browser candidate.
class SeoConfigurator extends StatefulWidget {
  const SeoConfigurator({
    super.key,
    required this.choices,
    required this.optionContent,
    required this.optionNodes,
    required this.constraints,
    required this.initialState,
    required this.project,
    this.transition = transitionSeoConfigurator,
    this.interactionId,
    this.headingLevel = 2,
    this.heading = 'Configure your plan',
    this.interactionLabel = 'Pricing configurator',
    this.choiceGroupLabel = 'Plan',
    this.quantityLabel = 'Quantity',
    this.optionLabel = 'Additional option',
    this.priceLabel = 'Estimated price',
    this.decrementLabel = 'Decrease quantity',
    this.incrementLabel = 'Increase quantity',
    this.onChanged,
  });

  final List<SeoConfiguratorChoice> choices;
  final Widget optionContent;
  final List<SeoNode> optionNodes;
  final SeoConfiguratorConstraints constraints;
  final SeoConfiguratorState initialState;
  final SeoConfiguratorViewProjection project;
  final SeoConfiguratorTransition transition;
  final String? interactionId;
  final int headingLevel;
  final String heading;
  final String interactionLabel;
  final String choiceGroupLabel;
  final String quantityLabel;
  final String optionLabel;
  final String priceLabel;
  final String decrementLabel;
  final String incrementLabel;

  /// Reports one completely validated native state and view change.
  final ValueChanged<SeoConfiguratorEvaluation>? onChanged;

  @override
  State<SeoConfigurator> createState() => _SeoConfiguratorState();
}

class _SeoConfiguratorState extends State<SeoConfigurator>
    with SeoBlockState<SeoConfigurator> {
  SeoConfiguratorComponentPlan? _plan;
  SeoConfiguratorComponentPlan? _mirrorPlan;
  SeoConfiguratorEvaluation? _evaluation;
  var _hasInteracted = false;

  @override
  void initState() {
    super.initState();
    _plan = _prepare(widget.initialState);
    _mirrorPlan = _plan;
    _evaluation = _plan?.initial;
  }

  @override
  void didUpdateWidget(SeoConfigurator oldWidget) {
    super.didUpdateWidget(oldWidget);
    final structureChanged = widget.constraints != oldWidget.constraints ||
        widget.initialState != oldWidget.initialState ||
        !_sameChoiceLabels(widget.choices, oldWidget.choices);
    final state = structureChanged
        ? widget.initialState
        : (_evaluation?.state ?? widget.initialState);
    final nextPlan = _prepare(state);
    final nextMirrorPlan =
        state == widget.initialState ? nextPlan : _prepare(widget.initialState);
    if (nextPlan == null || nextMirrorPlan == null) {
      _plan = null;
      _mirrorPlan = null;
      _evaluation = null;
    } else {
      _plan = nextPlan;
      _mirrorPlan = nextMirrorPlan;
      _evaluation = nextPlan.initial;
    }
    if (structureChanged) _hasInteracted = false;
  }

  SeoConfiguratorComponentPlan? _prepare(SeoConfiguratorState state) =>
      prepareSeoConfiguratorComponent(
        choices: [
          for (final choice in widget.choices)
            (label: choice.label, nodes: choice.nodes),
        ],
        optionNodes: widget.optionNodes,
        constraints: widget.constraints,
        initialState: state,
        project: widget.project,
        interactionId: widget.interactionId,
        headingLevel: widget.headingLevel,
        heading: widget.heading,
        interactionLabel: widget.interactionLabel,
        choiceGroupLabel: widget.choiceGroupLabel,
        quantityLabel: widget.quantityLabel,
        optionLabel: widget.optionLabel,
        priceLabel: widget.priceLabel,
        decrementLabel: widget.decrementLabel,
        incrementLabel: widget.incrementLabel,
      );

  @override
  Widget buildFlutter(BuildContext context) {
    final plan = _plan;
    final current = _evaluation;
    if (plan == null || current == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final state = current.state;
    final view = current.view;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(plan.heading, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 16),
        Semantics(
          container: true,
          label: plan.choiceGroupLabel,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var index = 0; index < plan.choices.length; index++)
                _choiceControl(plan, index, state.choiceIndex == index),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: Text(plan.quantityLabel)),
            IconButton(
              onPressed: state.quantity > plan.constraints.minQuantity
                  ? () => _dispatch(
                        const SeoConfiguratorDecrementQuantity(),
                      )
                  : null,
              tooltip: plan.decrementLabel,
              icon: const Icon(Icons.remove),
            ),
            SizedBox(
              width: 48,
              child: Text(
                '${state.quantity}',
                textAlign: TextAlign.center,
              ),
            ),
            IconButton(
              onPressed: state.quantity < plan.constraints.maxQuantity
                  ? () => _dispatch(
                        const SeoConfiguratorIncrementQuantity(),
                      )
                  : null,
              tooltip: plan.incrementLabel,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(plan.optionLabel),
          value: state.optionEnabled,
          onChanged: (enabled) => _dispatch(SeoConfiguratorSetOption(enabled)),
        ),
        const SizedBox(height: 12),
        Semantics(
          container: true,
          liveRegion: _hasInteracted,
          label: _hasInteracted ? view.announcementText : null,
          child: const SizedBox(width: 1, height: 1),
        ),
        Text(
          '${plan.priceLabel}: ${view.priceText}',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(view.summaryText),
        const SizedBox(height: 16),
        KeyedSubtree(
          key: ValueKey('configurator-choice-${state.choiceIndex}'),
          child: widget.choices[state.choiceIndex].content,
        ),
        if (state.optionEnabled) ...[
          const SizedBox(height: 12),
          widget.optionContent,
        ],
      ],
    );
  }

  Widget _choiceControl(
    SeoConfiguratorComponentPlan plan,
    int index,
    bool selected,
  ) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      button: true,
      enabled: true,
      selected: selected,
      label: plan.choices[index].label,
      excludeSemantics: true,
      onTap: () => _dispatch(SeoConfiguratorSelectChoice(index)),
      child: OutlinedButton(
        onPressed: () => _dispatch(SeoConfiguratorSelectChoice(index)),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(44, 44),
          foregroundColor: selected ? colors.onPrimaryContainer : null,
          backgroundColor: selected ? colors.primaryContainer : null,
          side: BorderSide(
            color: selected ? colors.primary : colors.outlineVariant,
            width: selected ? 2 : 1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        child: Text(plan.choices[index].label),
      ),
    );
  }

  void _dispatch(SeoConfiguratorAction action) {
    final current = _evaluation;
    if (current == null) return;
    final next = evaluateSeoConfiguratorAction(
      transition: widget.transition,
      project: widget.project,
      current: current,
      action: action,
      constraints: widget.constraints,
    );
    if (next == null || !next.accepted || !mounted) return;
    setState(() {
      _evaluation = next;
      _hasInteracted = true;
    });
    widget.onChanged?.call(next);
  }

  @override
  List<SeoNode> toSeoNodes() {
    final plan = _mirrorPlan;
    return plan == null ? const [] : buildSeoConfiguratorPlanNodes(plan);
  }
}

bool _sameChoiceLabels(
  List<SeoConfiguratorChoice> first,
  List<SeoConfiguratorChoice> second,
) {
  if (first.length != second.length) return false;
  for (var index = 0; index < first.length; index++) {
    if (first[index].label != second[index].label) return false;
  }
  return true;
}
