import 'package:flutter/widgets.dart';

import '../controller/seo_controller.dart';
import '../extensions/widget_seo.dart';
import '../renderer/seo_node.dart';

/// The contract every widget in the SEO library follows: one component,
/// one data model, two presentations.
///
/// A bridge widget exists because the mirror cannot see its content —
/// a closed submenu, an off-screen list entry, an inactive tab panel, a
/// painted chart. It therefore has to state that content twice: once as
/// Flutter widgets, once as HTML. The danger is that the two drift
/// apart, and that is not hypothetical: `SeoNavMenu` and
/// `SeoBreadcrumbs` each shipped with *three* disagreeing notions of
/// what counts as a link — the screen offered one, the mirror called it
/// the current page, the structured data dropped it.
///
/// This class makes the shape explicit so the two views are always
/// derived from the same source:
///
/// ```dart
/// class SeoSpecs extends SeoBlock {
///   const SeoSpecs(this.rows, {super.key});
///   final List<(String, String)> rows;   // die eine Quelle
///
///   @override
///   Widget buildFlutter(BuildContext context) => Column(children: [
///         for (final (name, value) in rows) Text('$name: $value'),
///       ]);
///
///   @override
///   List<SeoNode> toSeoNodes() => [
///         SeoNode(tag: 'dl', children: [
///           for (final (name, value) in rows) ...[
///             SeoNode(tag: 'dt', text: name),
///             SeoNode(tag: 'dd', text: value),
///           ],
///         ]),
///       ];
/// }
/// ```
///
/// Structured data stays out of this contract on purpose: only a few
/// blocks have any, and it is needed when the page metadata is built,
/// not when the widget is. Those blocks expose it as a static helper
/// instead — see `SeoFaq.schemaFor` and `SeoBreadcrumbs.schemaFor`.
///
/// On non-web platforms [toSeoNodes] is never rendered; the widget is
/// exactly what [buildFlutter] returns.
abstract class SeoBlock extends StatelessWidget {
  const SeoBlock({super.key});

  /// The visible Flutter widget, built on every platform.
  Widget buildFlutter(BuildContext context);

  /// The same content as semantic HTML, mirrored on web.
  List<SeoNode> toSeoNodes();

  @override
  Widget build(BuildContext context) {
    // Auf Mobile und Desktop gibt es keinen Spiegel — dann darf
    // [toSeoNodes] gar nicht erst laufen. Bei einer langen Liste wäre
    // das sonst pro Build eine vollständige Übersetzung, deren Ergebnis
    // niemand ansieht.
    if (!SeoController.enabled) return buildFlutter(context);
    return buildFlutter(context).seoNodes(toSeoNodes());
  }
}

/// The [SeoBlock] contract for blocks that carry state.
///
/// Tabs, menus and accordions keep a selection or an open set, so their
/// Flutter side is stateful — but the mirror must stay independent of
/// it: what is on screen may change, what crawlers read may not.
///
/// ```dart
/// class _MyTabsState extends State<MyTabs> with SeoBlockState<MyTabs> {
///   @override
///   Widget buildFlutter(BuildContext context) => …;
///   @override
///   List<SeoNode> toSeoNodes() => …;   // alle Panels, nicht nur das offene
/// }
/// ```
mixin SeoBlockState<T extends StatefulWidget> on State<T> {
  /// The visible Flutter widget for the current state.
  Widget buildFlutter(BuildContext context);

  /// The complete content as semantic HTML — independent of what is
  /// currently selected, expanded or scrolled into view.
  List<SeoNode> toSeoNodes();

  @override
  Widget build(BuildContext context) {
    // Auf Mobile und Desktop gibt es keinen Spiegel — dann darf
    // [toSeoNodes] gar nicht erst laufen. Bei einer langen Liste wäre
    // das sonst pro Build eine vollständige Übersetzung, deren Ergebnis
    // niemand ansieht.
    if (!SeoController.enabled) return buildFlutter(context);
    return buildFlutter(context).seoNodes(toSeoNodes());
  }
}
