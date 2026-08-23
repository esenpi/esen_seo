import 'dart:io';

import 'package:esen_seo/server.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.length != 1) {
    stderr.writeln(
      'Usage: dart run benchmark/dom_first_runtime_bundle/'
      'generate_esen.dart OUT',
    );
    exitCode = 64;
    return;
  }
  final css = await File(
    'benchmark/dom_first_runtime_bundle/fixtures/shared.css',
  ).readAsString();
  final reference = SeoDomFirstApplicationRuntime.bundle(
    'benchmark-page',
    members: const {
      SeoDomFirstApplicationRuntimeKind.tabs,
      SeoDomFirstApplicationRuntimeKind.carousel,
      SeoDomFirstApplicationRuntimeKind.stepperEffects,
    },
  );
  final runtime = await SeoDirectoryRuntimeStore(
    'benchmark/dom_first_runtime_bundle/fixtures/application/'
    'build/esen_seo/runtimes',
  ).load(reference);
  final html = SeoPage.domFirstFromNodes(
    meta: const SeoMeta(title: 'Runtime bundle benchmark'),
    body: benchmarkBodyNodes,
    stylesheet: css,
    applicationRuntime: runtime,
  ).toHtmlDocument();
  final output = File(arguments.single);
  await output.parent.create(recursive: true);
  await output.writeAsString(html);
}

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
      tabs: _tabs,
    ),
    SeoNode(tag: 'h2', text: 'Delivery stages'),
    ...buildSeoCarouselNodes(
      headingLevel: 3,
      interactionId: 'benchmark-carousel',
      interactionLabel: 'Delivery stages',
      slides: _slides,
    ),
    SeoNode(tag: 'h2', text: 'Publishing flow'),
    ...buildSeoStepperNodes(
      headingLevel: 3,
      interactionId: 'benchmark-stepper',
      interactionLabel: 'Publishing flow',
      steps: _steps,
    ),
  ]),
];

final List<SeoTabComponentEntry> _tabs = [
  (
    label: 'Overview',
    nodes: [SeoNode(tag: 'p', text: 'The page starts as complete HTML.')],
  ),
  (
    label: 'Architecture',
    nodes: [SeoNode(tag: 'p', text: 'Pure Dart owns every state transition.')],
  ),
  (
    label: 'Delivery',
    nodes: [
      SeoNode(tag: 'p', text: 'One verified artifact enhances the route.')
    ],
  ),
];

final List<SeoCarouselComponentEntry> _slides = [
  (
    label: 'Semantic source',
    nodes: [SeoNode(tag: 'p', text: 'Every slide exists before JavaScript.')],
  ),
  (
    label: 'Verified runtime',
    nodes: [
      SeoNode(tag: 'p', text: 'The manifest binds code and member kinds.')
    ],
  ),
  (
    label: 'Native parity',
    nodes: [
      SeoNode(tag: 'p', text: 'Flutter calls the same Carousel transition.')
    ],
  ),
];

final List<SeoStepperComponentEntry> _steps = [
  (
    label: 'Draft',
    nodes: [
      SeoNode(tag: 'p', text: 'Write the complete article before review.')
    ],
  ),
  (
    label: 'Review',
    nodes: [
      SeoNode(tag: 'p', text: 'Check facts, links and semantic structure.')
    ],
  ),
  (
    label: 'Publish',
    nodes: [
      SeoNode(tag: 'p', text: 'Release the approved document to readers.')
    ],
  ),
];
