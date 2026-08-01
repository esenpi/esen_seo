import 'package:flutter/widgets.dart';

import '../meta/seo_schema.dart';
import '../renderer/seo_node.dart';
import 'seo_block.dart';

/// One step of a [SeoBreadcrumbs] trail.
class SeoBreadcrumbEntry {
  const SeoBreadcrumbEntry(this.label, {this.url});

  /// The visible label, e.g. `Blog`.
  final String label;

  /// The target URL. Leave it `null` (or blank) for the current page —
  /// that step is mirrored as plain text instead of a link.
  final String? url;

  /// The usable URL, or `null` when this step is not a link. One
  /// definition for the widget, the mirror and the structured data —
  /// otherwise the three can disagree about what counts as a link.
  String? get href {
    final value = url?.trim();
    return (value == null || value.isEmpty) ? null : value;
  }
}

/// A breadcrumb trail that mirrors itself as real HTML.
///
/// Breadcrumbs tell search engines how a page sits in the site
/// hierarchy — and Google shows them instead of the bare URL in the
/// result. This widget renders a tappable trail on every platform and
/// mirrors as `<nav><ol><li>` markup with real links.
///
/// ```dart
/// SeoBreadcrumbs(
///   items: [
///     SeoBreadcrumbEntry('Start', url: '/'),
///     SeoBreadcrumbEntry('Blog', url: '/blog'),
///     SeoBreadcrumbEntry('Flutter SEO'),   // aktuelle Seite
///   ],
///   onTap: (item) => context.go(item.url!),
/// )
/// ```
///
/// For the breadcrumb rich result, pair it with the structured data —
/// [schemaFor] takes the same list and needs absolute URLs:
///
/// ```dart
/// SeoMeta(schemas: [SeoBreadcrumbs.schemaFor(items, base: siteBase)])
/// ```
class SeoBreadcrumbs extends SeoBlock {
  const SeoBreadcrumbs({
    super.key,
    required this.items,
    this.separator = '/',
    this.onTap,
    this.textStyle,
    this.linkStyle,
    this.label = 'Breadcrumb',
  });

  /// The trail from the root to the current page.
  final List<SeoBreadcrumbEntry> items;

  /// Separator between the steps — decorative only, so it is hidden
  /// from assistive technology in the mirror.
  final String separator;

  /// Called when a step with a URL is tapped.
  final void Function(SeoBreadcrumbEntry item)? onTap;

  /// Style of the current (non-link) step.
  final TextStyle? textStyle;

  /// Style of the linked steps.
  final TextStyle? linkStyle;

  /// Accessible name of the `<nav>` landmark.
  final String label;

  /// The `BreadcrumbList` structured data for [items], or `null` when
  /// there is nothing to describe — an empty list would be an invalid
  /// rich result.
  ///
  /// Relative URLs are resolved against [base]. Steps in the middle of
  /// the trail need a URL and are skipped without one; the final step
  /// may omit it, because search engines fall back to the page's own
  /// address there.
  static SeoSchema? schemaFor(
    List<SeoBreadcrumbEntry> items, {
    String base = '',
  }) {
    if (items.isEmpty) return null;
    final trimmed =
        base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    String? absolute(String? href) =>
        href == null ? null : (href.startsWith('/') ? '$trimmed$href' : href);

    final entries = <({String name, String? url})>[
      for (var i = 0; i < items.length; i++)
        if (items[i].href != null || i == items.length - 1)
          (name: items[i].label, url: absolute(items[i].href)),
    ];
    return entries.isEmpty ? null : SeoSchema.breadcrumbs(entries);
  }

  @override
  Widget buildFlutter(BuildContext context) =>
      items.isEmpty ? const SizedBox.shrink() : _buildTrail();

  Widget _buildTrail() {
    final children = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final isLink = item.href != null && onTap != null;
      children.add(
        isLink
            ? GestureDetector(
                onTap: () => onTap!(item),
                child: Text(
                  item.label,
                  style: linkStyle ??
                      const TextStyle(
                        color: Color(0xFF0B57D0),
                        decoration: TextDecoration.underline,
                      ),
                ),
              )
            : Text(item.label, style: textStyle),
      );
      if (i < items.length - 1) {
        children.add(Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text(separator, style: textStyle),
        ));
      }
    }
    return Wrap(
        crossAxisAlignment: WrapCrossAlignment.center, children: children);
  }

  @override
  List<SeoNode> toSeoNodes() => items.isEmpty
      ? const []
      : [
          SeoNode(
            tag: 'nav',
            // nav carries the navigation role, where an accessible name
            // is allowed — unlike a bare <p> or <div>.
            attributes: {'class': 'esen-seo-breadcrumbs', 'aria-label': label},
            children: [
              SeoNode(tag: 'ol', children: [
                for (var i = 0; i < items.length; i++)
                  SeoNode(tag: 'li', children: [
                    _stepNode(items[i], isCurrent: i == items.length - 1),
                    if (i < items.length - 1 && separator.isNotEmpty)
                      SeoNode(
                        tag: 'span',
                        text: separator,
                        attributes: const {'aria-hidden': 'true'},
                      ),
                  ]),
              ]),
            ],
          ),
        ];

  /// Only the final step is the current page — a step in the middle
  /// without a URL is simply not a link, not a second "you are here".
  SeoNode _stepNode(SeoBreadcrumbEntry item, {required bool isCurrent}) {
    final href = item.href;
    final current = isCurrent ? const {'aria-current': 'page'} : const {};
    if (href == null) {
      return SeoNode(tag: 'span', text: item.label, attributes: {...current});
    }
    return SeoNode(
      tag: 'a',
      text: item.label,
      attributes: {'href': href, ...current},
    );
  }
}
