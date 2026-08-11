import 'package:flutter/widgets.dart';

import '../components/seo_components.dart';
import '../components/seo_tabs_transition.dart';
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
/// By default the panels stay plain sections with headings. Supplying a valid
/// [interactionId] marks that complete document structure for optional,
/// package-owned progressive enhancement in a visible HTML page. The static
/// source remains readable when JavaScript is unavailable.
class SeoTabs extends StatefulWidget {
  const SeoTabs({
    super.key,
    required this.tabs,
    this.initialIndex = 0,
    this.headingLevel = 3,
    this.interactionId,
    this.interactionLabel = 'Tabs',
    this.transition = transitionSeoTabs,
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

  /// Stable DOM id that opts the semantic HTML into JavaScript enhancement.
  ///
  /// It must start with an ASCII letter and then contain only letters,
  /// digits, `_` or `-`, up to 128 characters. Invalid values leave the
  /// semantic output static and fully visible.
  final String? interactionId;

  /// Accessible label of the enhanced tab list.
  final String interactionLabel;

  /// Pure selection logic shared with an optional application web runtime.
  final SeoTabsTransition transition;

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
  late SeoTabsState _tabsState = initialSeoTabsState(
    count: widget.tabs.length,
    index: widget.initialIndex,
  );

  int get _index => _tabsState.index;

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
      _tabsState = initialSeoTabsState(
        count: widget.tabs.length,
        index: widget.initialIndex,
      );
    } else {
      _tabsState = initialSeoTabsState(
        count: widget.tabs.length,
        index: _index,
      );
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
      onTap: () => setState(() {
        _tabsState = applySeoTabsTransition(
          widget.transition,
          _tabsState,
          SeoTabsSelect(index),
        );
      }),
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
        interactionId: widget.interactionId,
        interactionLabel: widget.interactionLabel,
        initialIndex: widget.initialIndex,
      );
}
