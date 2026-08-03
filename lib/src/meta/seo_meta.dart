import '../renderer/html_renderer.dart';
import '../renderer/seo_node.dart';
import '../renderer/tag_policy.dart';
import 'seo_schema.dart';

/// Page metadata for the document `<head>`: title, description,
/// OpenGraph and Twitter Card tags.
///
/// ```dart
/// EsenSeo.setMeta(const SeoMeta(
///   title: 'Willkommen bei Esen Software',
///   description: 'Flutter Apps mit echtem SEO.',
///   canonicalUrl: 'https://esen.software/',
///   openGraph: OpenGraphMeta(image: 'https://esen.software/og.png'),
/// ));
/// ```
///
/// Smart defaults keep the API minimal: `og:title` and `og:description`
/// fall back to [title] and [description], `og:url` to [canonicalUrl] and
/// `og:type` to `website`. Twitter Cards reuse the OpenGraph values.
class SeoMeta {
  const SeoMeta({
    this.title,
    this.description,
    this.keywords = const [],
    this.author,
    this.robots,
    this.canonicalUrl,
    this.openGraph,
    this.twitter,
    this.schemas = const [],
    this.alternates = const {},
    this.extraMeta = const {},
  });

  /// The document title, rendered as `<title>` and `og:title` fallback.
  final String? title;

  /// The meta description shown in search results.
  final String? description;

  /// Keywords, joined with `, ` into one `<meta name="keywords">` tag.
  final List<String> keywords;

  /// Content author, rendered as `<meta name="author">`.
  final String? author;

  /// Crawler directives, e.g. `noindex, nofollow`.
  final String? robots;

  /// Canonical URL of this page, rendered as `<link rel="canonical">`
  /// and `og:url` fallback.
  final String? canonicalUrl;

  /// OpenGraph overrides and additions. Even without this, `og:title`,
  /// `og:description`, `og:url` and `og:type` are derived from the
  /// base fields.
  final OpenGraphMeta? openGraph;

  /// Twitter Card overrides. Without this a card is only emitted when an
  /// OpenGraph image exists (Twitter reads the `og:` tags for the rest).
  final TwitterCardMeta? twitter;

  /// Schema.org JSON-LD blocks for rich search results, rendered as
  /// `<script type="application/ld+json">` tags. See [SeoSchema].
  final List<SeoSchema> schemas;

  /// Language variants of this page for international SEO, mapping an
  /// hreflang code to the absolute URL of that variant:
  ///
  /// ```dart
  /// alternates: {
  ///   'de': 'https://example.com/de/preise',
  ///   'en': 'https://example.com/en/pricing',
  ///   'x-default': 'https://example.com/en/pricing',
  /// }
  /// ```
  ///
  /// Rendered as `<link rel="alternate" hreflang="…" href="…"/>`.
  /// Per Google's guidelines, include the page itself in the set and
  /// add an `x-default` entry for the fallback variant.
  final Map<String, String> alternates;

  /// Additional `<meta name="…" content="…">` tags, e.g. for site
  /// verification or theming:
  ///
  /// ```dart
  /// extraMeta: {
  ///   'google-site-verification': 'AbC123…',
  ///   'theme-color': '#0a0f1e',
  /// }
  /// ```
  ///
  /// A `referrer` entry is emitted only when its value is a privacy-preserving
  /// policy accepted by the renderer. Values such as `unsafe-url` are omitted.
  final Map<String, String> extraMeta;

  /// Returns a copy with the given fields replaced.
  /// Unset fields keep their current value (they cannot be nulled out).
  SeoMeta copyWith({
    String? title,
    String? description,
    List<String>? keywords,
    String? author,
    String? robots,
    String? canonicalUrl,
    OpenGraphMeta? openGraph,
    TwitterCardMeta? twitter,
    List<SeoSchema>? schemas,
    Map<String, String>? alternates,
    Map<String, String>? extraMeta,
  }) =>
      SeoMeta(
        title: title ?? this.title,
        description: description ?? this.description,
        keywords: keywords ?? this.keywords,
        author: author ?? this.author,
        robots: robots ?? this.robots,
        canonicalUrl: canonicalUrl ?? this.canonicalUrl,
        openGraph: openGraph ?? this.openGraph,
        twitter: twitter ?? this.twitter,
        schemas: schemas ?? this.schemas,
        alternates: alternates ?? this.alternates,
        extraMeta: extraMeta ?? this.extraMeta,
      );

  /// The `<head>` fragment for these values, e.g. for server-side rendering.
  String toHtml() => const HtmlRenderer.head().render(toNodes());

  /// Builds the `<head>` elements as [SeoNode]s: `<title>`, `<meta>` and
  /// `<link>` tags in a stable order.
  List<SeoNode> toNodes() {
    final nodes = <SeoNode>[];

    void meta(String keyAttribute, String key, String? content) {
      if (content == null || content.isEmpty) return;
      nodes.add(
        SeoNode(
            tag: 'meta', attributes: {keyAttribute: key, 'content': content}),
      );
    }

    void name(String key, String? content) => meta('name', key, content);
    void property(String key, String? content) =>
        meta('property', key, content);

    /// A meta tag whose content *is* a URL, held to the same policy the
    /// renderer applies to `href`. Without this, a value refused in
    /// `<link rel="canonical">` would still reach `og:url`, where the
    /// scrapers that read it might follow it.
    void urlProperty(String key, String? url) {
      if (url == null || !isAllowedSeoAttribute('href', url)) return;
      property(key, url);
    }

    String? checkedUrl(String? url) =>
        (url != null && isAllowedSeoAttribute('href', url)) ? url : null;

    if (title != null) nodes.add(SeoNode(tag: 'title', text: title));
    name('description', description);
    name('keywords', keywords.isEmpty ? null : keywords.join(', '));
    name('author', author);
    name('robots', robots);
    final canonical = checkedUrl(canonicalUrl);
    if (canonical != null) {
      nodes.add(
        SeoNode(
            tag: 'link', attributes: {'rel': 'canonical', 'href': canonical}),
      );
    }
    alternates.forEach((hreflang, href) {
      // Eine abgelehnte URL soll kein leeres <link> hinterlassen.
      if (checkedUrl(href) == null) return;
      nodes.add(SeoNode(tag: 'link', attributes: {
        'rel': 'alternate',
        'hreflang': hreflang,
        'href': href,
      }));
    });

    final og = openGraph;
    final ogTitle = og?.title ?? title;
    final ogDescription = og?.description ?? description;
    final ogUrl = og?.url ?? canonicalUrl;
    final hasOpenGraph = og != null || ogTitle != null || ogDescription != null;
    if (hasOpenGraph) {
      property('og:type', og?.type ?? 'website');
      property('og:title', ogTitle);
      property('og:description', ogDescription);
      urlProperty('og:url', ogUrl);
      urlProperty('og:image', og?.image);
      property('og:image:alt', og?.imageAlt);
      property('og:site_name', og?.siteName);
      property('og:locale', og?.locale);
    }

    final tw = twitter;
    if (tw != null || og?.image != null) {
      final defaultCard = og?.image != null ? 'summary_large_image' : 'summary';
      name('twitter:card', tw?.card ?? defaultCard);
      name('twitter:site', tw?.site);
      name('twitter:creator', tw?.creator);
    }

    extraMeta.forEach((key, content) {
      if (key.trim().toLowerCase() == 'referrer' &&
          !isAllowedSeoAttribute('referrerpolicy', content)) {
        return;
      }
      name(key, content);
    });

    for (final schema in schemas) {
      nodes.add(schema.toNode());
    }

    return nodes;
  }
}

/// OpenGraph values for link previews (Facebook, LinkedIn, WhatsApp, …).
///
/// Every field is optional — unset fields fall back to the base [SeoMeta]
/// values or sensible defaults.
class OpenGraphMeta {
  const OpenGraphMeta({
    this.title,
    this.description,
    this.image,
    this.imageAlt,
    this.url,
    this.type,
    this.siteName,
    this.locale,
  });

  /// Overrides `og:title` (default: [SeoMeta.title]).
  final String? title;

  /// Overrides `og:description` (default: [SeoMeta.description]).
  final String? description;

  /// Absolute URL of the preview image.
  final String? image;

  /// Alt text for the preview image.
  final String? imageAlt;

  /// Overrides `og:url` (default: [SeoMeta.canonicalUrl]).
  final String? url;

  /// OpenGraph object type, e.g. `website`, `article` (default: `website`).
  final String? type;

  /// Name of the site, e.g. `Esen Software`.
  final String? siteName;

  /// Locale of the content, e.g. `de_DE`.
  final String? locale;
}

/// Twitter Card values. Title, description and image come from the
/// OpenGraph tags — Twitter reads those automatically.
class TwitterCardMeta {
  const TwitterCardMeta({this.card, this.site, this.creator});

  /// Card type, e.g. `summary` or `summary_large_image`.
  /// Default: `summary_large_image` when an OpenGraph image exists,
  /// otherwise `summary`.
  final String? card;

  /// The site's Twitter handle, e.g. `@esensoftware`.
  final String? site;

  /// The author's Twitter handle.
  final String? creator;
}
