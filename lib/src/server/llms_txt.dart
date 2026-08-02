import '../meta/seo_meta.dart';
import '../renderer/seo_node.dart';
import '../renderer/tag_policy.dart';
import '../routing/seo_resolution.dart';
import '../routing/seo_resolved_page.dart';
import '../routing/seo_route.dart';

/// Generates an llms.txt from the SEO route table.
///
/// llms.txt (https://llmstxt.org) is the emerging convention for making
/// a site legible to AI assistants: a markdown manifest at `/llms.txt`
/// that names the site and lists its pages with one-line descriptions —
/// the AI-crawler counterpart to sitemap.xml.
///
/// Pass **exactly one** of [routes] and [pages] — see [seoSitemapXml]
/// for the same contract. With [routes] the table is resolved
/// synchronously and a [SeoRoute.dynamic] throws a [StateError]; with a
/// pre-resolved [pages] snapshot every table works.
///
/// Site [title] and [description] default to the metadata of the root
/// page (`/`); every listed page uses its own meta title and
/// description. Pages that resolve to a redirect, a non-200, or opt out
/// of the sitemap are skipped.
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
  required String siteBase,
  List<SeoRoute>? routes,
  List<SeoResolvedPage>? pages,
  String? title,
  String? description,
  List<String> additionalPaths = const [],
}) {
  final base = siteBase.endsWith('/')
      ? siteBase.substring(0, siteBase.length - 1)
      : siteBase;
  final resolved = pagesForGenerator(
    routes: routes,
    pages: pages,
    additionalPaths: additionalPaths,
    canonicalBase: siteBase,
  );

  final rootMeta = _rootMeta(resolved);
  final siteTitle = title ?? rootMeta?.title ?? Uri.parse(base).host;
  final siteDescription = description ?? rootMeta?.description;

  final buffer = StringBuffer()..writeln('# ${_singleLine(siteTitle)}');
  if (siteDescription != null && siteDescription.isNotEmpty) {
    buffer.writeln('> ${_singleLine(siteDescription)}');
  }

  buffer
    ..writeln()
    ..writeln('## Pages')
    ..writeln();
  for (final page in resolved) {
    if (!page.isIndexable) continue;
    final meta = page.document!.meta;
    final url = page.path == '/' ? '$base/' : '$base${page.path}';
    final pageTitle = _linkLabel(meta.title ?? page.path);
    final pageDescription = meta.description;
    buffer
      ..write('- [$pageTitle](${_linkTarget(url)})')
      ..writeln(pageDescription == null || pageDescription.isEmpty
          ? ''
          : ': ${_singleLine(pageDescription)}');
  }
  return buffer.toString();
}

/// The metadata of the root page (`/`) in a resolved set, for the site
/// title and description. The root is present even when it opted out of
/// the sitemap, matching the old behaviour where `matchSeoRoute('/')`
/// did not filter.
SeoMeta? _rootMeta(List<SeoResolvedPage> pages) {
  for (final page in pages) {
    if (page.path == '/') return page.document?.meta;
  }
  return null;
}

/// Generates an llms-full.txt: like [seoLlmsTxt], but with the complete
/// page content inlined as markdown — AI assistants get the whole site
/// in one request instead of crawling page by page.
///
/// The content comes from each page's resolved body (the same [SeoNode]
/// trees the SSR server and prerenderer use), converted to markdown:
/// headings, paragraphs, lists, links, images and blockquotes. Pages
/// with no body list their metadata only.
///
/// Pass **exactly one** of [routes] and [pages]. Unlike the sync
/// generators this never throws on a dynamic table — it is already
/// async and resolves internally when given [routes]. Meta and body of
/// each page come from a **single** resolution, so they cannot describe
/// different records.
Future<String> seoLlmsFullTxt({
  required String siteBase,
  List<SeoRoute>? routes,
  List<SeoResolvedPage>? pages,
  String? title,
  String? description,
  List<String> additionalPaths = const [],
  int concurrency = 8,
}) async {
  if ((routes == null) == (pages == null)) {
    throw ArgumentError('Pass exactly one of `routes:` or `pages:`.');
  }
  if (pages != null && additionalPaths.isNotEmpty) {
    throw ArgumentError(
      '`additionalPaths` cannot be combined with `pages:`.',
    );
  }
  final base = siteBase.endsWith('/')
      ? siteBase.substring(0, siteBase.length - 1)
      : siteBase;
  final resolved = pages ??
      await resolveSeoPages(
        routes: routes!,
        canonicalBase: siteBase,
        additionalPaths: additionalPaths,
        detail: SeoDetail.full,
        concurrency: concurrency,
      );

  final rootMeta = _rootMeta(resolved);
  final siteTitle = title ?? rootMeta?.title ?? Uri.parse(base).host;
  final siteDescription = description ?? rootMeta?.description;

  final buffer = StringBuffer()..writeln('# ${_singleLine(siteTitle)}');
  if (siteDescription != null && siteDescription.isNotEmpty) {
    buffer.writeln('> ${_singleLine(siteDescription)}');
  }

  for (final page in resolved) {
    if (!page.isIndexable) continue;
    final doc = page.document!;
    final meta = doc.meta;
    final url = page.path == '/' ? '$base/' : '$base${page.path}';
    buffer
      ..writeln()
      ..writeln('## ${_singleLine(meta.title ?? page.path)}')
      ..writeln(url);
    final pageDescription = meta.description;
    if (pageDescription != null && pageDescription.isNotEmpty) {
      buffer.writeln('> ${_singleLine(pageDescription)}');
    }
    final markdown = _nodesToMarkdown(doc.body, base);
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
    // Ein Label ist per Definition einzeilig. Ohne das Zusammenziehen
    // bricht ein alt-Text mit Leerzeile aus `![…]` aus und schreibt
    // eigene Überschriften und Absätze in die Datei, die KI-Assistenten
    // als Struktur der Seite lesen. Hier statt an den Aufrufstellen,
    // damit die nächste es nicht vergessen kann.
    _singleLine(value).replaceAll('[', r'\[').replaceAll(']', r'\]');

/// Wraps URLs containing `)` in angle brackets (CommonMark) so the link
/// target does not end early.
String _linkTarget(String url) => url.contains(')') ? '<$url>' : url;

String _singleLine(String value) =>
    value.replaceAll(RegExp(r'\s+'), ' ').trim();
