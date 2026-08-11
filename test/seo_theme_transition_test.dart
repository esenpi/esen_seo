import 'package:esen_seo/core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('system mode resolves against the current platform brightness', () {
    const light = SeoThemeState(systemIsDark: false);
    const dark = SeoThemeState(systemIsDark: true);

    expect(light.isDark, isFalse);
    expect(dark.isDark, isTrue);
    expect(
      transitionSeoTheme(
        light,
        const SeoThemeSystemBrightnessAction(true),
      ).state.isDark,
      isTrue,
    );
  });

  test('toggle leaves system mode and requests the resolved opposite', () {
    final fromLight = transitionSeoTheme(
      const SeoThemeState(systemIsDark: false),
      const SeoThemeToggleAction(),
    );
    final fromDark = transitionSeoTheme(
      const SeoThemeState(systemIsDark: true),
      const SeoThemeToggleAction(),
    );

    expect(fromLight.state.preference, SeoThemePreference.dark);
    expect(fromLight.state.isDark, isTrue);
    expect(fromLight.persist?.preference, SeoThemePreference.dark);
    expect(fromDark.state.preference, SeoThemePreference.light);
    expect(fromDark.state.isDark, isFalse);
    expect(fromDark.persist?.preference, SeoThemePreference.light);
  });

  test('explicit preference ignores later system changes', () {
    const state = SeoThemeState(
      preference: SeoThemePreference.dark,
      systemIsDark: false,
    );
    final result = transitionSeoTheme(
      state,
      const SeoThemeSystemBrightnessAction(false),
    );

    expect(result.state.preference, SeoThemePreference.dark);
    expect(result.state.isDark, isTrue);
    expect(result.persist, isNull);
  });

  test('storage codec is closed and malformed input returns to system', () {
    expect(parseSeoThemePreference('light'), SeoThemePreference.light);
    expect(parseSeoThemePreference('dark'), SeoThemePreference.dark);
    expect(parseSeoThemePreference('DARK'), SeoThemePreference.system);
    expect(parseSeoThemePreference(' dark '), SeoThemePreference.system);
    expect(parseSeoThemePreference(null), SeoThemePreference.system);
    expect(serializeSeoThemePreference(SeoThemePreference.system), isNull);
    expect(serializeSeoThemePreference(SeoThemePreference.light), 'light');
    expect(serializeSeoThemePreference(SeoThemePreference.dark), 'dark');
  });
}
