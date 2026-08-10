import 'dart:io';

import 'package:esen_seo/server.dart';
import 'package:example/seo_routes.dart';

Future<void> main() async {
  final page = SeoPage.visibleFromNodes(
    meta: const SeoMeta(
      title: 'Progressive tabs - esen_seo',
      description: 'One tab model rendered as complete HTML and enhanced with '
          'package-owned JavaScript.',
    ),
    body: [
      SeoNode(tag: 'h1', text: 'Progressive tabs'),
      SeoNode(
        tag: 'p',
        text: 'Disable JavaScript and every panel remains readable.',
      ),
      ...buildSeoTabsNodes(
        tabs: demoTabEntries(),
        interactionId: 'demo-tabs',
        interactionLabel: 'Rendering targets',
      ),
    ],
  );

  final output = File('build/interactive-tabs.html');
  await output.parent.create(recursive: true);
  await output.writeAsString(page.toHtmlDocument());
  stdout.writeln('Wrote ${output.path}');
}
