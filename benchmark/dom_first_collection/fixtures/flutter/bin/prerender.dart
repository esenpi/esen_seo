import 'dart:io';

import 'package:esen_seo/server.dart';
import 'package:esen_dom_first_collection_flutter_baseline/collection_data.dart';

Future<void> main() async {
  final css = await File('../shared.css').readAsString();
  await prerenderSite(
    routes: [
      SeoRoute(
        path: '/',
        meta: (_) => const SeoMeta(title: 'Collection history benchmark'),
        body: (_) => benchmarkBodyNodes(),
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
