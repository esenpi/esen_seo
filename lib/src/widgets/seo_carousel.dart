import 'package:flutter/widgets.dart';

import '../components/seo_components.dart';
import '../renderer/seo_node.dart';
import 'seo_block.dart';

/// One slide of a [SeoCarousel].
class SeoCarouselSlide {
  const SeoCarouselSlide({
    required this.label,
    required this.content,
    required this.nodes,
  });

  /// Visible heading of the slide and its semantic HTML section.
  final String label;

  /// The slide shown by Flutter when its page is built.
  final Widget content;

  /// The slide's HTML translation, emitted for every slide.
  final List<SeoNode> nodes;
}

/// A carousel whose complete slide set reaches semantic HTML.
///
/// Flutter uses a lazy [PageView.builder], while the mirror contains every
/// slide as a section with a heading. This closes the virtualization gap
/// without changing how iOS, Android or the running Flutter app render.
///
/// Supplying a valid [interactionId] opts a visible semantic page into
/// package-owned progressive controls. Without JavaScript all slide sections
/// remain visible and readable. The component never autoplays.
class SeoCarousel extends StatefulWidget {
  const SeoCarousel({
    super.key,
    required this.slides,
    this.height = 320,
    this.initialIndex = 0,
    this.headingLevel = 3,
    this.interactionId,
    this.interactionLabel = 'Carousel',
    this.previousLabel = 'Previous slide',
    this.nextLabel = 'Next slide',
    this.slideLabelStyle,
    this.positionStyle,
    this.onPageChanged,
  });

  /// Slides in display order.
  final List<SeoCarouselSlide> slides;

  /// Height of the Flutter page viewport. Invalid values fall back to 320.
  final double height;

  /// Initially visible slide, clamped into range.
  final int initialIndex;

  /// Heading level of every semantic slide section (`1`-`6`).
  final int headingLevel;

  /// Stable DOM id that opts semantic HTML into JavaScript enhancement.
  ///
  /// It must start with an ASCII letter and then contain only letters,
  /// digits, `_` or `-`, up to 128 characters. Invalid values leave every
  /// slide static and visible.
  final String? interactionId;

  /// Accessible label of the enhanced carousel region.
  final String interactionLabel;

  /// Accessible label of the previous-slide control.
  final String previousLabel;

  /// Accessible label of the next-slide control.
  final String nextLabel;

  /// Style of the visible Flutter slide heading.
  final TextStyle? slideLabelStyle;

  /// Style of the Flutter position indicator.
  final TextStyle? positionStyle;

  /// Called when Flutter changes the visible page.
  final ValueChanged<int>? onPageChanged;

  @override
  State<SeoCarousel> createState() => _SeoCarouselState();
}

class _SeoCarouselState extends State<SeoCarousel>
    with SeoBlockState<SeoCarousel> {
  late int _index;
  late final PageController _controller;

  @override
  void initState() {
    super.initState();
    _index = _initialIndex();
    _controller = PageController(initialPage: _index);
  }

  int _initialIndex() => widget.slides.isEmpty
      ? 0
      : widget.initialIndex.clamp(0, widget.slides.length - 1);

  @override
  void didUpdateWidget(SeoCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    var replaced = widget.slides.length != oldWidget.slides.length;
    for (var i = 0; !replaced && i < widget.slides.length; i++) {
      replaced = widget.slides[i].label != oldWidget.slides[i].label;
    }
    if (widget.slides.isEmpty) {
      _index = 0;
      return;
    }
    if (replaced ||
        widget.initialIndex != oldWidget.initialIndex ||
        _index >= widget.slides.length) {
      _index = _initialIndex();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller.hasClients && widget.slides.isNotEmpty) {
          _controller.jumpToPage(_index);
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget buildFlutter(BuildContext context) {
    if (widget.slides.isEmpty) return const SizedBox.shrink();
    final height =
        widget.height.isFinite && widget.height > 0 ? widget.height : 320.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: height,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.slides.length,
            onPageChanged: (index) {
              if (index == _index) return;
              setState(() => _index = index);
              widget.onPageChanged?.call(index);
            },
            itemBuilder: (context, index) => _buildSlide(widget.slides[index]),
          ),
        ),
        if (widget.slides.length > 1) ...[
          const SizedBox(height: 8),
          _buildControls(context),
        ],
      ],
    );
  }

  Widget _buildSlide(SeoCarouselSlide slide) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              slide.label,
              style: widget.slideLabelStyle ??
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Expanded(child: slide.content),
          ],
        ),
      );

  Widget _buildControls(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildControl(
          label: widget.previousLabel,
          symbol: isRtl ? '\u203a' : '\u2039',
          enabled: _index > 0,
          onTap: () => _goTo(_index - 1),
        ),
        SizedBox(
          width: 64,
          child: Text(
            '${_index + 1} / ${widget.slides.length}',
            textAlign: TextAlign.center,
            style: widget.positionStyle,
          ),
        ),
        _buildControl(
          label: widget.nextLabel,
          symbol: isRtl ? '\u2039' : '\u203a',
          enabled: _index < widget.slides.length - 1,
          onTap: () => _goTo(_index + 1),
        ),
      ],
    );
  }

  Widget _buildControl({
    required String label,
    required String symbol,
    required bool enabled,
    required VoidCallback onTap,
  }) =>
      Semantics(
        button: true,
        enabled: enabled,
        label: label,
        child: Opacity(
          opacity: enabled ? 1 : 0.4,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: enabled ? onTap : null,
            child: SizedBox(
              width: 40,
              height: 40,
              child: Center(
                child: ExcludeSemantics(
                  child: Text(symbol, style: const TextStyle(fontSize: 28)),
                ),
              ),
            ),
          ),
        ),
      );

  void _goTo(int index) {
    if (index < 0 || index >= widget.slides.length || !_controller.hasClients) {
      return;
    }
    _controller.animateToPage(
      index,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  List<SeoNode> toSeoNodes() => buildSeoCarouselNodes(
        slides: [
          for (final slide in widget.slides)
            (label: slide.label, nodes: slide.nodes),
        ],
        headingLevel: widget.headingLevel,
        interactionId: widget.interactionId,
        interactionLabel: widget.interactionLabel,
        previousLabel: widget.previousLabel,
        nextLabel: widget.nextLabel,
        initialIndex: widget.initialIndex,
      );
}
