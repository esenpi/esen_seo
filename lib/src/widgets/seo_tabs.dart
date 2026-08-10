import 'package:flutter/widgets.dart';

import '../components/seo_components.dart';
import '../renderer/seo_node.dart';
import 'seo_block.dart';

/// One tab of a [SeoTabs] group.
class SeoTab {
  const SeoTab({
    required this.label,
    required this.content,
    required this.nodes,
  });

  /// The tab's caption, e.g. `Technische Daten`.
  final String label;

  /// The panel shown on screen while this tab is selected.
  final Widget content;

  /// The panel's HTML translation — mirrored whether or not this tab
  /// is the selected one.
  final List<SeoNode> nodes;
}

/// A tab group whose **inactive** panels also reach the mirror.
///
/// A `TabBarView` only builds the selected panel, so on a typical
/// product page ("Beschreibung | Technische Daten | Bewertungen") two
/// thirds of the content never exist in the widget tree and stay
/// invisible to crawlers.
///
/// [SeoTabs] keeps every panel as data. Flutter shows one at a time;
/// the mirror contains all of them, each behind its own heading so the
/// document outline stays readable:
///
/// ```dart
/// SeoTabs(
///   tabs: [
///     SeoTab(
///       label: 'Beschreibung',
///       content: const Text('Leichtes Carbon-Rennrad.'),
///       nodes: [SeoNode(tag: 'p', text: 'Leichtes Carbon-Rennrad.')],
///     ),
///     SeoTab(
///       label: 'Technische Daten',
///       content: const SpecsTable(),
///       nodes: [SeoNode(tag: 'p', text: 'Gewicht: 8,4 kg')],
///     ),
///   ],
/// )
/// ```
///
/// The panels are mirrored as sections with headings rather than as an
/// ARIA tab widget: the point is content a crawler can read, and a
/// heading outline serves that better than interactive tab semantics
/// the mirror could not make real anyway.
class SeoTabs extends StatefulWidget {
  const SeoTabs({
    super.key,
    required this.tabs,
    this.initialIndex = 0,
    this.headingLevel = 3,
    this.labelStyle,
    this.selectedLabelStyle,
    this.indicatorColor = const Color(0xFF2563EB),
  });

  /// The tabs, in display order.
  final List<SeoTab> tabs;

  /// Which tab starts selected — clamped into range.
  final int initialIndex;

  /// Heading level of the panel headings in the mirror (`1`–`6`).
  final int headingLevel;

  /// Style of the unselected tab labels.
  final TextStyle? labelStyle;

  /// Style of the selected tab label.
  final TextStyle? selectedLabelStyle;

  /// Color of the selection indicator.
  final Color indicatorColor;

  @override
  State<SeoTabs> createState() => _SeoTabsState();
}

class _SeoTabsState extends State<SeoTabs> with SeoBlockState<SeoTabs> {
  late int _index = widget.tabs.isEmpty
      ? 0
      : widget.initialIndex.clamp(0, widget.tabs.length - 1);

  @override
  void didUpdateWidget(SeoTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tabs.isEmpty) return;
    // Andere Tabs heißt anderer Inhalt: Zeigt dasselbe Widget plötzlich
    // ein anderes Produkt, darf nicht der dritte Reiter des vorherigen
    // offen bleiben — zurück auf den gewünschten Start-Tab.
    var replaced = widget.tabs.length != oldWidget.tabs.length;
    for (var i = 0; !replaced && i < widget.tabs.length; i++) {
      replaced = widget.tabs[i].label != oldWidget.tabs[i].label;
    }
    if (replaced || widget.initialIndex != oldWidget.initialIndex) {
      _index = widget.initialIndex.clamp(0, widget.tabs.length - 1);
    } else if (_index >= widget.tabs.length) {
      _index = widget.tabs.length - 1;
    }
  }

  @override
  Widget buildFlutter(BuildContext context) =>
      widget.tabs.isEmpty ? const SizedBox.shrink() : _buildTabs();

  Widget _buildTabs() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            for (var i = 0; i < widget.tabs.length; i++) _buildLabel(i),
          ],
        ),
        const SizedBox(height: 12),
        widget.tabs[_index].content,
      ],
    );
  }

  Widget _buildLabel(int index) {
    final selected = index == _index;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _index = index),
      child: Container(
        padding: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? widget.indicatorColor : const Color(0x00000000),
              width: 2,
            ),
          ),
        ),
        child: Text(
          widget.tabs[index].label,
          style: selected
              ? (widget.selectedLabelStyle ??
                  const TextStyle(fontWeight: FontWeight.w600))
              : widget.labelStyle,
        ),
      ),
    );
  }

  @override
  List<SeoNode> toSeoNodes() => buildSeoTabsNodes(
        tabs: [
          for (final tab in widget.tabs) (label: tab.label, nodes: tab.nodes),
        ],
        headingLevel: widget.headingLevel,
      );
}
