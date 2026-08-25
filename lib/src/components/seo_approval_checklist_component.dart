/// Pure semantic builder for the curated approval checklist slice.
library;

import '../renderer/seo_node.dart';
import 'seo_approval_checklist_transition.dart';
import 'seo_component_format.dart';
import 'seo_configurator_transition.dart' show canonicalizeSeoConfiguratorText;

typedef SeoApprovalChecklistItemEntry = ({
  String label,
  List<SeoNode> nodes,
});

const int seoApprovalChecklistMaxLabelTextLength = 128;
const int seoApprovalChecklistMaxAggregateLabelTextLength = 4096;

final class SeoApprovalChecklistComponentPlan {
  SeoApprovalChecklistComponentPlan._({
    required this.items,
    required this.initial,
    required this.interactionId,
    required this.headingLevel,
    required this.heading,
    required this.interactionLabel,
    required this.statusLabel,
    required this.progressLabel,
  });

  final List<SeoApprovalChecklistItemEntry> items;
  final SeoApprovalChecklistEvaluation initial;
  final String? interactionId;
  final int headingLevel;
  final String heading;
  final String interactionLabel;
  final String statusLabel;
  final String progressLabel;
}

SeoApprovalChecklistComponentPlan? prepareSeoApprovalChecklistComponent({
  required List<SeoApprovalChecklistItemEntry> items,
  required SeoApprovalChecklistState initialState,
  required SeoApprovalChecklistViewProjection project,
  String? interactionId,
  int headingLevel = 2,
  String heading = 'Approval checklist',
  String interactionLabel = 'Approval checklist controls',
  String statusLabel = 'Status',
  String progressLabel = 'Progress',
}) {
  if (items.isEmpty || items.length > seoApprovalChecklistMaxItems) return null;
  final rawLabels = <String>[
    heading,
    interactionLabel,
    statusLabel,
    progressLabel,
    for (final item in items) item.label,
  ];
  if (rawLabels.fold<int>(0, (sum, label) => sum + label.length) >
      seoApprovalChecklistMaxAggregateLabelTextLength) {
    return null;
  }
  final labels = <String>[];
  for (final raw in rawLabels) {
    final label = canonicalizeSeoConfiguratorText(
      raw,
      maxLength: seoApprovalChecklistMaxLabelTextLength,
    );
    if (label == null) return null;
    labels.add(label.trim());
  }
  final itemLabels = labels.skip(4).toList(growable: false);
  if (itemLabels.toSet().length != itemLabels.length) return null;
  final initial = evaluateInitialSeoApprovalChecklistView(
    project,
    initialState,
    itemCount: items.length,
  );
  if (initial == null) return null;
  final candidateId = interactionId?.trim();
  final id = candidateId != null && isValidSeoInteractionId(candidateId)
      ? candidateId
      : null;
  return SeoApprovalChecklistComponentPlan._(
    items: List.unmodifiable([
      for (final (index, item) in items.indexed)
        (
          label: itemLabels[index],
          nodes: List<SeoNode>.unmodifiable(item.nodes),
        ),
    ]),
    initial: initial,
    interactionId: id,
    headingLevel: headingLevel.clamp(1, 6),
    heading: labels[0],
    interactionLabel: labels[1],
    statusLabel: labels[2],
    progressLabel: labels[3],
  );
}

List<SeoNode> buildSeoApprovalChecklistNodes({
  required List<SeoApprovalChecklistItemEntry> items,
  required SeoApprovalChecklistState initialState,
  required SeoApprovalChecklistViewProjection project,
  String? interactionId,
  int headingLevel = 2,
  String heading = 'Approval checklist',
  String interactionLabel = 'Approval checklist controls',
  String statusLabel = 'Status',
  String progressLabel = 'Progress',
}) {
  final plan = prepareSeoApprovalChecklistComponent(
    items: items,
    initialState: initialState,
    project: project,
    interactionId: interactionId,
    headingLevel: headingLevel,
    heading: heading,
    interactionLabel: interactionLabel,
    statusLabel: statusLabel,
    progressLabel: progressLabel,
  );
  return plan == null ? const [] : buildSeoApprovalChecklistPlanNodes(plan);
}

List<SeoNode> buildSeoApprovalChecklistPlanNodes(
  SeoApprovalChecklistComponentPlan plan,
) {
  final id = plan.interactionId;
  final state = plan.initial.state;
  final view = plan.initial.view;
  final checkedCount = seoApprovalChecklistCheckedCount(state);
  final itemLevel = (plan.headingLevel + 1).clamp(1, 6);
  return [
    SeoNode(
      tag: 'section',
      attributes: {
        'class': 'esen-seo-approval-checklist',
        if (id != null) ...{
          'id': id,
          'data-esen-component': 'approval-checklist',
          'data-esen-layout-stable': 'true',
          'data-esen-label': plan.interactionLabel,
          'data-esen-status-label': plan.statusLabel,
          'data-esen-progress-label': plan.progressLabel,
          'data-esen-initial-checked':
              state.checked.map((checked) => checked ? '1' : '0').join(','),
        },
      },
      children: [
        SeoNode(tag: 'h${plan.headingLevel}', text: plan.heading),
        if (id != null) _checklistPlaceholder(plan),
        SeoNode(
          tag: 'p',
          attributes: const {'class': 'esen-seo-approval-checklist-status'},
          children: [
            SeoNode(tag: 'strong', text: '${plan.statusLabel}: '),
            SeoNode(
              tag: 'span',
              text: view.statusText,
              attributes: {
                if (id != null) 'data-esen-checklist-status-text': '',
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
                if (id != null) 'data-esen-checklist-summary': '',
              },
            ),
          ],
        ),
        SeoNode(
          tag: 'div',
          attributes: {
            'class': 'esen-seo-approval-checklist-progress',
            'role': 'progressbar',
            'aria-label': plan.progressLabel,
            'aria-valuemin': '0',
            'aria-valuemax': '${plan.items.length}',
            'aria-valuenow': '$checkedCount',
            if (id != null) 'data-esen-checklist-progress': '',
          },
          children: [
            SeoNode(
              tag: 'span',
              text: '$checkedCount / ${plan.items.length}',
              attributes: {
                if (id != null) 'data-esen-checklist-progress-text': '',
              },
            ),
          ],
        ),
        SeoNode(
          tag: 'ul',
          attributes: const {'class': 'esen-seo-approval-checklist-items'},
          children: [
            for (final (index, item) in plan.items.indexed)
              SeoNode(
                tag: 'li',
                attributes: {
                  if (id != null) ...{
                    'data-esen-checklist-item': '$index',
                    'data-esen-initial-checked':
                        state.checked[index] ? 'true' : 'false',
                  },
                },
                children: [
                  SeoNode(
                    tag: 'h$itemLevel',
                    text: item.label,
                    attributes: {
                      if (id != null) ...{
                        'id': '$id-item-$index-label',
                        'data-esen-checklist-item-label': '',
                      },
                    },
                  ),
                  ...item.nodes,
                ],
              ),
          ],
        ),
        if (id != null)
          SeoNode(
            tag: 'span',
            attributes: const {
              'class': 'esen-seo-approval-checklist-announcement',
              'data-esen-checklist-announcement': '',
              'aria-live': 'polite',
              'aria-atomic': 'true',
            },
          ),
      ],
    ),
  ];
}

SeoNode _checklistPlaceholder(SeoApprovalChecklistComponentPlan plan) =>
    SeoNode(
      tag: 'div',
      attributes: const {
        'class': 'esen-seo-approval-checklist-controls',
        'data-esen-prepaint-placeholder': 'approval-checklist',
        'hidden': '',
        'aria-hidden': 'true',
      },
      children: [
        for (final (index, item) in plan.items.indexed)
          SeoNode(
            tag: 'span',
            text: item.label,
            attributes: {
              'class': 'esen-seo-approval-checklist-control-placeholder',
              'data-esen-placeholder-checked':
                  plan.initial.state.checked[index] ? 'true' : 'false',
            },
          ),
      ],
    );
