import 'dart:io';

import 'package:esen_dom_first_runtime_bundle_flutter_baseline/benchmark_data.dart';
import 'package:esen_seo/server.dart';

Future<void> main() async {
  final css = await File('../shared.css').readAsString();
  await prerenderSite(
    routes: [
      SeoRoute(
        path: '/',
        meta: (_) => const SeoMeta(title: 'Runtime bundle benchmark'),
        body: (_) => benchmarkBodyNodes,
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
