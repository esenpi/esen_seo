/// Pure configurator state and view projection shared by platform adapters.
library;

import 'seo_application_evaluation.dart';

/// Application-authored, state-free configurator transition.
typedef SeoConfiguratorTransition = SeoConfiguratorState Function(
  SeoConfiguratorState state,
  SeoConfiguratorAction action,
  SeoConfiguratorConstraints constraints,
);

/// Application-authored, state-free projection into fixed package view slots.
typedef SeoConfiguratorViewProjection = SeoConfiguratorView Function(
  SeoConfiguratorState state,
);

/// Largest selection group admitted by the first configurator slice.
const int seoConfiguratorMaxChoices = 32;

/// Largest quantity admitted by the package-owned bounded stepper.
const int seoConfiguratorMaxQuantity = 1000000;

/// Maximum UTF-16 length of the visible price slot.
const int seoConfiguratorMaxPriceTextLength = 128;

/// Maximum UTF-16 length of the visible summary slot.
const int seoConfiguratorMaxSummaryTextLength = 512;

/// Maximum UTF-16 length of the package-owned polite announcement.
const int seoConfiguratorMaxAnnouncementTextLength = 512;

/// Maximum raw UTF-16 length across every application-authored text value.
const int seoConfiguratorMaxAggregateTextLength = 1024;

/// Fixed bounds that package-owned configurator controls enforce.
final class SeoConfiguratorConstraints {
  const SeoConfiguratorConstraints({
    required this.choiceCount,
    required this.minQuantity,
    required this.maxQuantity,
  });

  final int choiceCount;
  final int minQuantity;
  final int maxQuantity;

  @override
  bool operator ==(Object other) =>
      other is SeoConfiguratorConstraints &&
      other.choiceCount == choiceCount &&
      other.minQuantity == minQuantity &&
      other.maxQuantity == maxQuantity;

  @override
  int get hashCode => Object.hash(choiceCount, minQuantity, maxQuantity);
}

/// Complete presentation state owned independently by Flutter and the DOM.
final class SeoConfiguratorState {
  const SeoConfiguratorState({
    required this.choiceIndex,
    required this.quantity,
    required this.optionEnabled,
  });

  final int choiceIndex;
  final int quantity;
  final bool optionEnabled;

  @override
  bool operator ==(Object other) =>
      other is SeoConfiguratorState &&
      other.choiceIndex == choiceIndex &&
      other.quantity == quantity &&
      other.optionEnabled == optionEnabled;

  @override
  int get hashCode => Object.hash(choiceIndex, quantity, optionEnabled);
}

/// Closed user-intent vocabulary understood by package-owned controls.
sealed class SeoConfiguratorAction {
  const SeoConfiguratorAction();
}

/// Selects one entry in the package-owned single-choice group.
final class SeoConfiguratorSelectChoice extends SeoConfiguratorAction {
  const SeoConfiguratorSelectChoice(this.index);

  final int index;
}

/// Increments quantity without moving past the configured maximum.
final class SeoConfiguratorIncrementQuantity extends SeoConfiguratorAction {
  const SeoConfiguratorIncrementQuantity();
}

/// Decrements quantity without moving before the configured minimum.
final class SeoConfiguratorDecrementQuantity extends SeoConfiguratorAction {
  const SeoConfiguratorDecrementQuantity();
}

/// Sets the one package-owned boolean option.
final class SeoConfiguratorSetOption extends SeoConfiguratorAction {
  const SeoConfiguratorSetOption(this.enabled);

  final bool enabled;
}

/// Fixed view values that application code may project from valid state.
///
/// No field can name a DOM target, element, attribute, class, URL or focus
/// destination. Platform adapters own those bindings and accept only these
/// text and visibility values after [evaluateSeoConfiguratorAction] validates
/// the complete candidate.
final class SeoConfiguratorView {
  const SeoConfiguratorView({
    required this.priceText,
    required this.summaryText,
    required this.announcementText,
    required this.activeChoiceRegion,
    required this.optionRegionVisible,
  });

  final String priceText;
  final String summaryText;
  final String announcementText;
  final int activeChoiceRegion;
  final bool optionRegionVisible;

  @override
  bool operator ==(Object other) =>
      other is SeoConfiguratorView &&
      other.priceText == priceText &&
      other.summaryText == summaryText &&
      other.announcementText == announcementText &&
      other.activeChoiceRegion == activeChoiceRegion &&
      other.optionRegionVisible == optionRegionVisible;

  @override
  int get hashCode => Object.hash(
        priceText,
        summaryText,
        announcementText,
        activeChoiceRegion,
        optionRegionVisible,
      );
}

/// Atomically validated state and view returned to a platform adapter.
final class SeoConfiguratorEvaluation {
  const SeoConfiguratorEvaluation({
    required this.state,
    required this.view,
    required this.accepted,
  });

  final SeoConfiguratorState state;
  final SeoConfiguratorView view;

  /// Whether one admitted action changed state and passed full view validation.
  final bool accepted;

  @override
  bool operator ==(Object other) =>
      other is SeoConfiguratorEvaluation &&
      other.state == state &&
      other.view == view &&
      other.accepted == accepted;

  @override
  int get hashCode => Object.hash(state, view, accepted);
}

/// Whether [constraints] can be represented identically on every platform.
bool isValidSeoConfiguratorConstraints(
  SeoConfiguratorConstraints constraints,
) =>
    constraints.choiceCount >= 1 &&
    constraints.choiceCount <= seoConfiguratorMaxChoices &&
    constraints.minQuantity >= 0 &&
    constraints.minQuantity <= constraints.maxQuantity &&
    constraints.maxQuantity <= seoConfiguratorMaxQuantity;

/// Whether [state] fits the fixed controls described by [constraints].
bool isValidSeoConfiguratorState(
  SeoConfiguratorState state,
  SeoConfiguratorConstraints constraints,
) =>
    isValidSeoConfiguratorConstraints(constraints) &&
    state.choiceIndex >= 0 &&
    state.choiceIndex < constraints.choiceCount &&
    state.quantity >= constraints.minQuantity &&
    state.quantity <= constraints.maxQuantity;

/// Returns a canonical initial state, or `null` for impossible constraints.
SeoConfiguratorState? initialSeoConfiguratorState({
  required SeoConfiguratorConstraints constraints,
  int choiceIndex = 0,
  int? quantity,
  bool optionEnabled = false,
}) {
  if (!isValidSeoConfiguratorConstraints(constraints)) return null;
  return SeoConfiguratorState(
    choiceIndex: choiceIndex.clamp(0, constraints.choiceCount - 1),
    quantity: (quantity ?? constraints.minQuantity).clamp(
      constraints.minQuantity,
      constraints.maxQuantity,
    ),
    optionEnabled: optionEnabled,
  );
}

/// Default closed transition for the package-owned configurator controls.
SeoConfiguratorState transitionSeoConfigurator(
  SeoConfiguratorState state,
  SeoConfiguratorAction action,
  SeoConfiguratorConstraints constraints,
) {
  if (!isValidSeoConfiguratorState(state, constraints)) return state;
  return switch (action) {
    SeoConfiguratorSelectChoice(:final index)
        when index >= 0 && index < constraints.choiceCount =>
      SeoConfiguratorState(
        choiceIndex: index,
        quantity: state.quantity,
        optionEnabled: state.optionEnabled,
      ),
    SeoConfiguratorSelectChoice() => state,
    SeoConfiguratorIncrementQuantity()
        when state.quantity < constraints.maxQuantity =>
      SeoConfiguratorState(
        choiceIndex: state.choiceIndex,
        quantity: state.quantity + 1,
        optionEnabled: state.optionEnabled,
      ),
    SeoConfiguratorIncrementQuantity() => state,
    SeoConfiguratorDecrementQuantity()
        when state.quantity > constraints.minQuantity =>
      SeoConfiguratorState(
        choiceIndex: state.choiceIndex,
        quantity: state.quantity - 1,
        optionEnabled: state.optionEnabled,
      ),
    SeoConfiguratorDecrementQuantity() => state,
    SeoConfiguratorSetOption(:final enabled) => SeoConfiguratorState(
        choiceIndex: state.choiceIndex,
        quantity: state.quantity,
        optionEnabled: enabled,
      ),
  };
}

/// Validates an initial state and view before any platform enhancement.
///
/// `null` means the static component must remain untouched. Returned text is
/// canonicalized with [sanitizeSeoConfiguratorText] before a builder compares
/// or an adapter writes it.
SeoConfiguratorEvaluation? evaluateInitialSeoConfiguratorView(
  SeoConfiguratorViewProjection project,
  SeoConfiguratorState state,
  SeoConfiguratorConstraints constraints,
) {
  final result = evaluateInitialSeoApplication(
    state: state,
    canonicalizeState: (candidate) =>
        isValidSeoConfiguratorState(candidate, constraints) ? candidate : null,
    project: project,
    validateView: (view, candidate) =>
        _validateSeoConfiguratorView(view, candidate, constraints),
  );
  if (result == null) return null;
  return SeoConfiguratorEvaluation(
    state: result.state,
    view: result.view,
    accepted: result.accepted,
  );
}

/// Applies one action and validates state and projected view atomically.
///
/// Invalid constraints or a stale current evaluation return `null`, which
/// refuses further enhancement. An inadmissible action, a no-op, a thrown
/// transition, or invalid candidate output returns the canonical current
/// evaluation with [SeoConfiguratorEvaluation.accepted] set to `false`. A
/// platform adapter may mutate only when the returned evaluation is accepted.
SeoConfiguratorEvaluation? evaluateSeoConfiguratorAction({
  required SeoConfiguratorTransition transition,
  required SeoConfiguratorViewProjection project,
  required SeoConfiguratorEvaluation current,
  required SeoConfiguratorAction action,
  required SeoConfiguratorConstraints constraints,
}) {
  final result = evaluateSeoApplicationAction(
    currentState: current.state,
    currentView: current.view,
    action: action,
    canonicalizeState: (candidate) =>
        isValidSeoConfiguratorState(candidate, constraints) ? candidate : null,
    validateView: (view, candidate) =>
        _validateSeoConfiguratorView(view, candidate, constraints),
    isActionAdmitted: (candidate, candidateAction) =>
        _isAdmittedSeoConfiguratorAction(
      candidate,
      candidateAction,
      constraints,
    ),
    transition: (candidate, candidateAction) =>
        transition(candidate, candidateAction, constraints),
    validateCandidate: (previous, _, candidate) =>
        isValidSeoConfiguratorState(candidate, constraints) &&
                candidate != previous
            ? candidate
            : null,
    project: project,
  );
  if (result == null) return null;
  return SeoConfiguratorEvaluation(
    state: result.state,
    view: result.view,
    accepted: result.accepted,
  );
}

/// Removes directional controls that can visually reorder bounded slot text.
String sanitizeSeoConfiguratorText(String input) {
  final output = StringBuffer();
  for (final rune in input.runes) {
    if (_isSeoConfiguratorBidiControl(rune)) continue;
    output.writeCharCode(rune);
  }
  return output.toString();
}

/// Validates one bounded configurator text value and removes bidi controls.
///
/// Length is checked before normalization so removed control characters cannot
/// be used to bypass a caller's budget. Empty or malformed UTF-16 values are
/// rejected.
String? canonicalizeSeoConfiguratorText(
  String input, {
  required int maxLength,
}) {
  if (maxLength < 1 ||
      input.length > maxLength ||
      _hasUnpairedSeoConfiguratorSurrogate(input)) {
    return null;
  }
  final value = sanitizeSeoConfiguratorText(input);
  return value.trim().isEmpty ? null : value;
}

SeoConfiguratorView? _validateSeoConfiguratorView(
  SeoConfiguratorView raw,
  SeoConfiguratorState state,
  SeoConfiguratorConstraints constraints,
) {
  if (raw.activeChoiceRegion != state.choiceIndex ||
      raw.activeChoiceRegion < 0 ||
      raw.activeChoiceRegion >= constraints.choiceCount ||
      raw.optionRegionVisible != state.optionEnabled) {
    return null;
  }

  final priceLength = raw.priceText.length;
  final summaryLength = raw.summaryText.length;
  final announcementLength = raw.announcementText.length;
  if (priceLength + summaryLength + announcementLength >
      seoConfiguratorMaxAggregateTextLength) {
    return null;
  }

  final price = canonicalizeSeoConfiguratorText(
    raw.priceText,
    maxLength: seoConfiguratorMaxPriceTextLength,
  );
  final summary = canonicalizeSeoConfiguratorText(
    raw.summaryText,
    maxLength: seoConfiguratorMaxSummaryTextLength,
  );
  final announcement = canonicalizeSeoConfiguratorText(
    raw.announcementText,
    maxLength: seoConfiguratorMaxAnnouncementTextLength,
  );
  if (price == null || summary == null || announcement == null) {
    return null;
  }
  return SeoConfiguratorView(
    priceText: price,
    summaryText: summary,
    announcementText: announcement,
    activeChoiceRegion: raw.activeChoiceRegion,
    optionRegionVisible: raw.optionRegionVisible,
  );
}

bool _isAdmittedSeoConfiguratorAction(
  SeoConfiguratorState state,
  SeoConfiguratorAction action,
  SeoConfiguratorConstraints constraints,
) =>
    switch (action) {
      SeoConfiguratorSelectChoice(:final index) => index >= 0 &&
          index < constraints.choiceCount &&
          index != state.choiceIndex,
      SeoConfiguratorIncrementQuantity() =>
        state.quantity < constraints.maxQuantity,
      SeoConfiguratorDecrementQuantity() =>
        state.quantity > constraints.minQuantity,
      SeoConfiguratorSetOption(:final enabled) =>
        enabled != state.optionEnabled,
    };

bool _isSeoConfiguratorBidiControl(int rune) =>
    rune == 0x061C ||
    rune == 0x200E ||
    rune == 0x200F ||
    (rune >= 0x202A && rune <= 0x202E) ||
    (rune >= 0x2066 && rune <= 0x2069);

bool _hasUnpairedSeoConfiguratorSurrogate(String value) {
  for (var index = 0; index < value.length; index++) {
    final unit = value.codeUnitAt(index);
    if (unit >= 0xD800 && unit <= 0xDBFF) {
      if (index + 1 >= value.length) return true;
      final next = value.codeUnitAt(index + 1);
      if (next < 0xDC00 || next > 0xDFFF) return true;
      index++;
    } else if (unit >= 0xDC00 && unit <= 0xDFFF) {
      return true;
    }
  }
  return false;
}
