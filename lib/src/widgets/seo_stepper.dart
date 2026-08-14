import 'package:flutter/widgets.dart';

import '../components/seo_components.dart';
import '../components/seo_stepper_transition.dart';
import '../renderer/seo_node.dart';
import 'seo_block.dart';

/// One step of a [SeoStepper].
class SeoStep {
  const SeoStep({
    required this.label,
    required this.content,
    required this.nodes,
  });

  /// Visible step label and semantic HTML heading.
  final String label;

  /// Native Flutter content built when the step is first visited.
  final Widget content;

  /// Complete semantic HTML content emitted immediately for this step.
  final List<SeoNode> nodes;
}

/// A stateful flow whose complete step set reaches semantic HTML.
///
/// Flutter initially builds only the active step body. Visited bodies remain
/// mounted so their native state survives back/next navigation, while
/// unvisited bodies stay lazy. The mirror always contains every step as an
/// ordered list with a heading and body.
///
/// A valid [interactionId] opts a visible semantic page into package-owned
/// progressive controls. It does not translate form state, validation,
/// completion rules or arbitrary Dart callbacks into JavaScript.
class SeoStepper extends StatefulWidget {
  const SeoStepper({
    super.key,
    required this.steps,
    this.initialIndex = 0,
    this.headingLevel = 3,
    this.interactionId,
    this.interactionLabel = 'Steps',
    this.previousLabel = 'Back',
    this.nextLabel = 'Next',
    this.positionLabel = 'Step',
    this.transition = transitionSeoStepper,
    this.stepLabelStyle,
    this.activeStepLabelStyle,
    this.onStepChanged,
  });

  /// Steps in flow order.
  final List<SeoStep> steps;

  /// Initially active step, clamped into range.
  final int initialIndex;

  /// Heading level of every semantic step (`1`-`6`).
  final int headingLevel;

  /// Stable DOM id that opts semantic HTML into JavaScript enhancement.
  final String? interactionId;

  /// Accessible label of the enhanced stepper region.
  final String interactionLabel;

  /// Label of the previous-step control in Flutter and visible HTML.
  final String previousLabel;

  /// Label of the next-step control in Flutter and visible HTML.
  final String nextLabel;

  /// Prefix of the live HTML position, for example `Step 2 / 4`.
  final String positionLabel;

  /// Pure selection logic shared with an optional application web runtime.
  final SeoStepperTransition transition;

  /// Flutter style of inactive step labels.
  final TextStyle? stepLabelStyle;

  /// Flutter style of the active step label.
  final TextStyle? activeStepLabelStyle;

  /// Called when the native Flutter presentation changes step.
  final ValueChanged<int>? onStepChanged;

  @override
  State<SeoStepper> createState() => _SeoStepperState();
}

class _SeoStepperState extends State<SeoStepper>
    with SeoBlockState<SeoStepper> {
  late SeoStepperState _stepperState;
  late Set<int> _visited;

  @override
  void initState() {
    super.initState();
    _stepperState = _initialState();
    _visited = {if (widget.steps.isNotEmpty) _index};
  }

  int get _index => _stepperState.index;

  SeoStepperState _initialState() => initialSeoStepperState(
        count: widget.steps.length,
        index: widget.initialIndex,
      );

  @override
  void didUpdateWidget(SeoStepper oldWidget) {
    super.didUpdateWidget(oldWidget);
    var replaced = widget.steps.length != oldWidget.steps.length;
    for (var i = 0; !replaced && i < widget.steps.length; i++) {
      replaced = widget.steps[i].label != oldWidget.steps[i].label;
    }
    if (widget.steps.isEmpty) {
      _stepperState = _initialState();
      _visited.clear();
      return;
    }
    if (replaced ||
        widget.initialIndex != oldWidget.initialIndex ||
        _index >= widget.steps.length) {
      _stepperState = _initialState();
      _visited = {_index};
    } else {
      _stepperState = initialSeoStepperState(
        count: widget.steps.length,
        index: _index,
      );
      _visited.removeWhere((index) => index >= widget.steps.length);
      _visited.add(_index);
    }
  }

  @override
  Widget buildFlutter(BuildContext context) {
    if (widget.steps.isEmpty) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var index = 0; index < widget.steps.length; index++)
                _buildHeader(index, widget.steps[index]),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(32, 8, 0, 12),
          child: Stack(
            children: [
              for (final index in _visited)
                Offstage(
                  key: ValueKey(index),
                  offstage: index != _index,
                  child: TickerMode(
                    enabled: index == _index,
                    child: ExcludeFocus(
                      excluding: index != _index,
                      child: widget.steps[index].content,
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (widget.steps.length > 1) _buildControls(),
      ],
    );
  }

  Widget _buildHeader(int index, SeoStep step) {
    final active = index == _index;
    return SizedBox(
      width: 180,
      child: Semantics(
        button: true,
        selected: active,
        label: step.label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _activate(SeoStepperSelect(index)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 32,
                  child: ExcludeSemantics(
                    child: Text('${index + 1}.'),
                  ),
                ),
                Expanded(
                  child: ExcludeSemantics(
                    child: Text(
                      step.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: active
                          ? widget.activeStepLabelStyle ??
                              const TextStyle(fontWeight: FontWeight.w600)
                          : widget.stepLabelStyle,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControls() => Row(
        children: [
          Expanded(
            child: _buildControl(
              label: widget.previousLabel,
              enabled: _index > 0,
              onTap: () => _activate(const SeoStepperPrevious()),
            ),
          ),
          Expanded(
            child: Text(
              '${_index + 1} / ${widget.steps.length}',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: _buildControl(
              label: widget.nextLabel,
              enabled: _index < widget.steps.length - 1,
              onTap: () => _activate(const SeoStepperNext()),
            ),
          ),
        ],
      );

  Widget _buildControl({
    required String label,
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
              height: 40,
              child: Center(
                child: ExcludeSemantics(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  void _activate(SeoStepperAction action) {
    final next = applySeoStepperTransition(
      widget.transition,
      _stepperState,
      action,
    );
    if (next == _stepperState) return;
    setState(() {
      _stepperState = next;
      _visited.add(next.index);
    });
    widget.onStepChanged?.call(next.index);
  }

  @override
  List<SeoNode> toSeoNodes() => buildSeoStepperNodes(
        steps: [
          for (final step in widget.steps)
            (label: step.label, nodes: step.nodes),
        ],
        headingLevel: widget.headingLevel,
        interactionId: widget.interactionId,
        interactionLabel: widget.interactionLabel,
        previousLabel: widget.previousLabel,
        nextLabel: widget.nextLabel,
        positionLabel: widget.positionLabel,
        initialIndex: widget.initialIndex,
      );
}
