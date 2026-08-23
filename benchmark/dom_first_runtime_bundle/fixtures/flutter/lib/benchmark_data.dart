import 'package:esen_seo/core.dart';

const benchmarkTabs = [
  (label: 'Overview', content: 'The page starts as complete HTML.'),
  (
    label: 'Architecture',
    content: 'Pure Dart owns every state transition.',
  ),
  (
    label: 'Delivery',
    content: 'One verified artifact enhances the route.',
  ),
];

const benchmarkSlides = [
  (
    label: 'Semantic source',
    content: 'Every slide exists before JavaScript.',
  ),
  (
    label: 'Verified runtime',
    content: 'The manifest binds code and member kinds.',
  ),
  (
    label: 'Native parity',
    content: 'Flutter calls the same Carousel transition.',
  ),
];

const benchmarkSteps = [
  (label: 'Draft', content: 'Write the complete article before review.'),
  (
    label: 'Review',
    content: 'Check facts, links and semantic structure.',
  ),
  (
    label: 'Publish',
    content: 'Release the approved document to readers.',
  ),
];

final List<SeoNode> benchmarkBodyNodes = [
  SeoNode(tag: 'main', children: [
    SeoNode(tag: 'h1', text: 'Application runtime bundle'),
    SeoNode(
      tag: 'p',
      text: 'Three independent pure transitions enhance one complete page.',
    ),
    SeoNode(tag: 'h2', text: 'Rendering modes'),
    ...buildSeoTabsNodes(
      headingLevel: 3,
      interactionId: 'benchmark-tabs',
      interactionLabel: 'Rendering modes',
      tabs: [
        for (final item in benchmarkTabs)
          (
            label: item.label,
            nodes: [SeoNode(tag: 'p', text: item.content)],
          ),
      ],
    ),
    SeoNode(tag: 'h2', text: 'Delivery stages'),
    ...buildSeoCarouselNodes(
      headingLevel: 3,
      interactionId: 'benchmark-carousel',
      interactionLabel: 'Delivery stages',
      slides: [
        for (final item in benchmarkSlides)
          (
            label: item.label,
            nodes: [SeoNode(tag: 'p', text: item.content)],
          ),
      ],
    ),
    SeoNode(tag: 'h2', text: 'Publishing flow'),
    ...buildSeoStepperNodes(
      headingLevel: 3,
      interactionId: 'benchmark-stepper',
      interactionLabel: 'Publishing flow',
      steps: [
        for (final item in benchmarkSteps)
          (
            label: item.label,
            nodes: [SeoNode(tag: 'p', text: item.content)],
          ),
      ],
    ),
  ]),
];
