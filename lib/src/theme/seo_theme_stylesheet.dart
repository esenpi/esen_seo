/// The Flutter half of the theme bridge: reads a [ThemeData] and hands
/// validated tokens to the pure generator.
///
/// This file may import Flutter — it is reachable only from
/// `package:esen_seo/esen_seo.dart`, never from `core.dart` or
/// `server.dart` (the pure-Dart CI proof walks the import graph and
/// would fail the build otherwise). The prerenderer, which runs
/// without Flutter, only ever meets the resulting string: generate it
/// once with [checkOrUpdateSeoThemeCss] into a committed
/// `lib/seo_theme.g.dart` and pass the constant to
/// `prerenderSite(stylesheet:)`.
library;

import 'package:flutter/material.dart';

import '../renderer/seo_theme_css.dart';

/// Builds the shell stylesheet from the app's own theme.
///
/// The result **replaces** `seoDefaultStylesheet` — pass one or the
/// other to `prerenderSite(stylesheet:)`, never both concatenated:
/// they declare the same rules at the same specificity, and source
/// order would silently decide.
///
/// What the shell mirrors and what it does not: colors, typography
/// scale, weights and the font family come from the theme (with a
/// system-font fallback chain, because the browser has not loaded the
/// app's bundled font — see the README for the opt-in `@font-face`
/// recipe). Component-level styling — elevation, shapes, ink effects —
/// is not mirrored; the shell is a document, not a widget tree.
///
/// Deliberate deviations from a raw Material reading, all documented:
/// headings follow the Material scale (`h1` ← `headlineLarge`), which
/// keeps their weight at whatever the theme says — Material 3 headings
/// are regular weight, not bold. `h4`–`h6` get rules for the first
/// time. Paragraphs default to `bodyLarge` (16 px, the browser
/// baseline) rather than Flutter's 14 px `bodyMedium` default; pass
/// [bodyRole] for 1:1 parity.
///
/// [mode] states what `MaterialApp.themeMode` forces — it is not a
/// `ThemeData` field, so it cannot be read automatically. An app that
/// forces `ThemeMode.dark` should pass `SeoThemeMode.dark`, otherwise
/// visitors with a light OS preference get a light shell and a visible
/// palette flip when Flutter takes over.
///
/// [scriptCategory] feeds Material's typography geometry — pass
/// [ScriptCategory.dense] or [ScriptCategory.tall] for CJK/Thai apps,
/// or the shell's metrics will quietly be the English ones.
String seoStylesheetFromTheme(
  ThemeData theme, {
  ThemeData? darkTheme,
  SeoThemeMode mode = SeoThemeMode.system,
  SeoBodyRole bodyRole = SeoBodyRole.bodyLarge,
  ScriptCategory scriptCategory = ScriptCategory.englishLike,
}) =>
    seoThemeCss(
      light: _tokensFrom(theme, scriptCategory),
      dark: darkTheme == null ? null : _tokensFrom(darkTheme, scriptCategory),
      mode: mode,
      bodyRole: bodyRole,
    );

SeoThemeTokens _tokensFrom(ThemeData raw, ScriptCategory script) {
  // Raw ThemeData carries NO text geometry — fontSize is null until
  // the theme is localized against a typography geometry. Reading the
  // roles without this step emits a stylesheet with no sizes at all.
  final theme =
      ThemeData.localize(raw, raw.typography.geometryThemeFor(script));
  final scheme = theme.colorScheme;
  final text = theme.textTheme;
  final m3 = theme.useMaterial3;
  final properties = <String, String>{};

  void color(String name, Color value) =>
      properties['--esen-color-$name'] = _hex(value);

  // The full Material 3 role set, minus the roles Flutter has already
  // deprecated (background, onBackground, surfaceVariant) — freezing
  // those into a public token contract would bake the deprecation in.
  color('primary', scheme.primary);
  color('on-primary', scheme.onPrimary);
  color('primary-container', scheme.primaryContainer);
  color('on-primary-container', scheme.onPrimaryContainer);
  color('secondary', scheme.secondary);
  color('on-secondary', scheme.onSecondary);
  color('secondary-container', scheme.secondaryContainer);
  color('on-secondary-container', scheme.onSecondaryContainer);
  color('tertiary', scheme.tertiary);
  color('on-tertiary', scheme.onTertiary);
  color('tertiary-container', scheme.tertiaryContainer);
  color('on-tertiary-container', scheme.onTertiaryContainer);
  color('error', scheme.error);
  color('on-error', scheme.onError);
  color('error-container', scheme.errorContainer);
  color('on-error-container', scheme.onErrorContainer);
  color('surface', scheme.surface);
  color('on-surface', scheme.onSurface);
  color('on-surface-variant', scheme.onSurfaceVariant);
  color('surface-container-lowest', scheme.surfaceContainerLowest);
  color('surface-container-low', scheme.surfaceContainerLow);
  color('surface-container', scheme.surfaceContainer);
  color('surface-container-high', scheme.surfaceContainerHigh);
  color('surface-container-highest', scheme.surfaceContainerHighest);
  color('outline', scheme.outline);
  color('outline-variant', scheme.outlineVariant);
  color('inverse-surface', scheme.inverseSurface);
  color('on-inverse-surface', scheme.onInverseSurface);
  color('inverse-primary', scheme.inversePrimary);
  color('shadow', scheme.shadow);
  color('scrim', scheme.scrim);

  // Semantic aliases — the stable half of the token contract, and the
  // half the element rules actually consume. Material 2 themes need
  // their own sources: a Material 2 ColorScheme reports quasi-black
  // for outlineVariant and a flat surface for surfaceContainer, while
  // the app's real M2 widgets paint dividerColor and cardColor — the
  // shell must mirror what the app paints, not what the scheme claims.
  color('background', theme.scaffoldBackgroundColor);
  color('link', scheme.primary);
  color(
    'divider',
    theme.dividerTheme.color ??
        (m3 ? scheme.outlineVariant : theme.dividerColor),
  );
  color(
      'card',
      theme.cardTheme.color ??
          (m3 ? scheme.surfaceContainerLow : theme.cardColor));
  if (!m3) {
    color('surface-container', theme.cardColor);
    color('surface-container-low', theme.cardColor);
  }

  void type(String role, TextStyle? style) {
    if (style == null) return;
    final size = style.fontSize;
    if (size != null) {
      properties['--esen-type-$role-size'] = '${_cssNumber(size / 16)}rem';
    }
    properties['--esen-type-$role-weight'] =
        '${(style.fontWeight ?? FontWeight.w400).value}';
    final height = style.height;
    // A null height means "engine default from font metrics" — emit
    // `normal` rather than inventing a number.
    properties['--esen-type-$role-line'] =
        height == null ? 'normal' : _cssNumber(height);
    final tracking = style.letterSpacing;
    properties['--esen-type-$role-tracking'] =
        (tracking == null || tracking == 0) ? '0' : '${_cssNumber(tracking)}px';
  }

  type('display-large', text.displayLarge);
  type('display-medium', text.displayMedium);
  type('display-small', text.displaySmall);
  type('headline-large', text.headlineLarge);
  type('headline-medium', text.headlineMedium);
  type('headline-small', text.headlineSmall);
  type('title-large', text.titleLarge);
  type('title-medium', text.titleMedium);
  type('title-small', text.titleSmall);
  type('body-large', text.bodyLarge);
  type('body-medium', text.bodyMedium);
  type('body-small', text.bodySmall);
  type('label-large', text.labelLarge);
  type('label-medium', text.labelMedium);
  type('label-small', text.labelSmall);

  // The theme's family first, then its declared fallbacks, then the
  // system chain — the browser has not loaded the app's bundled font,
  // so without the chain the shell would silently render in the
  // browser's default serif. Names are validated (and Apple's
  // dot-prefixed platform names dropped) by the pure generator.
  final bodyStyle = text.bodyLarge ?? text.bodyMedium;
  properties['--esen-font-sans'] = [
    if (bodyStyle?.fontFamily != null) bodyStyle!.fontFamily!,
    ...?bodyStyle?.fontFamilyFallback,
    'system-ui',
    '-apple-system',
    'Segoe UI',
    'Roboto',
    'sans-serif',
  ].join(',');
  // ThemeData has no monospace slot; the token exists so developer CSS
  // can override it in one place.
  properties['--esen-font-mono'] =
      'ui-monospace,SFMono-Regular,Menlo,monospace';

  return SeoThemeTokens(
    dark: theme.brightness == Brightness.dark,
    properties: properties,
  );
}

/// Lowercase `#rrggbb`, or `#rrggbbaa` when the color carries alpha.
///
/// Written against the 3.27 float accessors — `.value` is deprecated
/// there and `toARGB32()` does not exist yet; this is why the package
/// requires Flutter >=3.27.0.
String _hex(Color color) {
  String channel(double value) =>
      ((value * 255.0).round().clamp(0, 255)).toRadixString(16).padLeft(2, '0');
  final rgb = '${channel(color.r)}${channel(color.g)}${channel(color.b)}';
  final alpha = (color.a * 255.0).round().clamp(0, 255);
  return alpha == 255
      ? '#$rgb'
      : '#$rgb${alpha.toRadixString(16).padLeft(2, '0')}';
}

/// Deterministic, compact number formatting: `1.5`, not `1.50`; `2`,
/// not `2.0`. The generated file is committed and diffed — formatting
/// noise would look like drift.
String _cssNumber(double value) {
  var s = value.toStringAsFixed(4);
  s = s.replaceFirst(RegExp(r'0+$'), '');
  s = s.replaceFirst(RegExp(r'\.$'), '');
  return s == '-0' ? '0' : s;
}
