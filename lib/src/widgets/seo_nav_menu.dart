import 'package:flutter/widgets.dart';

import '../renderer/seo_node.dart';
import 'seo_block.dart';

/// One entry of a [SeoNavMenu], optionally with a submenu.
class SeoNavItem {
  const SeoNavItem(this.label, {this.url, this.children = const []});

  /// The visible label, e.g. `Leistungen`.
  final String label;

  /// The target URL. Entries that only open a submenu leave it `null`.
  final String? url;

  /// Nested entries — mirrored as a nested `<ul>`, arbitrarily deep.
  final List<SeoNavItem> children;

  /// The usable URL, or `null` when this entry is not a link. One
  /// definition for the visible menu and the mirror alike.
  String? get href {
    final value = url?.trim();
    return (value == null || value.isEmpty) ? null : value;
  }
}

/// A navigation menu that mirrors its **whole** structure as real HTML.
///
/// Dropdown and mega menus live in an overlay: while the menu is
/// closed, its entries do not exist in the widget tree at all, so the
/// mirror cannot see them. That hits SEO where it hurts most — internal
/// links are how search engines discover pages and judge their weight.
///
/// This widget keeps the full menu tree as data. Flutter shows the top
/// level and opens submenus on tap; the mirror always contains every
/// entry, nested exactly as declared:
///
/// ```dart
/// SeoNavMenu(
///   items: [
///     SeoNavItem('Start', url: '/'),
///     SeoNavItem('Leistungen', url: '/leistungen', children: [
///       SeoNavItem('Flutter Apps', url: '/leistungen/apps'),
///       SeoNavItem('SEO Beratung', url: '/leistungen/seo'),
///     ]),
///   ],
///   onTap: (item) => context.go(item.url!),
/// )
/// // → <nav><ul><li><a href="/">Start</a></li>
/// //     <li><a href="/leistungen">Leistungen</a>
/// //       <ul><li><a href="/leistungen/apps">Flutter Apps</a></li>…</ul>
/// //     </li></ul></nav>
/// ```
class SeoNavMenu extends StatefulWidget {
  const SeoNavMenu({
    super.key,
    required this.items,
    this.onTap,
    this.label = 'Hauptnavigation',
    this.direction = Axis.horizontal,
    this.textStyle,
    this.linkStyle,
  });

  /// The menu tree, in display order.
  final List<SeoNavItem> items;

  /// Called when an entry with a URL is tapped.
  final void Function(SeoNavItem item)? onTap;

  /// Accessible name of the `<nav>` landmark — a page may hold several
  /// navigations, and they need to be tellable apart.
  final String label;

  /// Whether the top level runs across (a bar) or down (a sidebar).
  final Axis direction;

  /// Style of entries without a link.
  final TextStyle? textStyle;

  /// Style of the linked entries.
  final TextStyle? linkStyle;

  @override
  State<SeoNavMenu> createState() => _SeoNavMenuState();
}

class _SeoNavMenuState extends State<SeoNavMenu>
    with SeoBlockState<SeoNavMenu> {
  /// Which top-level entries currently show their submenu, keyed by
  /// label — an index would point at a different entry as soon as the
  /// menu changes (a prepended item would open someone else's submenu).
  final Set<String> _open = {};

  @override
  void didUpdateWidget(SeoNavMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Einträge, die es nicht mehr gibt, dürfen nicht als offen gelten.
    final labels = {for (final item in widget.items) item.label};
    _open.removeWhere((label) => !labels.contains(label));
  }

  @override
  Widget buildFlutter(BuildContext context) =>
      widget.items.isEmpty ? const SizedBox.shrink() : _buildMenu();

  Widget _buildMenu() {
    final entries = <Widget>[
      for (var i = 0; i < widget.items.length; i++) _buildTopLevel(i),
    ];
    return widget.direction == Axis.horizontal
        ? Wrap(spacing: 16, runSpacing: 8, children: entries)
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: entries,
          );
  }

  Widget _buildTopLevel(int index) {
    final item = widget.items[index];
    final open = _open.contains(item.label);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _entryLabel(
          item,
          open: open,
          onToggle: item.children.isEmpty
              ? null
              : () => setState(() {
                    open ? _open.remove(item.label) : _open.add(item.label);
                  }),
        ),
        if (open)
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final child in item.children) _entryLabel(child),
              ],
            ),
          ),
      ],
    );
  }

  /// A single row.
  ///
  /// An entry that is a link **and** has a submenu needs both: the
  /// label navigates, and a separate arrow opens the submenu — the
  /// usual pattern for a parent page that also has children. Wiring
  /// both onto the same tap would make one of them unreachable.
  Widget _entryLabel(
    SeoNavItem item, {
    bool open = false,
    VoidCallback? onToggle,
  }) {
    final isLink = item.href != null && widget.onTap != null;
    final text = Text(
      item.label,
      style: isLink
          ? (widget.linkStyle ?? const TextStyle(color: Color(0xFF0B57D0)))
          : widget.textStyle,
    );

    // Ohne Link übernimmt das Label selbst das Auf- und Zuklappen.
    final label = isLink
        ? GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => widget.onTap!(item),
            child: text,
          )
        : (onToggle == null
            ? text
            : GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onToggle,
                child: text,
              ));

    final needsArrow = onToggle != null && isLink;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          label,
          if (needsArrow)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Text(open ? '▾' : '▸', style: widget.textStyle),
              ),
            ),
        ],
      ),
    );
  }

  /// The HTML translation — the complete tree, regardless of what is
  /// open on screen.
  @override
  List<SeoNode> toSeoNodes() => widget.items.isEmpty
      ? const []
      : [
          SeoNode(
            tag: 'nav',
            // nav takes an accessible name; several navigations per page
            // are normal and must be distinguishable.
            attributes: {'class': 'esen-seo-nav', 'aria-label': widget.label},
            children: [_listNode(widget.items)],
          ),
        ];

  SeoNode _listNode(List<SeoNavItem> items) => SeoNode(
        tag: 'ul',
        children: [
          for (final item in items)
            SeoNode(tag: 'li', children: [
              _entryNode(item),
              // Untermenüs gehören INS li des Elternteils — nur so
              // bleibt die Hierarchie für Crawler erkennbar.
              if (item.children.isNotEmpty) _listNode(item.children),
            ]),
        ],
      );

  SeoNode _entryNode(SeoNavItem item) {
    final href = item.href;
    if (href == null) return SeoNode(tag: 'span', text: item.label);
    return SeoNode(tag: 'a', text: item.label, attributes: {'href': href});
  }
}
