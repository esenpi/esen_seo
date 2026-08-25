import 'package:flutter/material.dart';

import '../components/seo_approval_checklist_component.dart';
import '../components/seo_approval_checklist_transition.dart';
import '../renderer/seo_node.dart';
import 'seo_block.dart';

final class SeoApprovalChecklistItemContent {
  const SeoApprovalChecklistItemContent({
    required this.label,
    required this.content,
    required this.nodes,
  });

  final String label;
  final Widget content;
  final List<SeoNode> nodes;
}

class SeoApprovalChecklist extends StatefulWidget {
  const SeoApprovalChecklist({
    super.key,
    required this.items,
    required this.initialState,
    required this.project,
    this.transition = transitionSeoApprovalChecklist,
    this.interactionId,
    this.headingLevel = 2,
    this.heading = 'Approval checklist',
    this.interactionLabel = 'Approval checklist controls',
    this.statusLabel = 'Status',
    this.progressLabel = 'Progress',
    this.onChanged,
  });

  final List<SeoApprovalChecklistItemContent> items;
  final SeoApprovalChecklistState initialState;
  final SeoApprovalChecklistViewProjection project;
  final SeoApprovalChecklistTransition transition;
  final String? interactionId;
  final int headingLevel;
  final String heading;
  final String interactionLabel;
  final String statusLabel;
  final String progressLabel;
  final ValueChanged<SeoApprovalChecklistEvaluation>? onChanged;

  @override
  State<SeoApprovalChecklist> createState() => _SeoApprovalChecklistState();
}

class _SeoApprovalChecklistState extends State<SeoApprovalChecklist>
    with SeoBlockState<SeoApprovalChecklist> {
  SeoApprovalChecklistComponentPlan? _plan;
  SeoApprovalChecklistComponentPlan? _mirrorPlan;
  SeoApprovalChecklistEvaluation? _evaluation;
  var _hasInteracted = false;

  @override
  void initState() {
    super.initState();
    _plan = _prepare(widget.initialState);
    _mirrorPlan = _plan;
    _evaluation = _plan?.initial;
  }

  @override
  void didUpdateWidget(SeoApprovalChecklist oldWidget) {
    super.didUpdateWidget(oldWidget);
    final structureChanged = widget.initialState != oldWidget.initialState ||
        !_sameItemLabels(widget.items, oldWidget.items);
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

  SeoApprovalChecklistComponentPlan? _prepare(
    SeoApprovalChecklistState state,
  ) =>
      prepareSeoApprovalChecklistComponent(
        items: [
          for (final item in widget.items)
            (label: item.label, nodes: item.nodes),
        ],
        initialState: state,
        project: widget.project,
        interactionId: widget.interactionId,
        headingLevel: widget.headingLevel,
        heading: widget.heading,
        interactionLabel: widget.interactionLabel,
        statusLabel: widget.statusLabel,
        progressLabel: widget.progressLabel,
      );

  @override
  Widget buildFlutter(BuildContext context) {
    final plan = _plan;
    final current = _evaluation;
    if (plan == null || current == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final state = current.state;
    final view = current.view;
    final checkedCount = seoApprovalChecklistCheckedCount(state);
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
          label: plan.progressLabel,
          value: '$checkedCount / ${plan.items.length}',
          child: LinearProgressIndicator(
            value: checkedCount / plan.items.length,
            minHeight: 8,
          ),
        ),
        const SizedBox(height: 16),
        for (final (index, item) in widget.items.indexed) ...[
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(plan.items[index].label),
            value: state.checked[index],
            onChanged: (checked) {
              if (checked != null) {
                _dispatch(SeoApprovalChecklistSetItem(index, checked));
              }
            },
          ),
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 12),
            child: item.content,
          ),
        ],
        Semantics(
          container: true,
          liveRegion: _hasInteracted,
          label: _hasInteracted ? view.announcementText : null,
          child: const SizedBox(width: 1, height: 1),
        ),
      ],
    );
  }

  void _dispatch(SeoApprovalChecklistAction action) {
    final current = _evaluation;
    if (current == null) return;
    final next = evaluateSeoApprovalChecklistAction(
      transition: widget.transition,
      project: widget.project,
      current: current,
      action: action,
      itemCount: widget.items.length,
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
    return plan == null ? const [] : buildSeoApprovalChecklistPlanNodes(plan);
  }
}

bool _sameItemLabels(
  List<SeoApprovalChecklistItemContent> left,
  List<SeoApprovalChecklistItemContent> right,
) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index].label != right[index].label) return false;
  }
  return true;
}
