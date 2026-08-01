import 'dart:io';

import '../meta/seo_meta.dart';
import '../renderer/html_renderer.dart';
import '../renderer/seo_container.dart';
import '../renderer/seo_stylesheet.dart';
import '../routing/seo_route.dart';
import 'llms_txt.dart';
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
/// - the semantic HTML body inside the `#esen-seo-content` container —
///   the running app finds that container by id and simply takes it
///   over (hydration).
///
/// With [renderMode] set to [SeoRenderMode.visibleShell] that container
/// is no longer hidden: the prerendered HTML becomes the **first frame**
/// the user actually sees, styled by [stylesheet], and Flutter takes the
/// screen over as soon as it has rendered. Pass [seoDefaultStylesheet]
/// for a presentable baseline or your own CSS to match your app.
///
/// Because the content is baked into the files, **no bot detection is
/// needed**: crawlers, link previews and users all receive the same
/// file, and the semantic HTML is right in the page source. Deep links
/// like `/demo` work on static hosts too, since a real
/// `/demo/index.html` exists.
///
/// Also writes `sitemap.xml`, `robots.txt`, `llms.txt`, `llms-full.txt`
/// and a `404.html` (Firebase Hosting, GitHub Pages & Co. serve it with
/// a real 404 status for unknown paths — no SPA soft-404) — plus the
/// IndexNow key file `<key>.txt` when [indexNowKey] is set. Returns the
/// written file paths.
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
  bool writeLlmsTxt = true,
  bool write404Page = true,
  String? indexNowKey,
  SeoRenderMode renderMode = SeoRenderMode.seoOnly,
  String? stylesheet,
}) async {
  final templateFile = File('$buildDir/index.html');
  if (!templateFile.existsSync()) {
    throw StateError(
      '$buildDir/index.html not found — run `flutter build web` first.',
    );
  }
  final template = await templateFile.readAsString();
  // Der Root-Pfad überschreibt index.html — ein zweiter Lauf würde die
  // eigene Ausgabe als Template lesen und alles doppelt einbauen.
  if (template.contains('id="$seoContainerId"')) {
    throw StateError(
      '$buildDir/index.html is already prerendered — run '
      '`flutter build web` again for a clean template. Prerendering an '
      'already prerendered file would duplicate the canonical link, the '
      'JSON-LD blocks and the content container.',
    );
  }

  final paths = <String>[
    for (final route in routes)
      if (!route.hasParams) _checkedPath(route.path),
    ...additionalPaths.map(normalizeSeoPath).map(_checkedPath),
  ];

  final written = <String>[];
  for (final path in paths) {
    final match = matchSeoRoute(routes, path);
    if (match == null) continue;
    final html = await _renderPage(
      template,
      match,
      siteBase,
      renderMode,
      stylesheet,
    );
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
  if (writeLlmsTxt) {
    final file = File('$buildDir/llms.txt');
    await file.writeAsString(seoLlmsTxt(
      routes: routes,
      siteBase: siteBase,
      additionalPaths: additionalPaths,
    ));
    written.add(file.path);

    final fullFile = File('$buildDir/llms-full.txt');
    await fullFile.writeAsString(await seoLlmsFullTxt(
      routes: routes,
      siteBase: siteBase,
      additionalPaths: additionalPaths,
    ));
    written.add(fullFile.path);
  }
  if (write404Page) {
    final file = File('$buildDir/404.html');
    await file.writeAsString(_applyTemplate(
      template,
      const SeoMeta(title: '404 — Page not found', robots: 'noindex'),
      '<h1>404 — Page not found</h1>',
      'en',
      renderMode,
      stylesheet,
    ));
    written.add(file.path);
  }
  if (indexNowKey != null) {
    if (!_validIndexNowKey.hasMatch(indexNowKey)) {
      throw ArgumentError.value(
        indexNowKey,
        'indexNowKey',
        'must be 8–128 characters, letters, digits and dashes only — the '
            'key becomes a file name',
      );
    }
    final file = File('$buildDir/$indexNowKey.txt');
    await file.writeAsString(indexNowKey);
    written.add(file.path);
  }
  return written;
}

/// The IndexNow key doubles as a file name — keep it to the character
/// set the protocol allows.
final RegExp _validIndexNowKey = RegExp(r'^[A-Za-z0-9-]{8,128}$');

/// Route paths become file paths under `buildDir`. A `..` segment (or a
/// backslash, or a Windows drive letter) would let a route — and with a
/// CMS behind it, someone else's content — write outside the build
/// directory entirely.
String _checkedPath(String path) {
  final segments = path.split('/');
  final unsafe = segments.any((segment) =>
      segment == '..' ||
      segment == '.' ||
      segment.contains(r'\') ||
      segment.contains(':') ||
      // Query und Fragment gehören nicht in einen Dateinamen: Die Datei
      // entstünde, wäre über ihre URL aber nie erreichbar.
      segment.contains('?') ||
      segment.contains('#') ||
      segment.contains('*') ||
      RegExp(r'[\x00-\x1F\x7F]').hasMatch(segment));
  if (unsafe) {
    throw ArgumentError.value(
      path,
      'path',
      'must not step outside the build directory — no "..", "." or drive '
          'segments',
    );
  }
  final lower = path.toLowerCase();
  // Jede Seite landet als <pfad>/index.html. Heißt ein Segment selbst
  // index.html, treffen sich Datei und Verzeichnis: /a schreibt die
  // Datei a/index.html, /a/index.html/b will darin ein Verzeichnis
  // anlegen. Was zuerst drankommt, entscheidet dann über den Absturz.
  if (lower.split('/').contains('index.html')) {
    throw ArgumentError.value(
      path,
      'path',
      'must not contain a segment named "index.html" — that is the file '
          'each page is written to',
    );
  }
  // Auch ein Präfix kollidiert: /robots.txt/foo legt erst das
  // Verzeichnis robots.txt an, danach scheitert die echte Datei.
  final collides = _reservedOutputNames.any(
    (reserved) => lower == reserved || lower.startsWith('$reserved/'),
  );
  if (collides) {
    throw ArgumentError.value(
      path,
      'path',
      'collides with a file the prerenderer generates — pick another '
          'route path',
    );
  }
  return path;
}

/// Paths whose output file the prerenderer writes itself. A route (or a
/// CMS slug) of the same name would overwrite `robots.txt` or the
/// sitemap with page HTML.
const Set<String> _reservedOutputNames = {
  '/robots.txt',
  '/sitemap.xml',
  '/llms.txt',
  '/llms-full.txt',
  '/404.html',
  '/index.html',
};

final RegExp _templateTitle = RegExp(r'\s*<title>.*?</title>', dotAll: true);
final RegExp _templateDescription =
    RegExp(r'\s*<meta name="description"[^>]*>');
final RegExp _bodyOpenTag = RegExp(r'<body[^>]*>');

Future<String> _renderPage(
  String template,
  SeoRouteMatch match,
  String siteBase,
  SeoRenderMode renderMode,
  String? stylesheet,
) async {
  final meta = match.buildMeta(canonicalBase: siteBase);
  final bodyHtml = const HtmlRenderer().render(await match.buildBody());
  return _applyTemplate(
    template,
    meta,
    bodyHtml,
    match.route.lang,
    renderMode,
    stylesheet,
  );
}

String _applyTemplate(
  String template,
  SeoMeta meta,
  String bodyHtml,
  String lang,
  SeoRenderMode renderMode,
  String? stylesheet,
) {
  var html = template;
  // Template-Duplikate entfernen — die Route liefert die echten Werte.
  html = html.replaceFirst(_templateTitle, '');
  html = html.replaceAll(_templateDescription, '');
  // lang setzen, sofern das Template keines definiert.
  html = html.replaceFirst(
    '<html>',
    '<html lang="${HtmlRenderer.escapeAttribute(lang)}">',
  );

  // Kritisches CSS gehört inline in den Head: Der Shell soll malen,
  // bevor irgendein zusätzlicher Request gelaufen ist.
  final head = StringBuffer(meta.toHtml());
  if (stylesheet != null && stylesheet.trim().isNotEmpty) {
    head.write(seoStyleTagHtml(stylesheet));
  }

  html = html.replaceFirst('</head>', '$head\n</head>');
  return html.replaceFirstMapped(
    _bodyOpenTag,
    (m) => '${m[0]}\n${seoContainerHtml(bodyHtml, mode: renderMode)}',
  );
}
