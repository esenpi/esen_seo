import 'dart:io';

import 'package:esen_seo/server.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.length != 1) {
    stderr
        .writeln('Usage: dart run benchmark/dom_first/generate_esen.dart OUT');
    exitCode = 64;
    return;
  }
  final css =
      await File('benchmark/dom_first/fixtures/shared.css').readAsString();
  final body = [
    SeoNode(tag: 'main', children: [
      SeoNode(tag: 'h1', text: 'Rendering targets'),
      SeoNode(
        tag: 'p',
        text:
            'One data model, three complete panels and accessible tab controls.',
      ),
      ...buildSeoTabsNodes(
        headingLevel: 2,
        interactionId: 'benchmark-tabs',
        interactionLabel: 'Rendering targets',
        tabs: [
          (
            label: 'Flutter',
            nodes: [
              SeoNode(
                  tag: 'p',
                  text:
                      'The same data renders as a native Flutter tab on every platform.')
            ],
          ),
          (
            label: 'HTML',
            nodes: [
              SeoNode(
                  tag: 'p',
                  text:
                      'Every panel is present as semantic HTML before JavaScript runs.')
            ],
          ),
          (
            label: 'JavaScript',
            nodes: [
              SeoNode(
                  tag: 'p',
                  text:
                      'The visible web page gains accessible tab controls after validation.')
            ],
          ),
        ],
      ),
    ]),
  ];
  final html = SeoPage.domFirstFromNodes(
    meta: const SeoMeta(title: 'Tabs benchmark'),
    body: body,
    stylesheet: css,
    features: const {SeoDomFirstFeature.tabs},
  ).toHtmlDocument();
  final output = File(arguments.single);
  await output.parent.create(recursive: true);
  await output.writeAsString(html);
}
