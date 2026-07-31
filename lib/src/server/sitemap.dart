import '../renderer/html_renderer.dart';
import '../routing/seo_route.dart';

/// Generates a sitemap.xml from the SEO route table.
///
/// Includes every route with [SeoRoute.includeInSitemap] that has no
/// `:param` segments (their concrete URLs cannot be enumerated from the
/// pattern — pass known instances via [additionalPaths], e.g. the slugs
/// of all published blog posts; they are matched back against the route
/// table so their metadata is picked up too).
///
/// Per URL the entry carries everything the route knows:
///
/// - `<lastmod>` from [SeoRoute.lastModified],
/// - `<xhtml:link rel="alternate" hreflang="…"/>` for every language
///   variant in the route's `SeoMeta.alternates` (Google's recommended
///   way to announce translations via the sitemap).
String seoSitemapXml({
  required List<SeoRoute> routes,
  required String siteBase,
  List<String> additionalPaths = const [],
}) {
  final base = siteBase.endsWith('/')
      ? siteBase.substring(0, siteBase.length - 1)
      : siteBase;
  final entries = <_SitemapEntry>[
    for (final route in routes)
      if (route.includeInSitemap && !route.hasParams)
        _SitemapEntry(route.path, route, null),
    for (final path in additionalPaths.map(normalizeSeoPath))
      _entryForPath(routes, path),
  ];

  final hasAlternates = entries.any((e) => e.alternates.isNotEmpty);
  final buffer = StringBuffer()
    ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
    ..write('<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"')
    ..writeln(
        hasAlternates ? ' xmlns:xhtml="http://www.w3.org/1999/xhtml">' : '>');
  for (final entry in entries) {
    final url = entry.path == '/' ? '$base/' : '$base${entry.path}';
    final lastmod = entry.route?.lastModified;
    if (lastmod == null && entry.alternates.isEmpty) {
      buffer.writeln('  <url><loc>${HtmlRenderer.escapeText(url)}</loc></url>');
      continue;
    }
    buffer
      ..writeln('  <url>')
      ..writeln('    <loc>${HtmlRenderer.escapeText(url)}</loc>');
    if (lastmod != null) {
      buffer.writeln('    <lastmod>${_lastmodDate(lastmod)}</lastmod>');
    }
    entry.alternates.forEach((hreflang, href) {
      buffer
        ..write('    <xhtml:link rel="alternate" hreflang="')
        ..write(HtmlRenderer.escapeAttribute(hreflang))
        ..write('" href="')
        ..write(HtmlRenderer.escapeAttribute(href))
        ..writeln('"/>');
    });
    buffer.writeln('  </url>');
  }
  buffer.write('</urlset>');
  return buffer.toString();
}

class _SitemapEntry {
  _SitemapEntry(this.path, this.route, Map<String, String>? alternates)
      : alternates = alternates ??
            (route == null ? const {} : route.meta(const {}).alternates);

  final String path;
  final SeoRoute? route;
  final Map<String, String> alternates;
}

/// Resolves an additional path against the route table so parameterized
/// pages (e.g. `/blog/:slug` instances) inherit lastmod and alternates.
_SitemapEntry _entryForPath(List<SeoRoute> routes, String path) {
  final match = matchSeoRoute(routes, path);
  if (match == null) return _SitemapEntry(path, null, const {});
  return _SitemapEntry(
      path, match.route, match.route.meta(match.params).alternates);
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
