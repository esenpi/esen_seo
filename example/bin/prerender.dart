// Statisches Prerendering: bäckt die SEO-Routen-Tabelle nach dem Build
// direkt in build/web — für Hosting ohne Dart-Server (Firebase Hosting,
// GitHub Pages, jedes CDN). Kein Bot-Detection nötig: das semantische
// HTML steht für alle direkt im Quelltext.
//
//   flutter build web
//   dart run bin/prerender.dart
//   → build/web einfach statisch deployen
import 'dart:io';

import 'package:esen_seo/server.dart';
import 'package:example/seo_routes.dart';

Future<void> main() async {
  final files = await prerenderSite(routes: seoRoutes, siteBase: siteBase);
  stdout.writeln('Prerendered ${files.length} files:');
  for (final file in files) {
    stdout.writeln('  $file');
  }
}
