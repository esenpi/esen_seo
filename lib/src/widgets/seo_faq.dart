import 'package:flutter/widgets.dart';

import '../components/seo_components.dart';
import '../meta/seo_schema.dart';
import '../renderer/seo_node.dart';
import 'seo_block.dart';

/// One question/answer pair of a [SeoFaq].
class SeoFaqEntry {
  const SeoFaqEntry(this.question, this.answer);

  /// The question, e.g. `Braucht es Puppeteer?`.
  final String question;

  /// The answer in plain text.
  final String answer;
}

/// An FAQ accordion that mirrors itself as real HTML.
///
/// FAQ sections are among the most rewarding SEO content there is —
/// but a collapsed accordion built from painted widgets shows crawlers
/// nothing. This widget renders a plain Flutter accordion on every
/// platform and mirrors every question **and answer** as
/// `<details>`/`<summary>` markup, so the full text is in the page
/// source whether or not anything is expanded.
///
/// ```dart
/// SeoFaq(
///   title: 'Häufige Fragen',
///   entries: [
///     SeoFaqEntry('Braucht es Puppeteer?', 'Nein — reines Dart.'),
///     SeoFaqEntry('Läuft es auf Mobile?', 'Ja, dort sind alle Aufrufe No-ops.'),
///   ],
/// )
/// ```
///
/// For the FAQ rich result, pair it with the matching structured data:
///
/// ```dart
/// SeoMeta(schemas: [SeoFaq.schemaFor(entries)])
/// ```
class SeoFaq extends StatefulWidget {
  const SeoFaq({
    super.key,
    required this.entries,
    this.title,
    this.titleLevel = 2,
    this.initiallyExpanded = false,
    this.questionStyle,
    this.answerStyle,
  });

  /// The question/answer pairs, in display order.
  final List<SeoFaqEntry> entries;

  /// Optional heading above the list.
  final String? title;

  /// Heading level of [title] (`1`–`6`, clamped) — pick the level that
  /// fits the page outline.
  final int titleLevel;

  /// Whether every entry starts expanded on screen. Irrelevant for the
  /// mirror: the answers are always in the HTML.
  final bool initiallyExpanded;

  /// Style of the question rows.
  final TextStyle? questionStyle;

  /// Style of the answer text.
  final TextStyle? answerStyle;

  /// The `FAQPage` structured data for [entries] — the on-page content
  /// and the rich-result markup from one source.
  static SeoSchema schemaFor(List<SeoFaqEntry> entries) => SeoSchema.faq([
        for (final entry in entries)
          (question: entry.question, answer: entry.answer),
      ]);

  @override
  State<SeoFaq> createState() => _SeoFaqState();
}

class _SeoFaqState extends State<SeoFaq> with SeoBlockState<SeoFaq> {
  late final Set<int> _expanded = {
    if (widget.initiallyExpanded)
      for (var i = 0; i < widget.entries.length; i++) i,
  };

  /// An empty or blank title must not produce an empty heading element —
  /// that is exactly what SEO and accessibility linters flag.
  bool get _hasTitle => widget.title != null && widget.title!.trim().isNotEmpty;

  @override
  Widget buildFlutter(BuildContext context) =>
      widget.entries.isEmpty ? const SizedBox.shrink() : _buildList();

  Widget _buildList() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_hasTitle)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              widget.title!,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
          ),
        for (var i = 0; i < widget.entries.length; i++)
          _buildEntry(i, widget.entries[i]),
      ],
    );
  }

  Widget _buildEntry(int index, SeoFaqEntry entry) {
    final open = _expanded.contains(index);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() {
              open ? _expanded.remove(index) : _expanded.add(index);
            }),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(open ? '▾' : '▸'),
                ),
                Expanded(
                  child: Text(
                    entry.question,
                    style: widget.questionStyle ??
                        const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          if (open)
            Padding(
              padding: const EdgeInsets.only(left: 20, top: 4),
              child: Text(entry.answer, style: widget.answerStyle),
            ),
        ],
      ),
    );
  }

  /// The HTML translation: `<details>` keeps the answers in the source
  /// and stays expandable without any JavaScript — which also makes it
  /// work in the prerendered shell before Flutter boots.
  @override
  List<SeoNode> toSeoNodes() => buildSeoFaqNodes(
        entries: [
          for (final entry in widget.entries)
            (question: entry.question, answer: entry.answer),
        ],
        title: widget.title,
        titleLevel: widget.titleLevel,
      );
}
