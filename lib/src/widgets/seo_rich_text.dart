import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../components/seo_rich_text.dart';
import '../renderer/seo_node.dart';
import '../tags/seo_tags.dart';
import 'seo_block.dart';

/// Rich text whose inline meaning reaches both Flutter and semantic HTML.
///
/// Flutter's ordinary `Text.rich` can be mirrored only as `toPlainText()`:
/// paint styles do not reliably identify strong emphasis, prose emphasis,
/// code, or a link target. [SeoRichText] uses one declarative span tree for
/// native Flutter `TextSpan`s and nested `<strong>`, `<em>`, `<code>` and
/// `<a>` elements instead.
///
/// ```dart
/// SeoRichText(
///   spans: [
///     SeoRichTextSpan.text('Read the '),
///     SeoRichTextSpan.link(href: '/docs', text: 'documentation'),
///     SeoRichTextSpan.text(' for '),
///     SeoRichTextSpan.strong(text: 'important details'),
///     SeoRichTextSpan.text('.'),
///   ],
///   onLinkTap: openRoute,
/// )
/// ```
///
/// Arbitrary `WidgetSpan`s are deliberately outside this model: embedded
/// widgets need an explicit semantic representation rather than an invisible
/// object-replacement character or a guessed fallback.
class SeoRichText extends StatefulWidget {
  const SeoRichText({
    super.key,
    required this.spans,
    this.tag = SeoTextTag.p,
    this.attributes = const {},
    this.onLinkTap,
    this.style,
    this.strongStyle,
    this.emphasisStyle,
    this.codeStyle,
    this.linkStyle,
    this.textAlign,
    this.textDirection,
    this.softWrap,
    this.overflow,
    this.maxLines,
  });

  /// Inline content in display order.
  final List<SeoRichTextSpan> spans;

  /// HTML element wrapping the inline content. Defaults to `<p>`.
  final SeoTextTag tag;

  /// Attributes of the wrapping HTML element.
  final Map<String, String> attributes;

  /// Handles a safe, trimmed link target in the native Flutter presentation.
  ///
  /// Without a callback the HTML link remains real, while Flutter displays it
  /// without installing a gesture recognizer. Unsafe targets are never passed
  /// to this callback.
  final ValueChanged<String>? onLinkTap;

  /// Base style of the Flutter text.
  final TextStyle? style;

  /// Flutter style for [SeoRichTextRole.strong].
  final TextStyle? strongStyle;

  /// Flutter style for [SeoRichTextRole.emphasis].
  final TextStyle? emphasisStyle;

  /// Flutter style for [SeoRichTextRole.code].
  final TextStyle? codeStyle;

  /// Flutter style for safe, non-nested [SeoRichTextRole.link] spans.
  final TextStyle? linkStyle;

  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final bool? softWrap;
  final TextOverflow? overflow;
  final int? maxLines;

  @override
  State<SeoRichText> createState() => _SeoRichTextState();
}

class _SeoRichTextState extends State<SeoRichText>
    with SeoBlockState<SeoRichText> {
  final List<TapGestureRecognizer> _recognizers = [];
  late TextSpan _flutterSpan;

  @override
  void initState() {
    super.initState();
    _rebuildFlutterSpan();
  }

  @override
  void didUpdateWidget(SeoRichText oldWidget) {
    super.didUpdateWidget(oldWidget);
    _rebuildFlutterSpan();
  }

  @override
  void dispose() {
    _disposeRecognizers(_recognizers);
    super.dispose();
  }

  void _rebuildFlutterSpan() {
    final nextRecognizers = <TapGestureRecognizer>[];
    try {
      final nextSpan = TextSpan(
        children: [
          for (final span in widget.spans)
            _buildFlutterSpan(
              span,
              depth: 0,
              inLink: false,
              recognizers: nextRecognizers,
            ),
        ],
      );
      _disposeRecognizers(_recognizers);
      _recognizers.addAll(nextRecognizers);
      _flutterSpan = nextSpan;
    } catch (_) {
      _disposeRecognizers(nextRecognizers);
      rethrow;
    }
  }

  TextSpan _buildFlutterSpan(
    SeoRichTextSpan span, {
    required int depth,
    required bool inLink,
    required List<TapGestureRecognizer> recognizers,
    TapGestureRecognizer? activeRecognizer,
  }) {
    if (depth > seoRichTextMaxDepth) {
      throw StateError(
        'SeoRichText nests deeper than $seoRichTextMaxDepth levels - is its '
        'span tree cyclic?',
      );
    }
    if (span.role == SeoRichTextRole.lineBreak) {
      return TextSpan(text: '\n', recognizer: activeRecognizer);
    }

    final href = span.effectiveHref;
    final isLink = span.role == SeoRichTextRole.link && !inLink && href != null;
    var recognizer = activeRecognizer;
    if (isLink && widget.onLinkTap != null) {
      recognizer = TapGestureRecognizer()
        ..onTap = () => widget.onLinkTap?.call(href);
      recognizers.add(recognizer);
    }

    return TextSpan(
      text: span.text,
      style: _styleFor(span.role, isLink: isLink),
      recognizer: span.text == null ? null : recognizer,
      children: [
        for (final child in span.children)
          _buildFlutterSpan(
            child,
            depth: depth + 1,
            inLink: inLink || isLink,
            recognizers: recognizers,
            activeRecognizer: recognizer,
          ),
      ],
    );
  }

  TextStyle? _styleFor(SeoRichTextRole role, {required bool isLink}) {
    switch (role) {
      case SeoRichTextRole.text:
      case SeoRichTextRole.lineBreak:
        return null;
      case SeoRichTextRole.strong:
        return widget.strongStyle ??
            const TextStyle(fontWeight: FontWeight.bold);
      case SeoRichTextRole.emphasis:
        return widget.emphasisStyle ??
            const TextStyle(fontStyle: FontStyle.italic);
      case SeoRichTextRole.code:
        return widget.codeStyle ?? const TextStyle(fontFamily: 'monospace');
      case SeoRichTextRole.link:
        if (!isLink) return null;
        return widget.linkStyle ??
            const TextStyle(decoration: TextDecoration.underline);
    }
  }

  void _disposeRecognizers(List<TapGestureRecognizer> recognizers) {
    for (final recognizer in recognizers) {
      recognizer.dispose();
    }
    recognizers.clear();
  }

  @override
  Widget buildFlutter(BuildContext context) {
    if (widget.spans.isEmpty) return const SizedBox.shrink();
    return Text.rich(
      _flutterSpan,
      style: widget.style,
      textAlign: widget.textAlign,
      textDirection: widget.textDirection,
      softWrap: widget.softWrap,
      overflow: widget.overflow,
      maxLines: widget.maxLines,
    );
  }

  @override
  List<SeoNode> toSeoNodes() => buildSeoRichTextNodes(
        spans: widget.spans,
        tag: widget.tag.name,
        attributes: widget.attributes,
      );
}
