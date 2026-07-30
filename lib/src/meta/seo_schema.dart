import 'dart:convert';

import '../renderer/seo_node.dart';

/// A Schema.org JSON-LD block for rich search results.
///
/// Attach schemas to the page through `SeoMeta.schemas`:
///
/// ```dart
/// EsenSeo.setMeta(SeoMeta(
///   title: 'Rotes Rennrad',
///   schemas: [
///     SeoSchema.product(
///       name: 'Rotes Rennrad',
///       price: 799.0,
///       priceCurrency: 'EUR',
///     ),
///   ],
/// ));
/// // → <script type="application/ld+json">{"@context":...}</script>
/// ```
///
/// The named factories cover the most common rich-result types; every
/// other Schema.org type works through the generic constructor:
///
/// ```dart
/// SeoSchema('Recipe', {'name': 'Linsensuppe', 'cookTime': 'PT45M'});
/// ```
class SeoSchema {
  /// A schema of any Schema.org [type] with raw [properties].
  ///
  /// `@context` and `@type` are added automatically; entries with a
  /// `null` value are dropped.
  SeoSchema(this.type, [Map<String, Object?> properties = const {}])
      : properties = Map.unmodifiable(
          Map.of(properties)..removeWhere((_, value) => value == null),
        );

  /// An `Article` — for blog posts and news pages.
  factory SeoSchema.article({
    required String headline,
    String? description,
    String? image,
    String? author,
    DateTime? datePublished,
    DateTime? dateModified,
    String? url,
  }) =>
      SeoSchema('Article', {
        'headline': headline,
        'description': description,
        'image': image,
        if (author != null) 'author': {'@type': 'Person', 'name': author},
        'datePublished': datePublished?.toIso8601String(),
        'dateModified': dateModified?.toIso8601String(),
        'url': url,
      });

  /// An `Organization` — company name, logo and social profiles.
  factory SeoSchema.organization({
    required String name,
    String? url,
    String? logo,
    List<String> sameAs = const [],
  }) =>
      SeoSchema('Organization', {
        'name': name,
        'url': url,
        'logo': logo,
        if (sameAs.isNotEmpty) 'sameAs': sameAs,
      });

  /// A `WebSite`, optionally with a search box for the sitelinks
  /// search feature ([searchUrlTemplate] e.g.
  /// `https://example.com/suche?q={search_term_string}`).
  factory SeoSchema.website({
    required String name,
    required String url,
    String? searchUrlTemplate,
  }) =>
      SeoSchema('WebSite', {
        'name': name,
        'url': url,
        if (searchUrlTemplate != null)
          'potentialAction': {
            '@type': 'SearchAction',
            'target': searchUrlTemplate,
            'query-input': 'required name=search_term_string',
          },
      });

  /// A `Product` with an optional price offer.
  factory SeoSchema.product({
    required String name,
    String? description,
    String? image,
    String? brand,
    double? price,
    String? priceCurrency,
    String? url,
  }) =>
      SeoSchema('Product', {
        'name': name,
        'description': description,
        'image': image,
        if (brand != null) 'brand': {'@type': 'Brand', 'name': brand},
        'url': url,
        if (price != null)
          'offers': {
            '@type': 'Offer',
            'price': price.toStringAsFixed(2),
            if (priceCurrency != null) 'priceCurrency': priceCurrency,
          },
      });

  /// A `BreadcrumbList` — the page's position in the site hierarchy.
  ///
  /// ```dart
  /// SeoSchema.breadcrumbs([
  ///   (name: 'Start', url: 'https://example.com/'),
  ///   (name: 'Blog', url: 'https://example.com/blog'),
  /// ]);
  /// ```
  factory SeoSchema.breadcrumbs(List<({String name, String url})> items) =>
      SeoSchema('BreadcrumbList', {
        'itemListElement': [
          for (var i = 0; i < items.length; i++)
            {
              '@type': 'ListItem',
              'position': i + 1,
              'name': items[i].name,
              'item': items[i].url,
            },
        ],
      });

  /// A `FAQPage` from question/answer pairs.
  factory SeoSchema.faq(List<({String question, String answer})> entries) =>
      SeoSchema('FAQPage', {
        'mainEntity': [
          for (final entry in entries)
            {
              '@type': 'Question',
              'name': entry.question,
              'acceptedAnswer': {'@type': 'Answer', 'text': entry.answer},
            },
        ],
      });

  /// The Schema.org type, e.g. `Article` or `Product`.
  final String type;

  /// All properties except `@context`/`@type`, without null values.
  final Map<String, Object?> properties;

  /// The complete JSON-LD object including `@context` and `@type`.
  Map<String, Object?> toJson() => {
        '@context': 'https://schema.org',
        '@type': type,
        ...properties,
      };

  /// The JSON string for the script block.
  ///
  /// `<` is escaped as `\\u003C` (the standard JSON escape for the same
  /// character), so content can never break out of the surrounding
  /// `</script>` context.
  String toJsonString() => jsonEncode(toJson()).replaceAll('<', '\\u003C');

  /// This schema as a `<script type="application/ld+json">` node.
  SeoNode toNode() => SeoNode(
        tag: 'script',
        attributes: {'type': 'application/ld+json'},
        rawText: toJsonString(),
      );
}
