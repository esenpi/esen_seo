/// Server-side half of esen_seo: bot detection and semantic HTML
/// delivery for a shelf server.
///
/// Pure Dart without any Flutter imports — runs with `dart run`, in
/// Docker or on any Dart-capable host. Bots get real semantic HTML
/// straight in the page source, real users get the Flutter web app:
///
/// ```dart
/// import 'package:esen_seo/server.dart';
/// import 'package:shelf/shelf.dart';
/// import 'package:shelf/shelf_io.dart' as io;
///
/// import '../lib/seo_routes.dart'; // dieselbe Tabelle wie die App
///
/// void main() async {
///   final handler = const Pipeline()
///       .addMiddleware(seoBotMiddleware(
///         routes: seoRoutes,
///         siteBase: 'https://example.com',
///       ))
///       .addHandler(flutterAppHandler);
///   await io.serve(handler, 'localhost', 8080);
/// }
/// ```
///
/// [SeoMeta], [SeoSchema], [SeoNode], [SeoRoute] and [HtmlRenderer] are
/// shared with the Flutter side, so head and body render identically in
/// both worlds.
library;

export 'audit.dart';
export 'core.dart';
export 'src/server/bot_detector.dart';
export 'src/server/indexnow.dart';
export 'src/server/llms_txt.dart';
export 'src/server/prerender.dart';
export 'src/server/redirects.dart';
export 'src/server/seo_middleware.dart';
export 'src/server/seo_page.dart';
export 'src/server/seo_runtime_store.dart';
export 'src/server/sitemap.dart';
