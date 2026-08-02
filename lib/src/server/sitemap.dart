import '../renderer/html_renderer.dart';
import '../routing/seo_resolved_page.dart';
import '../routing/seo_route.dart';

/// Characters XML 1.0 forbids outright. A single one of them in a route
/// path makes the whole document unparseable — every URL in the sitemap
/// would be lost, not just the offending one — so they are stripped
/// rather than escaped.
final RegExp _xmlForbidden =
    RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F-\x9F\uFFFE\uFFFF]'
        r'|[\uD800-\uDBFF](?![\uDC00-\uDFFF])'
        r'|(?<![\uD800-\uDBFF])[\uDC00-\uDFFF]');

String _xmlSafeAttr(String value) =>
    HtmlRenderer.escapeAttribute(value.replaceAll(_xmlForbidden, ''));

String _xmlSafe(String value) =>
    HtmlRenderer.escapeText(value.replaceAll(_xmlForbidden, ''));

/// Generates a sitemap.xml from the SEO route table.
///
/// Pass **exactly one** of [routes] and [pages]:
///
/// - [routes] is the classic path — the table is resolved synchronously.
///   It throws a [StateError] when the table contains a
///   [SeoRoute.dynamic], because a database read cannot happen without
///   awaiting; the message names the fix.
/// - [pages] is a pre-resolved snapshot from `resolveSeoPages`, which
///   works for every table. Passing [additionalPaths] together with
///   [pages] is an [ArgumentError] — they were already folded into the
///   pass. `seoBotMiddleware` and `prerenderSite` take this path for you.
///
/// Includes every indexable URL: a route without `:param` segments, plus
/// any concrete instances from a route's `enumeratePaths` or from
/// [additionalPaths]. A page that resolves to a redirect, a non-200, or
/// opts out via `includeInSitemap` is dropped.
///
/// Per URL the entry carries `<lastmod>` (a per-record date beats the
/// route's static one) and `<xhtml:link rel="alternate" hreflang="…"/>`
/// for every language variant in the page's `SeoMeta.alternates`.
String seoSitemapXml({
  required String siteBase,
  List<SeoRoute>? routes,
  List<SeoResolvedPage>? pages,
  List<String> additionalPaths = const [],
}) {
  final resolved = pagesForGenerator(
    routes: routes,
    pages: pages,
    additionalPaths: additionalPaths,
    canonicalBase: siteBase,
  );
  final base = siteBase.endsWith('/')
      ? siteBase.substring(0, siteBase.length - 1)
      : siteBase;

  final entries = [
    for (final page in resolved)
      if (page.isIndexable) page,
  ];

  final hasAlternates =
      entries.any((e) => e.document!.meta.alternates.isNotEmpty);
  final buffer = StringBuffer()
    ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
    ..write('<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"')
    ..writeln(
        hasAlternates ? ' xmlns:xhtml="http://www.w3.org/1999/xhtml">' : '>');
  for (final entry in entries) {
    final url = entry.path == '/' ? '$base/' : '$base${entry.path}';
    final lastmod = entry.lastModified;
    final alternates = entry.document!.meta.alternates;
    if (lastmod == null && alternates.isEmpty) {
      buffer.writeln('  <url><loc>${_xmlSafe(url)}</loc></url>');
      continue;
    }
    buffer
      ..writeln('  <url>')
      ..writeln('    <loc>${_xmlSafe(url)}</loc>');
    if (lastmod != null) {
      buffer.writeln('    <lastmod>${_lastmodDate(lastmod)}</lastmod>');
    }
    alternates.forEach((hreflang, href) {
      buffer
        ..write('    <xhtml:link rel="alternate" hreflang="')
        ..write(_xmlSafeAttr(hreflang))
        ..write('" href="')
        ..write(_xmlSafeAttr(href))
        ..writeln('"/>');
    });
    buffer.writeln('  </url>');
  }
  buffer.write('</urlset>');
  return buffer.toString();
}

/// W3C date (YYYY-MM-DD) — the granularity search engines actually use.
String _lastmodDate(DateTime value) =>
    value.toUtc().toIso8601String().substring(0, 10);

/// Generates a robots.txt that allows all crawlers and announces the
/// sitemap.
String seoRobotsTxt({required String siteBase, bool includeSitemap = true}) {
  final base = siteBase.endsWith('/')
      ? siteBase.substring(0, siteBase.length - 1)
      : siteBase;
  final buffer = StringBuffer()
    ..writeln('User-agent: *')
    ..writeln('Allow: /');
  if (includeSitemap) {
    buffer
      ..writeln()
      ..writeln('Sitemap: $base/sitemap.xml');
  }
  return buffer.toString();
}
