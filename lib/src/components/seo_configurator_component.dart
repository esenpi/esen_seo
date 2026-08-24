/// Pure semantic component builder for the curated configurator slice.
library;

import '../renderer/seo_node.dart';
import 'seo_component_format.dart';
import 'seo_configurator_transition.dart';

/// Pure input for one package-owned configurator choice.
typedef SeoConfiguratorComponentChoice = ({
  String label,
  List<SeoNode> nodes,
});

/// Maximum raw UTF-16 length of one fixed component label.
const int seoConfiguratorMaxLabelTextLength = 128;

/// Maximum raw UTF-16 length of all fixed component labels together.
const int seoConfiguratorMaxAggregateLabelTextLength = 4096;

/// Fully validated initial presentation shared by the builder and Flutter.
///
/// This remains an internal admission plan. It contains fixed package fields,
/// not a vocabulary for application-selected elements or mutations.
final class SeoConfiguratorComponentPlan {
  SeoConfiguratorComponentPlan._({
    required this.choices,
    required this.optionNodes,
    required this.constraints,
    required this.initial,
    required this.interactionId,
    required this.headingLevel,
    required this.heading,
    required this.interactionLabel,
    required this.choiceGroupLabel,
    required this.quantityLabel,
    required this.optionLabel,
    required this.priceLabel,
    required this.decrementLabel,
    required this.incrementLabel,
  });

  final List<SeoConfiguratorComponentChoice> choices;
  final List<SeoNode> optionNodes;
  final SeoConfiguratorConstraints constraints;
  final SeoConfiguratorEvaluation initial;
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
}

/// Validates and canonicalizes the complete initial component input.
///
/// `null` keeps both platform presentations inert. An invalid interaction id
/// does not discard valid content; it produces a static, unmarked component.
SeoConfiguratorComponentPlan? prepareSeoConfiguratorComponent({
  required List<SeoConfiguratorComponentChoice> choices,
  required List<SeoNode> optionNodes,
  required SeoConfiguratorConstraints constraints,
  required SeoConfiguratorState initialState,
  required SeoConfiguratorViewProjection project,
  String? interactionId,
  int headingLevel = 2,
  String heading = 'Configure your plan',
  String interactionLabel = 'Pricing configurator',
  String choiceGroupLabel = 'Plan',
  String quantityLabel = 'Quantity',
  String optionLabel = 'Additional option',
  String priceLabel = 'Estimated price',
  String decrementLabel = 'Decrease quantity',
  String incrementLabel = 'Increase quantity',
}) {
  if (!isValidSeoConfiguratorConstraints(constraints) ||
      choices.length != constraints.choiceCount) {
    return null;
  }

  final rawLabels = <String>[
    heading,
    interactionLabel,
    choiceGroupLabel,
    quantityLabel,
    optionLabel,
    priceLabel,
    decrementLabel,
    incrementLabel,
    for (final choice in choices) choice.label,
  ];
  var aggregateLength = 0;
  for (final label in rawLabels) {
    aggregateLength += label.length;
    if (aggregateLength > seoConfiguratorMaxAggregateLabelTextLength) {
      return null;
    }
  }

  final labels = <String>[];
  for (final label in rawLabels) {
    final value = canonicalizeSeoConfiguratorText(
      label,
      maxLength: seoConfiguratorMaxLabelTextLength,
    );
    if (value == null) return null;
    labels.add(value.trim());
  }
  final choiceLabels = labels.skip(8).toList(growable: false);
  if (choiceLabels.toSet().length != choiceLabels.length) return null;

  final initial = evaluateInitialSeoConfiguratorView(
    project,
    initialState,
    constraints,
  );
  if (initial == null) return null;

  final candidate = interactionId?.trim();
  final id = candidate != null && isValidSeoInteractionId(candidate)
      ? candidate
      : null;
  var labelIndex = 0;
  return SeoConfiguratorComponentPlan._(
    choices: List.unmodifiable([
      for (final (index, choice) in choices.indexed)
        (
          label: labels[8 + index],
          nodes: List<SeoNode>.unmodifiable(choice.nodes),
        ),
    ]),
    optionNodes: List<SeoNode>.unmodifiable(optionNodes),
    constraints: constraints,
    initial: initial,
    interactionId: id,
    headingLevel: headingLevel.clamp(1, 6),
    heading: labels[labelIndex++],
    interactionLabel: labels[labelIndex++],
    choiceGroupLabel: labels[labelIndex++],
    quantityLabel: labels[labelIndex++],
    optionLabel: labels[labelIndex++],
    priceLabel: labels[labelIndex++],
    decrementLabel: labels[labelIndex++],
    incrementLabel: labels[labelIndex++],
  );
}

/// Builds the complete no-script semantic source for a configurator.
///
/// Every choice and the option description remain visible without JavaScript.
/// A valid [interactionId] adds only inert, package-owned markers and a hidden
/// geometry placeholder. No application value can name an element, attribute,
/// class, selector or focus destination.
List<SeoNode> buildSeoConfiguratorNodes({
  required List<SeoConfiguratorComponentChoice> choices,
  required List<SeoNode> optionNodes,
  required SeoConfiguratorConstraints constraints,
  required SeoConfiguratorState initialState,
  required SeoConfiguratorViewProjection project,
  String? interactionId,
  int headingLevel = 2,
  String heading = 'Configure your plan',
  String interactionLabel = 'Pricing configurator',
  String choiceGroupLabel = 'Plan',
  String quantityLabel = 'Quantity',
  String optionLabel = 'Additional option',
  String priceLabel = 'Estimated price',
  String decrementLabel = 'Decrease quantity',
  String incrementLabel = 'Increase quantity',
}) {
  final plan = prepareSeoConfiguratorComponent(
    choices: choices,
    optionNodes: optionNodes,
    constraints: constraints,
    initialState: initialState,
    project: project,
    interactionId: interactionId,
    headingLevel: headingLevel,
    heading: heading,
    interactionLabel: interactionLabel,
    choiceGroupLabel: choiceGroupLabel,
    quantityLabel: quantityLabel,
    optionLabel: optionLabel,
    priceLabel: priceLabel,
    decrementLabel: decrementLabel,
    incrementLabel: incrementLabel,
  );
  if (plan == null) return const [];
  return buildSeoConfiguratorPlanNodes(plan);
}

/// Serializes an already validated component plan without re-projecting state.
List<SeoNode> buildSeoConfiguratorPlanNodes(
  SeoConfiguratorComponentPlan plan,
) {
  final id = plan.interactionId;
  final state = plan.initial.state;
  final view = plan.initial.view;
  final sectionLevel = (plan.headingLevel + 1).clamp(1, 6);
  return [
    SeoNode(
      tag: 'section',
      attributes: {
        'class': 'esen-seo-configurator',
        if (id != null) ...{
          'id': id,
          'data-esen-component': 'configurator',
          'data-esen-layout-stable': 'true',
          'data-esen-label': plan.interactionLabel,
          'data-esen-choice-label': plan.choiceGroupLabel,
          'data-esen-quantity-label': plan.quantityLabel,
          'data-esen-option-label': plan.optionLabel,
          'data-esen-decrement-label': plan.decrementLabel,
          'data-esen-increment-label': plan.incrementLabel,
          'data-esen-min-quantity': '${plan.constraints.minQuantity}',
          'data-esen-max-quantity': '${plan.constraints.maxQuantity}',
          'data-esen-initial-choice': '${state.choiceIndex}',
          'data-esen-initial-quantity': '${state.quantity}',
          'data-esen-initial-option': '${state.optionEnabled}',
        },
      },
      children: [
        SeoNode(tag: 'h${plan.headingLevel}', text: plan.heading),
        if (id != null) _buildConfiguratorPlaceholder(plan),
        SeoNode(
          tag: 'p',
          attributes: const {'class': 'esen-seo-configurator-price'},
          children: [
            SeoNode(tag: 'strong', text: '${plan.priceLabel}: '),
            SeoNode(
              tag: 'span',
              text: view.priceText,
              attributes: {
                if (id != null) 'data-esen-configurator-price': '',
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
                if (id != null) 'data-esen-configurator-summary': '',
              },
            ),
          ],
        ),
        SeoNode(tag: 'h$sectionLevel', text: plan.choiceGroupLabel),
        for (var index = 0; index < plan.choices.length; index++)
          SeoNode(
            tag: 'section',
            attributes: {
              if (id != null) ...{
                'id': '$id-choice-$index',
                'data-esen-configurator-choice-region': '$index',
                if (index == state.choiceIndex)
                  'data-esen-initial-active': 'true',
              },
            },
            children: [
              SeoNode(
                tag: 'h$sectionLevel',
                text: plan.choices[index].label,
                attributes: {
                  if (id != null) 'data-esen-configurator-choice-name': '',
                },
              ),
              ...plan.choices[index].nodes,
            ],
          ),
        SeoNode(
          tag: 'section',
          attributes: {
            if (id != null) ...{
              'id': '$id-option',
              'data-esen-configurator-option-region': '',
              if (state.optionEnabled) 'data-esen-initial-visible': 'true',
            },
          },
          children: [
            SeoNode(tag: 'h$sectionLevel', text: plan.optionLabel),
            ...plan.optionNodes,
          ],
        ),
        if (id != null)
          SeoNode(
            tag: 'span',
            attributes: const {
              'class': 'esen-seo-configurator-status',
              'data-esen-configurator-status': '',
              'aria-live': 'polite',
              'aria-atomic': 'true',
            },
          ),
      ],
    ),
  ];
}

SeoNode _buildConfiguratorPlaceholder(SeoConfiguratorComponentPlan plan) {
  final state = plan.initial.state;
  return SeoNode(
    tag: 'div',
    attributes: const {
      'class': 'esen-seo-configurator-controls',
      'data-esen-prepaint-placeholder': 'configurator',
      'hidden': '',
      'aria-hidden': 'true',
    },
    children: [
      SeoNode(
        tag: 'div',
        attributes: const {'class': 'esen-seo-configurator-choices'},
        children: [
          for (var index = 0; index < plan.choices.length; index++)
            SeoNode(
              tag: 'span',
              text: plan.choices[index].label,
              attributes: {
                'class': 'esen-seo-configurator-control-placeholder',
                if (index == state.choiceIndex)
                  'data-esen-placeholder-selected': 'true',
              },
            ),
        ],
      ),
      SeoNode(
        tag: 'div',
        attributes: const {'class': 'esen-seo-configurator-quantity'},
        children: [
          SeoNode(
            tag: 'span',
            text: plan.decrementLabel,
            attributes: {
              'class': 'esen-seo-configurator-control-placeholder',
              if (state.quantity == plan.constraints.minQuantity)
                'data-esen-placeholder-disabled': 'true',
            },
          ),
          SeoNode(
            tag: 'span',
            text: '${state.quantity}',
            attributes: const {
              'class': 'esen-seo-configurator-quantity-value',
            },
          ),
          SeoNode(
            tag: 'span',
            text: plan.incrementLabel,
            attributes: {
              'class': 'esen-seo-configurator-control-placeholder',
              if (state.quantity == plan.constraints.maxQuantity)
                'data-esen-placeholder-disabled': 'true',
            },
          ),
        ],
      ),
      SeoNode(
        tag: 'span',
        text: plan.optionLabel,
        attributes: {
          'class': 'esen-seo-configurator-control-placeholder',
          if (state.optionEnabled) 'data-esen-placeholder-selected': 'true',
        },
      ),
    ],
  );
}
