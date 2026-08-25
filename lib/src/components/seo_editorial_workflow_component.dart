/// Pure semantic builder for the curated editorial workflow slice.
library;

import '../renderer/seo_node.dart';
import 'seo_component_format.dart';
import 'seo_configurator_transition.dart' show canonicalizeSeoConfiguratorText;
import 'seo_editorial_workflow_transition.dart';

typedef SeoEditorialWorkflowStageEntry = ({
  String label,
  List<SeoNode> nodes,
});

const int seoEditorialWorkflowMaxLabelTextLength = 128;
const int seoEditorialWorkflowMaxAggregateLabelTextLength = 2048;

final class SeoEditorialWorkflowComponentPlan {
  SeoEditorialWorkflowComponentPlan._({
    required this.stages,
    required this.initial,
    required this.interactionId,
    required this.headingLevel,
    required this.heading,
    required this.interactionLabel,
    required this.statusLabel,
    required this.progressLabel,
    required this.historyLabel,
    required this.submitLabel,
    required this.approveLabel,
    required this.rejectLabel,
    required this.publishLabel,
  });

  final List<SeoEditorialWorkflowStageEntry> stages;
  final SeoEditorialWorkflowEvaluation initial;
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
}

SeoEditorialWorkflowComponentPlan? prepareSeoEditorialWorkflowComponent({
  required List<SeoEditorialWorkflowStageEntry> stages,
  required SeoEditorialWorkflowState initialState,
  required SeoEditorialWorkflowViewProjection project,
  String? interactionId,
  int headingLevel = 2,
  String heading = 'Editorial workflow',
  String interactionLabel = 'Editorial approval workflow',
  String statusLabel = 'Status',
  String progressLabel = 'Progress',
  String historyLabel = 'History',
  String submitLabel = 'Submit for review',
  String approveLabel = 'Approve',
  String rejectLabel = 'Reject',
  String publishLabel = 'Publish',
}) {
  if (stages.length != SeoEditorialWorkflowStage.values.length) return null;
  final rawLabels = <String>[
    heading,
    interactionLabel,
    statusLabel,
    progressLabel,
    historyLabel,
    submitLabel,
    approveLabel,
    rejectLabel,
    publishLabel,
    for (final stage in stages) stage.label,
  ];
  if (rawLabels.fold<int>(0, (sum, label) => sum + label.length) >
      seoEditorialWorkflowMaxAggregateLabelTextLength) {
    return null;
  }
  final labels = <String>[];
  for (final raw in rawLabels) {
    final label = canonicalizeSeoConfiguratorText(
      raw,
      maxLength: seoEditorialWorkflowMaxLabelTextLength,
    );
    if (label == null) return null;
    labels.add(label.trim());
  }
  final stageLabels = labels.skip(9).toList(growable: false);
  if (stageLabels.toSet().length != stageLabels.length) return null;

  final initial = evaluateInitialSeoEditorialWorkflowView(
    project,
    initialState,
  );
  if (initial == null) return null;
  final candidateId = interactionId?.trim();
  final id = candidateId != null && isValidSeoInteractionId(candidateId)
      ? candidateId
      : null;
  return SeoEditorialWorkflowComponentPlan._(
    stages: List.unmodifiable([
      for (final (index, stage) in stages.indexed)
        (
          label: stageLabels[index],
          nodes: List<SeoNode>.unmodifiable(stage.nodes),
        ),
    ]),
    initial: initial,
    interactionId: id,
    headingLevel: headingLevel.clamp(1, 6),
    heading: labels[0],
    interactionLabel: labels[1],
    statusLabel: labels[2],
    progressLabel: labels[3],
    historyLabel: labels[4],
    submitLabel: labels[5],
    approveLabel: labels[6],
    rejectLabel: labels[7],
    publishLabel: labels[8],
  );
}

List<SeoNode> buildSeoEditorialWorkflowNodes({
  required List<SeoEditorialWorkflowStageEntry> stages,
  required SeoEditorialWorkflowState initialState,
  required SeoEditorialWorkflowViewProjection project,
  String? interactionId,
  int headingLevel = 2,
  String heading = 'Editorial workflow',
  String interactionLabel = 'Editorial approval workflow',
  String statusLabel = 'Status',
  String progressLabel = 'Progress',
  String historyLabel = 'History',
  String submitLabel = 'Submit for review',
  String approveLabel = 'Approve',
  String rejectLabel = 'Reject',
  String publishLabel = 'Publish',
}) {
  final plan = prepareSeoEditorialWorkflowComponent(
    stages: stages,
    initialState: initialState,
    project: project,
    interactionId: interactionId,
    headingLevel: headingLevel,
    heading: heading,
    interactionLabel: interactionLabel,
    statusLabel: statusLabel,
    progressLabel: progressLabel,
    historyLabel: historyLabel,
    submitLabel: submitLabel,
    approveLabel: approveLabel,
    rejectLabel: rejectLabel,
    publishLabel: publishLabel,
  );
  return plan == null ? const [] : buildSeoEditorialWorkflowPlanNodes(plan);
}

List<SeoNode> buildSeoEditorialWorkflowPlanNodes(
  SeoEditorialWorkflowComponentPlan plan,
) {
  final id = plan.interactionId;
  final state = plan.initial.state;
  final view = plan.initial.view;
  final sectionLevel = (plan.headingLevel + 1).clamp(1, 6);
  return [
    SeoNode(
      tag: 'section',
      attributes: {
        'class': 'esen-seo-editorial-workflow',
        if (id != null) ...{
          'id': id,
          'data-esen-component': 'editorial-workflow',
          'data-esen-layout-stable': 'true',
          'data-esen-label': plan.interactionLabel,
          'data-esen-status-label': plan.statusLabel,
          'data-esen-progress-label': plan.progressLabel,
          'data-esen-history-label': plan.historyLabel,
          'data-esen-submit-label': plan.submitLabel,
          'data-esen-approve-label': plan.approveLabel,
          'data-esen-reject-label': plan.rejectLabel,
          'data-esen-publish-label': plan.publishLabel,
          'data-esen-initial-stage': '${state.stage.index}',
          'data-esen-initial-history':
              state.history.map((stage) => stage.index).join(','),
        },
      },
      children: [
        SeoNode(tag: 'h${plan.headingLevel}', text: plan.heading),
        if (id != null) _workflowPlaceholder(plan),
        SeoNode(
          tag: 'p',
          attributes: const {'class': 'esen-seo-editorial-workflow-status'},
          children: [
            SeoNode(tag: 'strong', text: '${plan.statusLabel}: '),
            SeoNode(
              tag: 'span',
              text: view.statusText,
              attributes: {
                if (id != null) 'data-esen-workflow-status-text': '',
              },
            ),
          ],
        ),
        SeoNode(
          tag: 'p',
          children: [
            SeoNode(
              tag: 'span',
              text: view.summaryText,
              attributes: {
                if (id != null) 'data-esen-workflow-summary': '',
              },
            ),
          ],
        ),
        SeoNode(
          tag: 'ol',
          attributes: {
            'class': 'esen-seo-editorial-workflow-progress',
            'aria-label': plan.progressLabel,
            if (id != null) 'data-esen-workflow-progress': '',
          },
          children: [
            for (final stage in SeoEditorialWorkflowStage.values)
              SeoNode(
                tag: 'li',
                text: plan.stages[stage.index].label,
                attributes: {
                  if (id != null)
                    'data-esen-workflow-progress-stage': '${stage.index}',
                  if (stage == state.stage) ...{
                    'aria-current': 'step',
                    if (id != null) 'data-esen-initial-current': 'true',
                  },
                },
              ),
          ],
        ),
        for (final stage in SeoEditorialWorkflowStage.values)
          SeoNode(
            tag: 'section',
            attributes: {
              if (id != null) ...{
                'id': '$id-stage-${stage.index}',
                'data-esen-workflow-stage-region': '${stage.index}',
                if (stage == state.stage) 'data-esen-initial-active': 'true',
              },
            },
            children: [
              SeoNode(
                tag: 'h$sectionLevel',
                text: plan.stages[stage.index].label,
                attributes: {
                  if (id != null) 'data-esen-workflow-stage-name': '',
                },
              ),
              ...plan.stages[stage.index].nodes,
            ],
          ),
        SeoNode(tag: 'h$sectionLevel', text: plan.historyLabel),
        SeoNode(
          tag: 'ol',
          attributes: {
            'class': 'esen-seo-editorial-workflow-history',
            if (id != null) 'data-esen-workflow-history': '',
          },
          children: [
            for (final stage in state.history)
              SeoNode(
                tag: 'li',
                text: plan.stages[stage.index].label,
                attributes: {
                  if (id != null)
                    'data-esen-workflow-history-stage': '${stage.index}',
                },
              ),
          ],
        ),
        if (id != null)
          SeoNode(
            tag: 'span',
            attributes: const {
              'class': 'esen-seo-editorial-workflow-announcement',
              'data-esen-workflow-announcement': '',
              'aria-live': 'polite',
              'aria-atomic': 'true',
            },
          ),
      ],
    ),
  ];
}

SeoNode _workflowPlaceholder(SeoEditorialWorkflowComponentPlan plan) => SeoNode(
      tag: 'div',
      attributes: const {
        'class': 'esen-seo-editorial-workflow-controls',
        'data-esen-prepaint-placeholder': 'editorial-workflow',
        'hidden': '',
        'aria-hidden': 'true',
      },
      children: [
        for (final (action, label) in [
          (const SeoEditorialWorkflowSubmit(), plan.submitLabel),
          (const SeoEditorialWorkflowApprove(), plan.approveLabel),
          (const SeoEditorialWorkflowReject(), plan.rejectLabel),
          (const SeoEditorialWorkflowPublish(), plan.publishLabel),
        ])
          SeoNode(
            tag: 'span',
            text: label,
            attributes: {
              'class': 'esen-seo-editorial-workflow-control-placeholder',
              if (!isSeoEditorialWorkflowActionEnabled(
                plan.initial.state,
                action,
              ))
                'data-esen-placeholder-disabled': 'true',
            },
          ),
      ],
    );
