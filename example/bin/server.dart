// SSR server for the example app: bots get semantic HTML straight in the
// page source, real users get the Flutter web app.
//
//   flutter build web --pwa-strategy=none
//   dart run bin/server.dart
//
//   curl -A "Googlebot/2.1" http://localhost:8080        → semantisches HTML
//   curl -A "Googlebot/2.1" http://localhost:8080/demo   → Demo-Seite als HTML
//   curl -A "Googlebot/2.1" http://localhost:8080/nope   → echter 404
//   curl http://localhost:8080/sitemap.xml               → aus der Routen-Tabelle
//   curl http://localhost:8080/robots.txt                → mit Sitemap-Verweis
//   curl -A "Mozilla/5.0" http://localhost:8080          → Flutter App
import 'dart:io';

import 'package:esen_seo/server.dart';
import 'package:example/seo_routes.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_static/shelf_static.dart';

Future<void> main() async {
  final staticHandler = createStaticHandler(
    'build/web',
    defaultDocument: 'index.html',
  );

  final handler = const Pipeline()
      .addMiddleware(logRequests())
      // Dieselbe Routen-Tabelle wie die App (lib/seo_routes.dart):
      // Bots bekommen pro Route das fertige HTML-Dokument, dazu
      // sitemap.xml, robots.txt und echte 404er für unbekannte Pfade.
      .addMiddleware(seoBotMiddleware(
        routes: seoRoutes,
        siteBase: siteBase,
        domFirstRuntimeStore: SeoDirectoryRuntimeStore(
          'build/esen_seo/runtimes',
        ),
      ))
      .addHandler((request) async {
    final response = await staticHandler(request);
    // SPA-Fallback: Die App nutzt Path-URLs (cleanUrls). Unbekannte
    // Pfade wie /demo liefern die index.html, Flutter übernimmt dann
    // das Routing im Browser.
    if (response.statusCode == 404) {
      return staticHandler(
        Request('GET', request.requestedUri.replace(path: '/')),
      );
    }
    return response;
  });

  final server = await io.serve(handler, InternetAddress.anyIPv4, 8080);
  stdout.writeln('Serving on http://localhost:${server.port}');
}
