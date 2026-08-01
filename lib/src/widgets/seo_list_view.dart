import 'package:flutter/widgets.dart';

import '../renderer/seo_node.dart';
import 'seo_block.dart';

/// Builds the HTML translation of one list item.
typedef SeoListNodeBuilder<T> = List<SeoNode> Function(T item, int index);

/// A lazily built list whose **complete** content reaches the mirror.
///
/// This closes the widest silent SEO hole in Flutter Web. A
/// `ListView.builder` only builds the items currently in the viewport,
/// so a blog index with two hundred entries mirrors maybe eight of
/// them — everything below the fold is invisible to crawlers, and
/// nothing about the page looks wrong while it happens.
///
/// [SeoListView] keeps the data, not just the built widgets: Flutter
/// still renders lazily, while the mirror gets every single entry.
///
/// ```dart
/// SeoListView<Post>(
///   items: posts,
///   itemBuilder: (context, post, i) => PostCard(post),
///   nodeBuilder: (post, i) => [
///     SeoNode(tag: 'article', children: [
///       SeoNode(tag: 'h2', children: [
///         SeoNode(tag: 'a', text: post.title,
///             attributes: {'href': '/blog/${post.slug}'}),
///       ]),
///       SeoNode(tag: 'p', text: post.teaser),
///     ]),
///   ],
/// )
/// ```
///
/// Wrap the entries in a list element with [listTag] (`ul`/`ol`) when
/// the order or the count carries meaning; the default `div` keeps the
/// markup out of the way for card grids and feeds.
class SeoListView<T> extends SeoBlock {
  const SeoListView({
    super.key,
    required this.items,
    required this.itemBuilder,
    required this.nodeBuilder,
    this.listTag = 'div',
    this.itemTag,
    this.scrollDirection = Axis.vertical,
    this.shrinkWrap = false,
    this.physics,
    this.padding,
    this.separatorBuilder,
    this.attributes = const {},
  });

  /// The full data set — every entry reaches the mirror, however few
  /// of them Flutter builds.
  final List<T> items;

  /// Builds the visible Flutter widget for an entry.
  final Widget Function(BuildContext context, T item, int index) itemBuilder;

  /// Builds the HTML nodes for an entry.
  final SeoListNodeBuilder<T> nodeBuilder;

  /// Element wrapping the list, e.g. `ul`, `ol` or `div`.
  final String listTag;

  /// Element wrapping each entry. Defaults to `li` inside `ul`/`ol`,
  /// otherwise the entry's nodes are emitted directly.
  final String? itemTag;

  /// Scroll axis of the Flutter list.
  final Axis scrollDirection;

  /// Whether the Flutter list shrink-wraps its content.
  final bool shrinkWrap;

  /// Scroll physics of the Flutter list.
  final ScrollPhysics? physics;

  /// Padding around the Flutter list.
  final EdgeInsetsGeometry? padding;

  /// Optional separator between the visible entries. Separators are
  /// decoration and deliberately stay out of the mirror.
  final Widget Function(BuildContext context, int index)? separatorBuilder;

  /// Extra HTML attributes for the wrapping element.
  final Map<String, String> attributes;

  /// A blank tag means "no wrapper" — never an empty element name,
  /// which would silently swallow the entries.
  String? get _itemTag {
    final explicit = itemTag?.trim();
    if (explicit != null) return explicit.isEmpty ? null : explicit;
    const listElements = {'ul', 'ol', 'menu'};
    return listElements.contains(_listTag.toLowerCase()) ? 'li' : null;
  }

  String get _listTag => listTag.trim().isEmpty ? 'div' : listTag.trim();

  @override
  Widget buildFlutter(BuildContext context) {
    final separator = separatorBuilder;
    if (separator != null) {
      return ListView.separated(
        scrollDirection: scrollDirection,
        shrinkWrap: shrinkWrap,
        physics: physics,
        padding: padding,
        itemCount: items.length,
        separatorBuilder: separator,
        itemBuilder: (context, index) =>
            itemBuilder(context, items[index], index),
      );
    }
    return ListView.builder(
      scrollDirection: scrollDirection,
      shrinkWrap: shrinkWrap,
      physics: physics,
      padding: padding,
      itemCount: items.length,
      itemBuilder: (context, index) =>
          itemBuilder(context, items[index], index),
    );
  }

  @override
  List<SeoNode> toSeoNodes() {
    final wrap = _itemTag;
    final children = <SeoNode>[];
    for (var i = 0; i < items.length; i++) {
      final nodes = nodeBuilder(items[i], i);
      if (nodes.isEmpty) continue;
      if (wrap == null) {
        children.addAll(nodes);
      } else {
        children.add(SeoNode(tag: wrap, children: nodes));
      }
    }
    if (children.isEmpty) return const [];
    return [
      SeoNode(
        tag: _listTag,
        attributes: {'class': 'esen-seo-list', ...attributes},
        children: children,
      ),
    ];
  }
}
