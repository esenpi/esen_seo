/// Pure state and transition logic for the package-owned theme toggle.
library;

/// The persisted presentation preference.
enum SeoThemePreference { system, light, dark }

/// The storage key shared by the early bootstrap and browser adapter.
const String seoThemePreferenceStorageKey = 'esen.theme';

/// Current theme state, including the platform preference used by system mode.
final class SeoThemeState {
  const SeoThemeState({
    this.preference = SeoThemePreference.system,
    required this.systemIsDark,
  });

  final SeoThemePreference preference;
  final bool systemIsDark;

  bool get isDark => switch (preference) {
        SeoThemePreference.system => systemIsDark,
        SeoThemePreference.light => false,
        SeoThemePreference.dark => true,
      };

  @override
  bool operator ==(Object other) =>
      other is SeoThemeState &&
      other.preference == preference &&
      other.systemIsDark == systemIsDark;

  @override
  int get hashCode => Object.hash(preference, systemIsDark);
}

/// A closed action understood by both Flutter and DOM-first presentations.
sealed class SeoThemeAction {
  const SeoThemeAction();
}

/// Toggle away from the currently resolved brightness.
final class SeoThemeToggleAction extends SeoThemeAction {
  const SeoThemeToggleAction();
}

/// Restore a persisted preference, or system mode when no preference exists.
final class SeoThemeRestoreAction extends SeoThemeAction {
  const SeoThemeRestoreAction(this.preference);

  final SeoThemePreference preference;
}

/// Update the platform brightness used while the preference is system.
final class SeoThemeSystemBrightnessAction extends SeoThemeAction {
  const SeoThemeSystemBrightnessAction(this.isDark);

  final bool isDark;
}

/// The only external effect emitted by [transitionSeoTheme].
final class SeoThemePersistEffect {
  const SeoThemePersistEffect(this.preference);

  final SeoThemePreference preference;
}

/// Next state plus an optional declarative persistence request.
final class SeoThemeTransitionResult {
  const SeoThemeTransitionResult(this.state, {this.persist});

  final SeoThemeState state;
  final SeoThemePersistEffect? persist;
}

/// Applies one closed theme action without retaining state or doing I/O.
SeoThemeTransitionResult transitionSeoTheme(
  SeoThemeState state,
  SeoThemeAction action,
) {
  return switch (action) {
    SeoThemeToggleAction() => _toggle(state),
    SeoThemeRestoreAction(:final preference) => SeoThemeTransitionResult(
        SeoThemeState(
          preference: preference,
          systemIsDark: state.systemIsDark,
        ),
      ),
    SeoThemeSystemBrightnessAction(:final isDark) => SeoThemeTransitionResult(
        SeoThemeState(
          preference: state.preference,
          systemIsDark: isDark,
        ),
      ),
  };
}

SeoThemeTransitionResult _toggle(SeoThemeState state) {
  final preference =
      state.isDark ? SeoThemePreference.light : SeoThemePreference.dark;
  return SeoThemeTransitionResult(
    SeoThemeState(
      preference: preference,
      systemIsDark: state.systemIsDark,
    ),
    persist: SeoThemePersistEffect(preference),
  );
}

/// Parses the closed storage representation. Invalid values use system mode.
SeoThemePreference parseSeoThemePreference(String? value) => switch (value) {
      'light' => SeoThemePreference.light,
      'dark' => SeoThemePreference.dark,
      _ => SeoThemePreference.system,
    };

/// Serializes a preference for storage; system mode removes the stored value.
String? serializeSeoThemePreference(SeoThemePreference preference) =>
    switch (preference) {
      SeoThemePreference.system => null,
      SeoThemePreference.light => 'light',
      SeoThemePreference.dark => 'dark',
    };
