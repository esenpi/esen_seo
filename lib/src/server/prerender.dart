import 'dart:io';

import '../renderer/html_renderer.dart';
import '../renderer/seo_container.dart';
import '../routing/seo_route.dart';
import 'sitemap.dart';

/// Bakes the SEO route table into the built Flutter web app as static
/// HTML files — for hosting **without** a Dart server (Firebase
/// Hosting, GitHub Pages, any CDN).
///
/// For every route without `:param` segments (plus every concrete path
/// in [additionalPaths]) a copy of `index.html` is written to
/// `<path>/index.html`, containing:
///
/// - the route's title, meta tags, OpenGraph and JSON-LD in the
///   `<head>` — the template's `<title>` and `<meta name="description">`
///   are replaced,
/// - the semantic HTML body inside the hidden `#esen-seo-content`
///   container — the running app finds that container by id and simply
///   takes it over (hydration).
///
/// Because the content is baked into the files, **no bot detection is
/// needed**: crawlers, link previews and users all receive the same
/// file, and the semantic HTML is right in the page source. Deep links
/// like `/demo` work on static hosts too, since a real
/// `/demo/index.html` exists.
///
/// Also writes `sitemap.xml` and `robots.txt`. Returns the written file
/// paths.
///
/// ```dart
/// // bin/prerender.dart — nach jedem `flutter build web` ausführen:
/// await prerenderSite(routes: seoRoutes, siteBase: siteBase);
/// ```
///
/// Trade-off vs. the shelf server: prerendered pages are a build-time
/// snapshot — content changes require a redeploy, and `:param` routes
/// are only covered for the paths you enumerate. For frequently
/// changing content use `seoBotMiddleware` instead.
Future<List<String>> prerenderSite({
  required List<SeoRoute> routes,
  required String siteBase,
  String buildDir = 'build/web',
  List<String> additionalPaths = const [],
  bool writeSitemap = true,
  bool writeRobotsTxt = true,
}) async {
  final templateFile = File('$buildDir/index.html');
  if (!templateFile.existsSync()) {
    throw StateError(
      '$buildDir/index.html not found — run `flutter build web` first.',
    );
  }
  final template = await templateFile.readAsString();

  final paths = <String>[
    for (final route in routes)
      if (!route.hasParams) route.path,
    ...additionalPaths.map(normalizeSeoPath),
  ];

  final written = <String>[];
  for (final path in paths) {
    final match = matchSeoRoute(routes, path);
    if (match == null) continue;
    final html = await _renderPage(template, match, siteBase);
    final file = File(
      path == '/' ? '$buildDir/index.html' : '$buildDir$path/index.html',
    );
    await file.parent.create(recursive: true);
    await file.writeAsString(html);
    written.add(file.path);
  }

  if (writeSitemap) {
    final file = File('$buildDir/sitemap.xml');
    await file.writeAsString(seoSitemapXml(
      routes: routes,
      siteBase: siteBase,
      additionalPaths: additionalPaths,
    ));
    written.add(file.path);
  }
  if (writeRobotsTxt) {
    final file = File('$buildDir/robots.txt');
    await file.writeAsString(
      seoRobotsTxt(siteBase: siteBase, includeSitemap: writeSitemap),
    );
    written.add(file.path);
  }
  return written;
}

final RegExp _templateTitle = RegExp(r'\s*<title>.*?</title>', dotAll: true);
final RegExp _templateDescription =
    RegExp(r'\s*<meta name="description"[^>]*>');
final RegExp _bodyOpenTag = RegExp(r'<body[^>]*>');

Future<String> _renderPage(
  String template,
  SeoRouteMatch match,
  String siteBase,
) async {
  final meta = match.buildMeta(canonicalBase: siteBase);
  final bodyHtml = const HtmlRenderer().render(await match.buildBody());

  var html = template;
  // Template-Duplikate entfernen — die Route liefert die echten Werte.
  html = html.replaceFirst(_templateTitle, '');
  html = html.replaceAll(_templateDescription, '');
  // lang setzen, sofern das Template keines definiert.
  html = html.replaceFirst(
    '<html>',
    '<html lang="${HtmlRenderer.escapeAttribute(match.route.lang)}">',
  );

  html = html.replaceFirst('</head>', '${meta.toHtml()}\n</head>');
  return html.replaceFirstMapped(
    _bodyOpenTag,
    (m) => '${m[0]}\n${seoContainerHtml(bodyHtml)}',
  );
}
