import 'dart:io';

import 'package:esen_seo/server.dart';

Future<void> main() async {
  final css = await File('../shared.css').readAsString();
  await prerenderSite(
    routes: [
      SeoRoute(
        path: '/',
        meta: (_) => const SeoMeta(title: 'Stepper effects benchmark'),
        body: (_) => _body,
      ),
    ],
    siteBase: 'http://127.0.0.1',
    renderMode: SeoRenderMode.visibleShell,
    stylesheet: css,
    enableInteractions: false,
    writeSitemap: false,
    writeRobotsTxt: false,
    writeLlmsTxt: false,
    write404Page: false,
  );
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
      steps: [
        (
          label: 'Draft',
          nodes: [
            SeoNode(
              tag: 'p',
              text: 'Write the complete article before review.',
            ),
          ],
        ),
        (
          label: 'Review',
          nodes: [
            SeoNode(
              tag: 'p',
              text: 'Check facts, links and the semantic outline.',
            ),
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
      ],
    ),
  ]),
];
