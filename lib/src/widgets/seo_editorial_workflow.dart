import 'package:flutter/material.dart';

import '../components/seo_editorial_workflow_component.dart';
import '../components/seo_editorial_workflow_transition.dart';
import '../renderer/seo_node.dart';
import 'seo_block.dart';

final class SeoEditorialWorkflowStageContent {
  const SeoEditorialWorkflowStageContent({
    required this.label,
    required this.content,
    required this.nodes,
  });

  final String label;
  final Widget content;
  final List<SeoNode> nodes;
}

class SeoEditorialWorkflow extends StatefulWidget {
  const SeoEditorialWorkflow({
    super.key,
    required this.stages,
    required this.initialState,
    required this.project,
    this.transition = transitionSeoEditorialWorkflow,
    this.interactionId,
    this.headingLevel = 2,
    this.heading = 'Editorial workflow',
    this.interactionLabel = 'Editorial approval workflow',
    this.statusLabel = 'Status',
    this.progressLabel = 'Progress',
    this.historyLabel = 'History',
    this.submitLabel = 'Submit for review',
    this.approveLabel = 'Approve',
    this.rejectLabel = 'Reject',
    this.publishLabel = 'Publish',
    this.onChanged,
  });

  final List<SeoEditorialWorkflowStageContent> stages;
  final SeoEditorialWorkflowState initialState;
  final SeoEditorialWorkflowViewProjection project;
  final SeoEditorialWorkflowTransition transition;
  final String? interactionId;
  final int headingLevel;
  final String heading;
  final String interactionLabel;
  final String statusLabel;
  final String progressLabel;
  final String historyLabel;
  final String submitLabel;
  final String approveLabel;
  final String rejectLabel;
  final String publishLabel;
  final ValueChanged<SeoEditorialWorkflowEvaluation>? onChanged;

  @override
  State<SeoEditorialWorkflow> createState() => _SeoEditorialWorkflowState();
}

class _SeoEditorialWorkflowState extends State<SeoEditorialWorkflow>
    with SeoBlockState<SeoEditorialWorkflow> {
  SeoEditorialWorkflowComponentPlan? _plan;
  SeoEditorialWorkflowComponentPlan? _mirrorPlan;
  SeoEditorialWorkflowEvaluation? _evaluation;
  var _hasInteracted = false;

  @override
  void initState() {
    super.initState();
    _plan = _prepare(widget.initialState);
    _mirrorPlan = _plan;
    _evaluation = _plan?.initial;
  }

  @override
  void didUpdateWidget(SeoEditorialWorkflow oldWidget) {
    super.didUpdateWidget(oldWidget);
    final structureChanged = widget.initialState != oldWidget.initialState ||
        !_sameStageLabels(widget.stages, oldWidget.stages);
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

  SeoEditorialWorkflowComponentPlan? _prepare(
    SeoEditorialWorkflowState state,
  ) =>
      prepareSeoEditorialWorkflowComponent(
        stages: [
          for (final stage in widget.stages)
            (label: stage.label, nodes: stage.nodes),
        ],
        initialState: state,
        project: widget.project,
        interactionId: widget.interactionId,
        headingLevel: widget.headingLevel,
        heading: widget.heading,
        interactionLabel: widget.interactionLabel,
        statusLabel: widget.statusLabel,
        progressLabel: widget.progressLabel,
        historyLabel: widget.historyLabel,
        submitLabel: widget.submitLabel,
        approveLabel: widget.approveLabel,
        rejectLabel: widget.rejectLabel,
        publishLabel: widget.publishLabel,
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
        Text(
          '${plan.statusLabel}: ${view.statusText}',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(view.summaryText),
        const SizedBox(height: 16),
        Semantics(
          container: true,
          label: plan.progressLabel,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final stage in SeoEditorialWorkflowStage.values)
                Semantics(
                  selected: stage == state.stage,
                  label: plan.stages[stage.index].label,
                  excludeSemantics: true,
                  child: Chip(
                    avatar: Icon(
                      stage.index < state.stage.index
                          ? Icons.check
                          : Icons.circle_outlined,
                      size: 16,
                    ),
                    label: Text(plan.stages[stage.index].label),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        KeyedSubtree(
          key: ValueKey('editorial-workflow-stage-${state.stage.index}'),
          child: widget.stages[state.stage.index].content,
        ),
        const SizedBox(height: 16),
        Text(plan.historyLabel, style: theme.textTheme.titleMedium),
        const SizedBox(height: 6),
        for (final (index, stage) in state.history.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text('${index + 1}. ${plan.stages[stage.index].label}'),
          ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _actionButton(
              plan.submitLabel,
              const SeoEditorialWorkflowSubmit(),
            ),
            _actionButton(
              plan.approveLabel,
              const SeoEditorialWorkflowApprove(),
            ),
            _actionButton(
              plan.rejectLabel,
              const SeoEditorialWorkflowReject(),
            ),
            _actionButton(
              plan.publishLabel,
              const SeoEditorialWorkflowPublish(),
            ),
          ],
        ),
        Semantics(
          container: true,
          liveRegion: _hasInteracted,
          label: _hasInteracted ? view.announcementText : null,
          child: const SizedBox(width: 1, height: 1),
        ),
      ],
    );
  }

  Widget _actionButton(String label, SeoEditorialWorkflowAction action) {
    final current = _evaluation;
    final enabled = current != null &&
        isSeoEditorialWorkflowActionEnabled(current.state, action);
    return OutlinedButton(
      onPressed: enabled ? () => _dispatch(action) : null,
      child: Text(label),
    );
  }

  void _dispatch(SeoEditorialWorkflowAction action) {
    final current = _evaluation;
    if (current == null) return;
    final next = evaluateSeoEditorialWorkflowAction(
      transition: widget.transition,
      project: widget.project,
      current: current,
      action: action,
    );
    if (next == null || !next.accepted) return;
    setState(() {
      _evaluation = next;
      _hasInteracted = true;
    });
    widget.onChanged?.call(next);
  }

  @override
  List<SeoNode> toSeoNodes() {
    final plan = _mirrorPlan;
    return plan == null ? const [] : buildSeoEditorialWorkflowPlanNodes(plan);
  }
}

bool _sameStageLabels(
  List<SeoEditorialWorkflowStageContent> left,
  List<SeoEditorialWorkflowStageContent> right,
) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index].label != right[index].label) return false;
  }
  return true;
}
