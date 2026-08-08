import 'dart:io';

import '../meta/seo_meta.dart';
import '../renderer/html_renderer.dart';
import '../renderer/seo_container.dart';
import '../renderer/seo_stylesheet.dart';
import '../routing/seo_resolution.dart';
import '../routing/seo_resolved_page.dart';
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
/// That mode **requires the app to call `EsenSeo.init()`** — without it
/// nothing ever schedules the handoff and the shell stays on top of the
/// running app for good. See [SeoRenderMode.visibleShell].
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
  int concurrency = 8,
  void Function(String path, SeoResolution resolution)? onSkipped,
  void Function(String path, Object error, StackTrace stack)? onError,
}) async {
  final templateFile = File('$buildDir/index.html');
  if (!templateFile.existsSync()) {
    throw StateError(
      '$buildDir/index.html not found — run `flutter build web` first.',
    );
  }
  final template = await templateFile.readAsString();
  _validateTemplate(template, buildDir);

  // Say which stylesheet is being baked in. The drift guard watches
  // the generated file, but nothing else watches the last link of the
  // chain — a themed stylesheet that is generated, committed and then
  // never passed here fails silently in exactly the way this line
  // makes visible in every build log.
  stdout.writeln(_describeStylesheet(stylesheet, renderMode));
  // Der Root-Pfad überschreibt index.html — ein zweiter Lauf würde die
  // eigene Ausgabe als Template lesen und alles doppelt einbauen.
  if (_seoContainerMarker.hasMatch(template)) {
    throw StateError(
      '$buildDir/index.html is already prerendered — run '
      '`flutter build web` again for a clean template. Prerendering an '
      'already prerendered file would duplicate the canonical link, the '
      'JSON-LD blocks and the content container.',
    );
  }

  // Den Key prüfen, bevor irgendetwas geschrieben wird: er gehört zur
  // Liste der belegten Dateinamen, und ein Abbruch nach dem halben Build
  // hinterlässt ein Verzeichnis, in dem manche Seiten neu und manche alt
  // sind.
  if (indexNowKey != null && !_validIndexNowKey.hasMatch(indexNowKey)) {
    throw ArgumentError.value(
      indexNowKey,
      'indexNowKey',
      'must be 8–128 characters, letters, digits and dashes only — the '
          'key becomes a file name',
    );
  }
  final reserved = <String>{
    ..._reservedOutputNames,
    // Der Key ist erst zur Laufzeit bekannt, belegt aber genauso einen
    // Dateinamen wie robots.txt.
    if (indexNowKey != null) '/${indexNowKey.toLowerCase()}.txt',
  };

  // One resolution pass for the whole build: every page is read once and
  // the same list feeds the HTML, the sitemap and both llms files, so a
  // dynamic route cannot show one thing on the page and another in the
  // sitemap.
  final pages = await resolveSeoPages(
    routes: routes,
    canonicalBase: siteBase,
    additionalPaths: additionalPaths,
    detail: SeoDetail.full,
    concurrency: concurrency,
    onError: onError,
  );

  // Validate EVERY output path — including the ones an enumerator
  // produced, which is the first time untrusted strings become file
  // paths — before a single file is written.
  final outputPaths = <String, String>{};
  for (final page in pages) {
    _checkedPath(page.path, reserved);
    final portableKey = page.path.toLowerCase();
    final first = outputPaths[portableKey];
    if (first != null && first != page.path) {
      throw ArgumentError.value(
        page.path,
        'path',
        'collides with "$first" on a case-insensitive file system',
      );
    }
    outputPaths[portableKey] = page.path;
  }

  final written = <String>[];
  for (final page in pages) {
    final doc = page.document;
    // A static host cannot emit a 301 or a 404 status from a file, so a
    // redirect or an error page is not written — it is reported instead,
    // for the caller to turn into a host-specific _redirects fragment.
    if (doc == null || doc.statusCode != 200) {
      onSkipped?.call(page.path, page.resolution);
      continue;
    }
    final html = _applyTemplate(
      template,
      doc.meta,
      const HtmlRenderer().render(doc.body),
      page.lang,
      renderMode,
      stylesheet,
    );
    final file = File(
      page.path == '/'
          ? '$buildDir/index.html'
          : '$buildDir${page.path}/index.html',
    );
    await file.parent.create(recursive: true);
    await file.writeAsString(html);
    written.add(file.path);
  }

  if (writeSitemap) {
    final file = File('$buildDir/sitemap.xml');
    await file.writeAsString(seoSitemapXml(pages: pages, siteBase: siteBase));
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
    await file.writeAsString(seoLlmsTxt(pages: pages, siteBase: siteBase));
    written.add(file.path);

    final fullFile = File('$buildDir/llms-full.txt');
    await fullFile
        .writeAsString(await seoLlmsFullTxt(pages: pages, siteBase: siteBase));
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
    // Format und Kollisionsfreiheit sind oben geprüft, vor dem ersten
    // Schreibvorgang.
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
String _checkedPath(String path, Set<String> reserved) {
  final segments = path.split('/');
  // Ein leeres Segment INNEN (`/a//b`) verschwindet im Dateipfad: die
  // Datei landet unter a/b, die Sitemap wirbt aber für /a//b, und eine
  // zweite Route /a/b überschreibt sie stillschweigend. Leer sein darf
  // nur das erste Segment (jeder Pfad beginnt mit /) und das letzte
  // (abschließender Slash) — dazwischen ist es ein Tippfehler.
  final interior =
      segments.length > 2 ? segments.sublist(1, segments.length - 1) : const [];
  final unsafe = interior.any((segment) => segment.isEmpty) ||
      segments.any((segment) =>
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
  final collides = reserved.any(
    (name) => lower == name || lower.startsWith('$name/'),
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

final RegExp _templateTitle = RegExp(
  r'\s*<title\b[^>]*>.*?</title\s*>',
  caseSensitive: false,
  dotAll: true,
);
final RegExp _metaTag = RegExp(r'<meta\b[^>]*>', caseSensitive: false);
final RegExp _descriptionMetaName = RegExp(
  r'''\bname\s*=\s*(?:"description"|'description'|description(?=[\s/>]))''',
  caseSensitive: false,
);
final RegExp _htmlOpenTag = RegExp(r'<html\b([^>]*)>', caseSensitive: false);
final RegExp _langAttribute = RegExp(r'''\blang\s*=''', caseSensitive: false);
final RegExp _headCloseTag = RegExp(r'</head\s*>', caseSensitive: false);
final RegExp _bodyOpenTag = RegExp(r'<body\b[^>]*>', caseSensitive: false);
final RegExp _seoContainerMarker = RegExp(
  r'''\bid\s*=\s*(["'])''' + RegExp.escape(seoContainerId) + r'''\1''',
  caseSensitive: false,
);

void _validateTemplate(String template, String buildDir) {
  final missing = <String>[
    if (!_htmlOpenTag.hasMatch(template)) '<html>',
    if (!_headCloseTag.hasMatch(template)) '</head>',
    if (!_bodyOpenTag.hasMatch(template)) '<body>',
  ];
  if (missing.isNotEmpty) {
    throw StateError(
      '$buildDir/index.html is not a complete HTML template; missing '
      '${missing.join(', ')}.',
    );
  }
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
  html = html.replaceAllMapped(
    _metaTag,
    (match) => _descriptionMetaName.hasMatch(match[0]!) ? '' : match[0]!,
  );
  // lang setzen, sofern das Template keines definiert.
  html = html.replaceFirstMapped(
    _htmlOpenTag,
    (match) {
      final attributes = match[1] ?? '';
      if (_langAttribute.hasMatch(attributes)) return match[0]!;
      return '<html$attributes lang="${HtmlRenderer.escapeAttribute(lang)}">';
    },
  );

  // Kritisches CSS gehört inline in den Head: Der Shell soll malen,
  // bevor irgendein zusätzlicher Request gelaufen ist.
  final head = StringBuffer(meta.toHtml());
  if (stylesheet != null && stylesheet.trim().isNotEmpty) {
    head.write(seoStyleTagHtml(stylesheet));
  }

  html = html.replaceFirstMapped(
    _headCloseTag,
    (match) => '$head\n${match[0]}',
  );
  final result = html.replaceFirstMapped(
    _bodyOpenTag,
    (m) => '${m[0]}\n${seoContainerHtml(bodyHtml, mode: renderMode)}',
  );
  if (!_seoContainerMarker.hasMatch(result)) {
    throw StateError(
        'Prerendering failed to inject the SEO content container.');
  }
  return result;
}

/// One line for the build log: what will style the shell.
String _describeStylesheet(String? stylesheet, SeoRenderMode mode) {
  final css = stylesheet?.trim() ?? '';
  final String what;
  if (css.isEmpty) {
    what = 'none (unstyled semantic HTML)';
  } else if (css == seoDefaultStylesheet.trim()) {
    what = 'seoDefaultStylesheet (opinion-free web scale)';
  } else if (css.contains('--esen-color-')) {
    what = 'themed (${css.length} chars, esen theme tokens)';
  } else {
    what = 'custom (${css.length} chars)';
  }
  return 'prerender stylesheet: $what'
      '${mode == SeoRenderMode.visibleShell ? ' — visible shell' : ''}';
}
