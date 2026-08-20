import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';

import '../components/seo_collection_transition.dart';
import '../components/seo_components.dart';
import '../renderer/seo_node.dart';
import 'seo_block.dart';

typedef _SeoCollectionData = ({
  List<String> categories,
  List<SeoCollectionRecord> records,
});

final class _SeoCollectionQueryFormatter extends TextInputFormatter {
  const _SeoCollectionQueryFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final bounded = boundSeoCollectionQuery(newValue.text);
    if (bounded == newValue.text) return newValue;
    final requestedOffset = newValue.selection.extentOffset;
    final offset = requestedOffset < 0
        ? bounded.length
        : requestedOffset > bounded.length
            ? bounded.length
            : requestedOffset;
    return TextEditingValue(
      text: bounded,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}

/// One complete item in a [SeoCollection].
class SeoCollectionEntry {
  const SeoCollectionEntry({
    required this.title,
    required this.searchText,
    required this.categories,
    required this.sortKey,
    required this.content,
    required this.nodes,
  });

  final String title;
  final String searchText;
  final List<String> categories;
  final int sortKey;
  final Widget content;
  final List<SeoNode> nodes;
}

/// A complete collection with shared search, category, sort and page state.
///
/// Flutter and the DOM-first adapter dispatch the same closed actions into the
/// same pure transition. The semantic source always contains every item and
/// native link; JavaScript only changes the visible subset after validating the
/// complete component contract.
class SeoCollection extends StatefulWidget {
  const SeoCollection({
    super.key,
    required this.items,
    this.interactionId,
    this.interactionLabel = 'Collection',
    this.pageSize = 12,
    this.initialSort = SeoCollectionSort.newest,
    this.transition = transitionSeoCollection,
    this.searchLabel = 'Search',
    this.categoriesLabel = 'Categories',
    this.allCategoriesLabel = 'All',
    this.sortLabel = 'Sort',
    this.newestLabel = 'Newest',
    this.oldestLabel = 'Oldest',
    this.titleLabel = 'Title',
    this.previousLabel = 'Previous',
    this.nextLabel = 'Next',
    this.resultsLabel = 'results',
    this.noResultsLabel = 'No results',
    this.pageLabel = 'Page',
    this.synchronizeUrl = false,
    this.controlTextStyle,
    this.selectedColor = const Color(0xFF2563EB),
    this.borderColor = const Color(0xFF94A3B8),
    this.controlBackgroundColor = const Color(0x00000000),
    this.itemSpacing = 12,
  });

  final List<SeoCollectionEntry> items;
  final String? interactionId;
  final String interactionLabel;
  final int pageSize;
  final SeoCollectionSort initialSort;

  /// Pure state logic shared with an optional application web runtime.
  final SeoCollectionTransition transition;
  final String searchLabel;
  final String categoriesLabel;
  final String allCategoriesLabel;
  final String sortLabel;
  final String newestLabel;
  final String oldestLabel;
  final String titleLabel;
  final String previousLabel;
  final String nextLabel;
  final String resultsLabel;
  final String noResultsLabel;
  final String pageLabel;

  /// Whether the DOM-first presentation stores collection state in the URL.
  ///
  /// Native Flutter presentations keep local state; browser history exists
  /// only on the permanent HTML presentation. The application-owned
  /// collection runtime currently requires this to remain false; package-owned
  /// collection enhancement supports it.
  final bool synchronizeUrl;
  final TextStyle? controlTextStyle;
  final Color selectedColor;
  final Color borderColor;
  final Color controlBackgroundColor;
  final double itemSpacing;

  @override
  State<SeoCollection> createState() => _SeoCollectionState();
}

class _SeoCollectionState extends State<SeoCollection>
    with SeoBlockState<SeoCollection> {
  late SeoCollectionState _state;
  late _SeoCollectionData _collectionData;
  late final TextEditingController _queryController;
  late final FocusNode _queryFocus;

  @override
  void initState() {
    super.initState();
    _state = SeoCollectionState(sort: widget.initialSort);
    _collectionData = _createData(widget.items);
    _queryController = TextEditingController();
    _queryFocus = FocusNode(debugLabel: 'SeoCollection search');
  }

  @override
  void didUpdateWidget(SeoCollection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldCategories = _collectionData.categories;
    final selectedLabel = switch (_state.categoryIndex) {
      final index? when index >= 0 && index < oldCategories.length =>
        normalizeSeoCollectionText(oldCategories[index]),
      _ => null,
    };
    _collectionData = _createData(widget.items);
    final data = _collectionData;
    final selectedIndex = selectedLabel == null
        ? null
        : data.categories.indexWhere(
            (label) => normalizeSeoCollectionText(label) == selectedLabel,
          );
    _state = selectSeoCollection(
      records: data.records,
      categoryCount: data.categories.length,
      pageSize: widget.pageSize,
      state: SeoCollectionState(
        query: _state.query,
        categoryIndex:
            selectedIndex == null || selectedIndex < 0 ? null : selectedIndex,
        sort: widget.initialSort != oldWidget.initialSort
            ? widget.initialSort
            : _state.sort,
        page: _state.page,
      ),
    ).state;
  }

  @override
  void dispose() {
    _queryController.dispose();
    _queryFocus.dispose();
    super.dispose();
  }

  List<String> _categoryLabels(List<SeoCollectionEntry> items) =>
      seoCollectionCategoryLabels(items.map((item) => item.categories));

  _SeoCollectionData _createData(List<SeoCollectionEntry> items) {
    final categories = _categoryLabels(items);
    return (
      categories: categories,
      records: List<SeoCollectionRecord>.unmodifiable([
        for (final item in items)
          SeoCollectionRecord(
            title: item.title,
            searchText: item.searchText,
            categoryIndexes:
                seoCollectionCategoryIndexes(item.categories, categories),
            sortKey: item.sortKey,
          ),
      ]),
    );
  }

  SeoCollectionSnapshot _snapshot() => selectSeoCollection(
        records: _collectionData.records,
        categoryCount: _collectionData.categories.length,
        pageSize: widget.pageSize,
        state: _state,
      );

  bool _canApply(SeoCollectionAction action) => canApplySeoCollectionAction(
        widget.transition,
        _state,
        action,
        records: _collectionData.records,
        categoryCount: _collectionData.categories.length,
        pageSize: widget.pageSize,
      );

  void _dispatch(SeoCollectionAction action) {
    final next = applySeoCollectionTransition(
      widget.transition,
      _state,
      action,
      records: _collectionData.records,
      categoryCount: _collectionData.categories.length,
      pageSize: widget.pageSize,
    );
    if (!mounted) return;
    if (_queryController.text != next.query) {
      _queryController.value = TextEditingValue(
        text: next.query,
        selection: TextSelection.collapsed(offset: next.query.length),
      );
    }
    setState(() => _state = next);
  }

  @override
  Widget buildFlutter(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();
    final snapshot = _snapshot();
    final categories = _collectionData.categories;
    final style = widget.controlTextStyle ?? DefaultTextStyle.of(context).style;
    final spacing = widget.itemSpacing.isFinite && widget.itemSpacing >= 0
        ? widget.itemSpacing
        : 12.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.searchLabel, style: style),
        const SizedBox(height: 6),
        Semantics(
          textField: true,
          label: widget.searchLabel,
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: widget.controlBackgroundColor,
              border: Border.all(color: widget.borderColor),
              borderRadius: BorderRadius.circular(6),
            ),
            child: EditableText(
              controller: _queryController,
              focusNode: _queryFocus,
              style: style,
              cursorColor: widget.selectedColor,
              backgroundCursorColor: widget.borderColor,
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.search,
              inputFormatters: const [_SeoCollectionQueryFormatter()],
              onChanged: (query) => _dispatch(SeoCollectionSetQuery(query)),
            ),
          ),
        ),
        if (categories.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(widget.categoriesLabel, style: style),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _control(
                label: widget.allCategoriesLabel,
                selected: snapshot.state.categoryIndex == null,
                onTap: () => _dispatch(const SeoCollectionSelectCategory(null)),
              ),
              for (var index = 0; index < categories.length; index++)
                _control(
                  label: categories[index],
                  selected: snapshot.state.categoryIndex == index,
                  onTap: () => _dispatch(SeoCollectionSelectCategory(index)),
                ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        Text(widget.sortLabel, style: style),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _control(
              label: widget.newestLabel,
              selected: snapshot.state.sort == SeoCollectionSort.newest,
              onTap: () => _dispatch(
                const SeoCollectionSetSort(SeoCollectionSort.newest),
              ),
            ),
            _control(
              label: widget.oldestLabel,
              selected: snapshot.state.sort == SeoCollectionSort.oldest,
              onTap: () => _dispatch(
                const SeoCollectionSetSort(SeoCollectionSort.oldest),
              ),
            ),
            _control(
              label: widget.titleLabel,
              selected: snapshot.state.sort == SeoCollectionSort.title,
              onTap: () => _dispatch(
                const SeoCollectionSetSort(SeoCollectionSort.title),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Semantics(
          liveRegion: true,
          child: Text(
            snapshot.matchCount == 0
                ? widget.noResultsLabel
                : '${snapshot.matchCount} ${widget.resultsLabel}',
            style: style,
          ),
        ),
        const SizedBox(height: 12),
        if (snapshot.visibleIndices.isEmpty)
          const SizedBox.shrink()
        else
          for (final (position, index) in snapshot.visibleIndices.indexed) ...[
            KeyedSubtree(
              key: ValueKey('${widget.items[index].title}-$index'),
              child: widget.items[index].content,
            ),
            if (position < snapshot.visibleIndices.length - 1)
              SizedBox(height: spacing),
          ],
        if (snapshot.pageCount > 1) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              _control(
                label: widget.previousLabel,
                visibleLabel: '\u2039',
                enabled: _canApply(const SeoCollectionPreviousPage()),
                onTap: () => _dispatch(const SeoCollectionPreviousPage()),
              ),
              Expanded(
                child: Text(
                  '${widget.pageLabel} ${snapshot.state.page + 1} / '
                  '${snapshot.pageCount}',
                  textAlign: TextAlign.center,
                  style: style,
                ),
              ),
              _control(
                label: widget.nextLabel,
                visibleLabel: '\u203a',
                enabled: _canApply(const SeoCollectionNextPage()),
                onTap: () => _dispatch(const SeoCollectionNextPage()),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _control({
    required String label,
    required VoidCallback onTap,
    bool selected = false,
    bool enabled = true,
    String? visibleLabel,
  }) =>
      _SeoCollectionControl(
        label: label,
        visibleLabel: visibleLabel ?? label,
        selected: selected,
        enabled: enabled,
        selectedColor: widget.selectedColor,
        borderColor: widget.borderColor,
        backgroundColor: widget.controlBackgroundColor,
        textStyle: widget.controlTextStyle,
        onTap: onTap,
      );

  @override
  List<SeoNode> toSeoNodes() => buildSeoCollectionNodes(
        items: [
          for (final item in widget.items)
            (
              title: item.title,
              searchText: item.searchText,
              categories: item.categories,
              sortKey: item.sortKey,
              nodes: item.nodes,
            ),
        ],
        interactionId: widget.interactionId,
        interactionLabel: widget.interactionLabel,
        pageSize: widget.pageSize,
        initialSort: widget.initialSort,
        searchLabel: widget.searchLabel,
        categoriesLabel: widget.categoriesLabel,
        allCategoriesLabel: widget.allCategoriesLabel,
        sortLabel: widget.sortLabel,
        newestLabel: widget.newestLabel,
        oldestLabel: widget.oldestLabel,
        titleLabel: widget.titleLabel,
        previousLabel: widget.previousLabel,
        nextLabel: widget.nextLabel,
        resultsLabel: widget.resultsLabel,
        noResultsLabel: widget.noResultsLabel,
        pageLabel: widget.pageLabel,
        synchronizeUrl: widget.synchronizeUrl,
      );
}

class _SeoCollectionControl extends StatefulWidget {
  const _SeoCollectionControl({
    required this.label,
    required this.visibleLabel,
    required this.selected,
    required this.enabled,
    required this.selectedColor,
    required this.borderColor,
    required this.backgroundColor,
    required this.textStyle,
    required this.onTap,
  });

  final String label;
  final String visibleLabel;
  final bool selected;
  final bool enabled;
  final Color selectedColor;
  final Color borderColor;
  final Color backgroundColor;
  final TextStyle? textStyle;
  final VoidCallback onTap;

  @override
  State<_SeoCollectionControl> createState() => _SeoCollectionControlState();
}

class _SeoCollectionControlState extends State<_SeoCollectionControl> {
  bool _focused = false;
  bool _hovered = false;

  void _activate() {
    if (widget.enabled) widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final emphasized = widget.selected || _focused || _hovered;
    final color = emphasized ? widget.selectedColor : widget.borderColor;
    return Semantics(
      button: true,
      enabled: widget.enabled,
      selected: widget.selected,
      label: widget.label,
      child: Opacity(
        opacity: widget.enabled ? 1 : 0.4,
        child: MouseRegion(
          cursor: widget.enabled
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: FocusableActionDetector(
            enabled: widget.enabled,
            onShowFocusHighlight: (value) => setState(() => _focused = value),
            actions: {
              ActivateIntent: CallbackAction<ActivateIntent>(
                onInvoke: (_) {
                  _activate();
                  return null;
                },
              ),
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.enabled ? _activate : null,
              child: Container(
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: widget.backgroundColor,
                  border: Border.all(color: color, width: emphasized ? 2 : 1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: ExcludeSemantics(
                  child: Text(
                    widget.visibleLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: widget.textStyle?.copyWith(
                      color: widget.selected ? widget.selectedColor : null,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
