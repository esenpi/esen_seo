import 'package:flutter/widgets.dart';

import '../extensions/widget_seo.dart';
import '../renderer/seo_node.dart';

/// A customer quote that mirrors itself as real HTML.
///
/// Testimonials are standard on landing pages and usually built from
/// styled containers — which leaves crawlers with nothing but loose
/// text. This widget renders the quote on every platform and mirrors it
/// as a proper `<figure>` with `<blockquote>` and an attribution:
///
/// ```dart
/// SeoTestimonial(
///   quote: 'Unsere Flutter-Web-App rankt endlich bei Google.',
///   author: 'Maria Schmidt',
///   role: 'CTO, Beispiel GmbH',
///   sourceUrl: 'https://example.com/case-study',
/// )
/// ```
///
/// The quote is on-page content. For review stars in search results,
/// add the matching structured data via `SeoSchema.review` — the two
/// complement each other.
class SeoTestimonial extends StatelessWidget {
  const SeoTestimonial({
    super.key,
    required this.quote,
    this.author,
    this.role,
    this.sourceUrl,
    this.quoteStyle,
    this.authorStyle,
    this.accentColor = const Color(0xFFD1D5DB),
  });

  /// The quoted text, without quotation marks — those are styling.
  final String quote;

  /// Who said it.
  final String? author;

  /// Their role or company, e.g. `CTO, Beispiel GmbH`.
  final String? role;

  /// Where the quote comes from — mirrored as the `cite` attribute.
  final String? sourceUrl;

  /// Style of the quote text.
  final TextStyle? quoteStyle;

  /// Style of the attribution line.
  final TextStyle? authorStyle;

  /// Color of the quote bar on the left.
  final Color accentColor;

  /// `Maria Schmidt, CTO` — whatever of the two is present.
  String? get _attribution {
    final parts = [
      if (author != null && author!.isNotEmpty) author!,
      if (role != null && role!.isNotEmpty) role!,
    ];
    return parts.isEmpty ? null : parts.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    return _buildQuote().seoNodes(_toNodes());
  }

  Widget _buildQuote() {
    final attribution = _attribution;
    return Container(
      padding: const EdgeInsets.only(left: 16),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: accentColor, width: 3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            quote,
            style: quoteStyle ??
                const TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
          ),
          if (attribution != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '— $attribution',
                style: authorStyle ??
                    const TextStyle(fontSize: 13, color: Color(0xFF4A4A4A)),
              ),
            ),
        ],
      ),
    );
  }

  List<SeoNode> _toNodes() {
    final attribution = _attribution;
    return [
      SeoNode(
        tag: 'figure',
        attributes: const {'class': 'esen-seo-testimonial'},
        children: [
          SeoNode(
            tag: 'blockquote',
            attributes: {
              if (sourceUrl != null && sourceUrl!.isNotEmpty)
                'cite': sourceUrl!,
            },
            children: [SeoNode(tag: 'p', text: quote)],
          ),
          // Die Zuschreibung gehört laut HTML-Spezifikation NEBEN das
          // blockquote, nicht hinein — sie ist nicht Teil des Zitats.
          if (attribution != null)
            SeoNode(tag: 'figcaption', text: '— $attribution'),
        ],
      ),
    ];
  }
}
