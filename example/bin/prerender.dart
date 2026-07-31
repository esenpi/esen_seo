// Statisches Prerendering: bäckt die SEO-Routen-Tabelle nach dem Build
// direkt in build/web — für Hosting ohne Dart-Server (Firebase Hosting,
// GitHub Pages, jedes CDN). Kein Bot-Detection nötig: das semantische
// HTML steht für alle direkt im Quelltext.
//
//   flutter build web
//   dart run bin/prerender.dart
//   → build/web einfach statisch deployen
//
// Mit --visible wird das prerenderte HTML zum sichtbaren ersten Frame:
// Der Nutzer liest die Seite schon, bevor die Flutter-Engine geladen
// hat; sobald Flutter den ersten Frame zeichnet, übernimmt die App.
import 'dart:io';

import 'package:esen_seo/server.dart';
import 'package:example/seo_routes.dart';

Future<void> main(List<String> args) async {
  final visible = args.contains('--visible');
  final files = await prerenderSite(
    routes: seoRoutes,
    siteBase: siteBase,
    renderMode: visible ? SeoRenderMode.visibleShell : SeoRenderMode.seoOnly,
    stylesheet: visible ? seoDefaultStylesheet : null,
  );
  stdout.writeln('Prerendered ${files.length} files:');
  for (final file in files) {
    stdout.writeln('  $file');
  }
}
