import '../renderer/seo_node.dart';
import '../renderer/tag_policy.dart';
import '../routing/seo_route.dart';

/// Generates an llms.txt from the SEO route table.
///
/// llms.txt (https://llmstxt.org) is the emerging convention for making
/// a site legible to AI assistants: a markdown manifest at `/llms.txt`
/// that names the site and lists its pages with one-line descriptions —
/// the AI-crawler counterpart to sitemap.xml.
///
/// Site [title] and [description] default to the metadata of the root
/// route (`/`); every listed page uses its route's meta title and
/// description. Like the sitemap, `:param` routes are skipped — pass
/// known instances via [additionalPaths].
///
/// ```dart
/// final txt = seoLlmsTxt(routes: seoRoutes, siteBase: 'https://x.dev');
/// // # Esen Software
/// // > Flutter Apps mit echtem SEO.
/// //
/// // ## Pages
/// //
/// // - [Home](https://x.dev/): Flutter Apps mit echtem SEO.
/// // - [Docs](https://x.dev/docs): So funktioniert esen_seo.
/// ```
String seoLlmsTxt({
  required List<SeoRoute> routes,
  required String siteBase,
  String? title,
  String? description,
  List<String> additionalPaths = const [],
}) {
  final base = siteBase.endsWith('/')
      ? siteBase.substring(0, siteBase.length - 1)
      : siteBase;

  final rootMeta = matchSeoRoute(routes, '/')?.buildMeta();
  final siteTitle = title ?? rootMeta?.title ?? Uri.parse(base).host;
  final siteDescription = description ?? rootMeta?.description;

  final buffer = StringBuffer()..writeln('# ${_singleLine(siteTitle)}');
  if (siteDescription != null && siteDescription.isNotEmpty) {
    buffer.writeln('> ${_singleLine(siteDescription)}');
  }

  // Set-Literal statt Liste: additionalPaths, die schon als Route
  // existieren (oder doppelt übergeben werden), erscheinen nur einmal.
  final paths = <String>{
    for (final route in routes)
      if (route.includeInSitemap && !route.hasParams) route.path,
    ...additionalPaths.map(normalizeSeoPath),
  };

  buffer
    ..writeln()
    ..writeln('## Pages')
    ..writeln();
  for (final path in paths) {
    final url = path == '/' ? '$base/' : '$base$path';
    final meta = matchSeoRoute(routes, path)?.buildMeta();
    final pageTitle = _linkLabel(_singleLine(meta?.title ?? path));
    final pageDescription = meta?.description;
    buffer
      ..write('- [$pageTitle](${_linkTarget(url)})')
      ..writeln(pageDescription == null || pageDescription.isEmpty
          ? ''
          : ': ${_singleLine(pageDescription)}');
  }
  return buffer.toString();
}

/// Generates an llms-full.txt: like [seoLlmsTxt], but with the complete
/// page content inlined as markdown — AI assistants get the whole site
/// in one request instead of crawling page by page.
///
/// The content comes from each route's server-side `body` builder
/// (the same [SeoNode] trees the SSR server and prerenderer use),
/// converted to markdown: headings, paragraphs, lists, links, images
/// and blockquotes. Routes without a body builder list their metadata
/// only. Async because body builders may load content, e.g. from a
/// database.
Future<String> seoLlmsFullTxt({
  required List<SeoRoute> routes,
  required String siteBase,
  String? title,
  String? description,
  List<String> additionalPaths = const [],
}) async {
  final base = siteBase.endsWith('/')
      ? siteBase.substring(0, siteBase.length - 1)
      : siteBase;

  final rootMeta = matchSeoRoute(routes, '/')?.buildMeta();
  final siteTitle = title ?? rootMeta?.title ?? Uri.parse(base).host;
  final siteDescription = description ?? rootMeta?.description;

  final buffer = StringBuffer()..writeln('# ${_singleLine(siteTitle)}');
  if (siteDescription != null && siteDescription.isNotEmpty) {
    buffer.writeln('> ${_singleLine(siteDescription)}');
  }

  // Set-Literal statt Liste — Duplikate wie in [seoLlmsTxt] nur einmal.
  final paths = <String>{
    for (final route in routes)
      if (route.includeInSitemap && !route.hasParams) route.path,
    ...additionalPaths.map(normalizeSeoPath),
  };

  for (final path in paths) {
    final match = matchSeoRoute(routes, path);
    if (match == null) continue;
    final url = path == '/' ? '$base/' : '$base$path';
    final meta = match.buildMeta();
    buffer
      ..writeln()
      ..writeln('## ${_singleLine(meta.title ?? path)}')
      ..writeln(url);
    final pageDescription = meta.description;
    if (pageDescription != null && pageDescription.isNotEmpty) {
      buffer.writeln('> ${_singleLine(pageDescription)}');
    }
    final markdown = _nodesToMarkdown(await match.buildBody(), base);
    if (markdown.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln(markdown);
    }
  }
  return buffer.toString();
}

/// Renders SeoNode trees as markdown blocks separated by blank lines.
String _nodesToMarkdown(List<SeoNode> nodes, String base) {
  final blocks = <String>[];
  for (final node in nodes) {
    _writeBlock(node, blocks, base);
  }
  return blocks.join('\n\n');
}

const _headingLevels = {
  'h1': '#',
  'h2': '##',
  'h3': '###',
  'h4': '####',
  'h5': '#####',
  'h6': '######',
};

void _writeBlock(SeoNode node, List<String> blocks, String base) {
  final heading = _headingLevels[node.tag];
  if (heading != null) {
    final text = _inline(node, base);
    if (text.isNotEmpty) blocks.add('$heading $text');
    return;
  }
  switch (node.tag) {
    case 'script':
    case 'style':
      return; // JSON-LD & Co. sind kein Inhalt.
    case 'ul':
    case 'ol':
      final items = <String>[];
      for (var i = 0; i < node.children.length; i++) {
        final text = _inline(node.children[i], base);
        if (text.isEmpty) continue;
        items.add(node.tag == 'ul' ? '- $text' : '${i + 1}. $text');
      }
      if (items.isNotEmpty) blocks.add(items.join('\n'));
    case 'blockquote':
      final text = _inline(node, base);
      if (text.isNotEmpty) blocks.add('> $text');
    case 'img':
      final src = node.attributes['src'];
      if (src != null) {
        final target = _href(src, base);
        if (target != null) {
          blocks.add('![${_linkLabel(node.attributes['alt'] ?? '')}]'
              '(${_linkTarget(target)})');
        }
      }
    case 'hr':
      blocks.add('---');
    case 'p':
    case 'a':
    case '':
      final text = _inline(node, base);
      if (text.isNotEmpty) blocks.add(text);
    default:
      // Container (div, section, article, …): eigener Text als Absatz,
      // Kinder als eigenständige Blöcke.
      final text = node.text?.trim();
      if (text != null && text.isNotEmpty) blocks.add(_singleLine(text));
      for (final child in node.children) {
        _writeBlock(child, blocks, base);
      }
  }
}

/// Renders a node's text and children as one line of inline markdown.
String _inline(SeoNode node, String base) {
  final buffer = StringBuffer();
  void walk(SeoNode n) {
    switch (n.tag) {
      case 'script':
      case 'style':
        return;
      case 'a':
        final label = _inlineOf(n, base);
        final target = n.attributes['href'] == null
            ? null
            : _href(n.attributes['href']!, base);
        buffer.write(target == null
            ? label
            : '[${_linkLabel(label)}](${_linkTarget(target)})');
        return;
      case 'img':
        final src = n.attributes['src'];
        final target = src == null ? null : _href(src, base);
        if (target != null) {
          buffer.write('![${_linkLabel(n.attributes['alt'] ?? '')}]'
              '(${_linkTarget(target)})');
        }
        return;
      case 'strong':
      case 'b':
        buffer.write('**${_inlineOf(n, base)}**');
        return;
      case 'em':
      case 'i':
        buffer.write('*${_inlineOf(n, base)}*');
        return;
      case 'code':
        buffer.write('`${_inlineOf(n, base)}`');
        return;
    }
    if (n.text != null) buffer.write('${n.text} ');
    for (final child in n.children) {
      walk(child);
    }
  }

  walk(node);
  return _singleLine(buffer.toString());
}

/// [_inline] for a child node regardless of its own tag handling.
String _inlineOf(SeoNode node, String base) =>
    _inline(SeoNode(tag: '', text: node.text, children: node.children), base);

/// Site-relative URLs become absolute — AI consumers read the file
/// without a base-URL context. Returns `null` for anything the URL
/// policy refuses: llms.txt is read by agents that may follow its
/// links, so an executable scheme has no business being in there.
String? _href(String url, String base) {
  if (!isAllowedSeoAttribute('href', url)) return null;
  return url.startsWith('/') ? '$base$url' : url;
}

/// Escapes square brackets so titles, labels and alt texts cannot break
/// the `[label](url)` link syntax.
String _linkLabel(String value) =>
    value.replaceAll('[', r'\[').replaceAll(']', r'\]');

/// Wraps URLs containing `)` in angle brackets (CommonMark) so the link
/// target does not end early.
String _linkTarget(String url) => url.contains(')') ? '<$url>' : url;

String _singleLine(String value) =>
    value.replaceAll(RegExp(r'\s+'), ' ').trim();
