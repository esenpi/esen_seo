/// Pure-Dart core of esen_seo — no Flutter, no shelf.
///
/// Import this in files shared between the Flutter app and the SSR
/// server, e.g. the SEO route table:
///
/// ```dart
/// // lib/seo_routes.dart — imported by main.dart AND bin/server.dart
/// import 'package:esen_seo/core.dart';
///
/// final seoRoutes = [
///   SeoRoute(path: '/', meta: (_) => SeoMeta(title: 'Home')),
/// ];
/// ```
///
/// The full Flutter API lives in `package:esen_seo/esen_seo.dart`,
/// the server API in `package:esen_seo/server.dart` — both re-export
/// this core.
library;

export 'src/meta/seo_meta.dart';
export 'src/meta/seo_schema.dart';
export 'src/renderer/html_renderer.dart';
export 'src/renderer/seo_node.dart';
export 'src/routing/seo_route.dart';
