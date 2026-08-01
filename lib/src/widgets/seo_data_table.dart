import 'package:flutter/widgets.dart';

import '../extensions/widget_seo.dart';
import '../renderer/seo_node.dart';

/// A data table that mirrors itself as a real HTML `<table>`.
///
/// Tabular content is some of the most valuable SEO material there is —
/// specs, prices, comparisons — and painted tables lose all of it. This
/// widget renders a plain Flutter [Table] on every platform and mirrors
/// as semantic `<table>` markup with `<caption>`, `<thead>` and
/// `<tbody>` on the web:
///
/// ```dart
/// SeoDataTable(
///   title: 'Technische Daten',
///   columns: ['Merkmal', 'Wert'],
///   rows: [
///     ['Gewicht', '8,4 kg'],
///     ['Rahmen', 'Carbon'],
///   ],
/// )
/// ```
///
/// Rows shorter than [columns] are padded with empty cells, longer rows
/// are truncated — the page never breaks over data shape.
class SeoDataTable extends StatelessWidget {
  const SeoDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.title,
    this.headerStyle,
    this.cellStyle,
    this.borderColor = const Color(0xFFD1D5DB),
  });

  /// The column headers.
  final List<String> columns;

  /// The body rows; each row lists its cells in column order.
  final List<List<String>> rows;

  /// Optional caption — rendered above the table and as `<caption>`.
  final String? title;

  /// Style of the header cells.
  final TextStyle? headerStyle;

  /// Style of the body cells.
  final TextStyle? cellStyle;

  /// Color of the table borders.
  final Color borderColor;

  /// Normalizes a row to exactly one cell per column.
  List<String> _cells(List<String> row) => [
        for (var i = 0; i < columns.length; i++) i < row.length ? row[i] : '',
      ];

  @override
  Widget build(BuildContext context) {
    // Ohne Spalten gibt es nichts Sinnvolles zu zeigen — weder für
    // Flutter (Table wirft bei leeren Zeilen) noch für Crawler.
    if (columns.isEmpty) {
      return const SizedBox.shrink().seoNodes(const []);
    }
    return _buildTable(context).seoNodes(_toNodes());
  }

  Widget _buildTable(BuildContext context) {
    Widget cell(String text, {TextStyle? style}) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(text, style: style),
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              title!,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        Table(
          border: TableBorder.all(color: borderColor, width: 1),
          defaultColumnWidth: const IntrinsicColumnWidth(),
          children: [
            TableRow(
              children: [
                for (final column in columns)
                  cell(
                    column,
                    style: headerStyle ??
                        const TextStyle(fontWeight: FontWeight.w600),
                  ),
              ],
            ),
            for (final row in rows)
              TableRow(
                children: [
                  for (final value in _cells(row))
                    cell(value, style: cellStyle),
                ],
              ),
          ],
        ),
      ],
    );
  }

  List<SeoNode> _toNodes() => [
        SeoNode(
          tag: 'table',
          attributes: {'class': 'esen-seo-data-table'},
          children: [
            if (title != null) SeoNode(tag: 'caption', text: title),
            SeoNode(tag: 'thead', children: [
              SeoNode(tag: 'tr', children: [
                for (final column in columns) SeoNode(tag: 'th', text: column),
              ]),
            ]),
            SeoNode(tag: 'tbody', children: [
              for (final row in rows)
                SeoNode(tag: 'tr', children: [
                  for (final value in _cells(row))
                    SeoNode(tag: 'td', text: value),
                ]),
            ]),
          ],
        ),
      ];
}
