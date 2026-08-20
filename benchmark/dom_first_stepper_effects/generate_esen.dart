import 'dart:io';

import 'package:esen_seo/server.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.length != 1) {
    stderr.writeln(
      'Usage: dart run benchmark/dom_first_stepper_effects/'
      'generate_esen.dart OUT',
    );
    exitCode = 64;
    return;
  }
  final css = await File(
    'benchmark/dom_first_stepper_effects/fixtures/shared.css',
  ).readAsString();
  const runtimeReference = SeoDomFirstApplicationRuntime.stepperEffects(
    'benchmark-stepper-effects',
  );
  final runtime = await SeoDirectoryRuntimeStore(
    'benchmark/dom_first_stepper_effects/fixtures/application/'
    'build/esen_seo/runtimes',
  ).load(runtimeReference);
  final html = SeoPage.domFirstFromNodes(
    meta: const SeoMeta(title: 'Stepper effects benchmark'),
    body: _body,
    stylesheet: css,
    applicationRuntime: runtime,
  ).toHtmlDocument();
  final output = File(arguments.single);
  await output.parent.create(recursive: true);
  await output.writeAsString(html);
}

final List<SeoNode> _body = [
  SeoNode(tag: 'main', children: [
    SeoNode(tag: 'h1', text: 'Publishing flow'),
    SeoNode(
      tag: 'p',
      text: 'One pure transition selects a complete step and then focuses '
          'its panel.',
    ),
    ...buildSeoStepperNodes(
      headingLevel: 2,
      interactionId: 'benchmark-stepper',
      interactionLabel: 'Publishing flow',
      steps: _steps,
    ),
  ]),
];

final List<SeoStepperComponentEntry> _steps = [
  (
    label: 'Draft',
    nodes: [
      SeoNode(tag: 'p', text: 'Write the complete article before review.'),
    ],
  ),
  (
    label: 'Review',
    nodes: [
      SeoNode(tag: 'p', text: 'Check facts, links and the semantic outline.'),
    ],
  ),
  (
    label: 'Publish',
    nodes: [
      SeoNode(
        tag: 'p',
        text: 'Release the approved document to every reader.',
      ),
    ],
  ),
];
