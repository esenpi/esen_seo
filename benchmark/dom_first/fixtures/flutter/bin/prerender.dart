import 'dart:io';

import 'package:esen_seo/server.dart';

Future<void> main() async {
  final css = await File('../shared.css').readAsString();
  await prerenderSite(
    routes: [
      SeoRoute(
        path: '/',
        meta: (_) => const SeoMeta(title: 'Tabs benchmark'),
        body: (_) => [
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
        ],
      ),
    ],
    siteBase: 'http://127.0.0.1',
    renderMode: SeoRenderMode.visibleShell,
    stylesheet: css,
    enableInteractions: true,
    writeSitemap: false,
    writeRobotsTxt: false,
    writeLlmsTxt: false,
    write404Page: false,
  );
}
