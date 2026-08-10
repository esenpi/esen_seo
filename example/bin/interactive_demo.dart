import 'dart:io';

import 'package:esen_seo/server.dart';
import 'package:example/seo_routes.dart';

Future<void> main() async {
  final page = SeoPage.visibleFromNodes(
    meta: const SeoMeta(
      title: 'Progressive components - esen_seo',
      description: 'Navigation and tabs rendered as complete HTML and '
          'enhanced with package-owned JavaScript.',
    ),
    body: [
      SeoNode(tag: 'h1', text: 'Progressive components'),
      SeoNode(
        tag: 'p',
        text: 'Disable JavaScript and every link and panel remains readable.',
      ),
      SeoNode(tag: 'h2', text: 'Progressive navigation'),
      ...demoNavNodes(),
      SeoNode(tag: 'h2', text: 'Progressive tabs'),
      ...buildSeoTabsNodes(
        tabs: demoTabEntries(),
        interactionId: 'demo-tabs',
        interactionLabel: 'Rendering targets',
      ),
    ],
  );

  final output = File('build/interactive-components.html');
  await output.parent.create(recursive: true);
  await output.writeAsString(page.toHtmlDocument());
  stdout.writeln('Wrote ${output.path}');
}
