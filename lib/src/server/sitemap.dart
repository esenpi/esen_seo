import '../renderer/html_renderer.dart';
import '../routing/seo_route.dart';

/// Generates a sitemap.xml from the SEO route table.
///
/// Includes every route with [SeoRoute.includeInSitemap] that has no
/// `:param` segments (their concrete URLs cannot be enumerated from the
/// pattern — pass known instances via [additionalPaths], e.g. the slugs
/// of all published blog posts).
String seoSitemapXml({
  required List<SeoRoute> routes,
  required String siteBase,
  List<String> additionalPaths = const [],
}) {
  final base = siteBase.endsWith('/')
      ? siteBase.substring(0, siteBase.length - 1)
      : siteBase;
  final paths = <String>[
    for (final route in routes)
      if (route.includeInSitemap && !route.hasParams) route.path,
    ...additionalPaths.map(normalizeSeoPath),
  ];

  final buffer = StringBuffer()
    ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
    ..writeln('<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">');
  for (final path in paths) {
    final url = path == '/' ? '$base/' : '$base$path';
    buffer.writeln('  <url><loc>${HtmlRenderer.escapeText(url)}</loc></url>');
  }
  buffer.write('</urlset>');
  return buffer.toString();
}

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
