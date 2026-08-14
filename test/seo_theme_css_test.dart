import 'package:esen_seo/esen_seo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// The internal fragments and generator, tested directly where the
// public surface would make the assertion indirect.
import 'package:esen_seo/src/renderer/seo_theme_css.dart';

/// Hex exactly the way the bridge writes it — float channels, 3.27 API.
String hexOf(Color c) {
  String ch(double v) =>
      ((v * 255.0).round().clamp(0, 255)).toRadixString(16).padLeft(2, '0');
  return '#${ch(c.r)}${ch(c.g)}${ch(c.b)}';
}

void main() {
  group('seoStylesheetFromTheme — the mapping', () {
    test('a Material 3 theme lands as tokens and element rules', () {
      final css = seoStylesheetFromTheme(
        ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      );
      expect(css, contains('#esen-seo-content{'));
      expect(css, contains('--esen-color-primary:#'));
      expect(css, contains('--esen-color-secondary-container:#'));
      expect(css, contains('color-scheme:light;'));
      // The heading chain is the Material scale.
      expect(
        css,
        contains('font-size:var(--esen-type-headline-large-size,2rem)'),
      );
      // M3 headlineLarge: 32px = 2rem, weight 400, height 1.25.
      expect(css, contains('--esen-type-headline-large-size:2rem'));
      expect(css, contains('--esen-type-headline-large-weight:400'));
      expect(css, contains('--esen-type-headline-large-line:1.25'));
    });

    test('raw ThemeData has no text geometry — the bridge localizes', () {
      // The gotcha this guards: without ThemeData.localize the sizes
      // are simply null and the stylesheet would carry no type scale.
      expect(ThemeData().textTheme.bodyLarge?.fontSize, isNull);
      final css = seoStylesheetFromTheme(ThemeData());
      expect(css, contains('--esen-type-body-large-size:1rem'));
      expect(css, contains('--esen-type-body-medium-size:0.875rem'));
    });

    test('link color is the primary role', () {
      final theme = ThemeData(colorSchemeSeed: Colors.indigo);
      final css = seoStylesheetFromTheme(theme);
      expect(
        css,
        contains('--esen-color-link:${hexOf(theme.colorScheme.primary)}'),
      );
      expect(css, contains('color:var(--esen-color-link,#0b57d0)'));
    });

    test('a Material 2 theme mirrors what M2 widgets actually paint', () {
      final theme = ThemeData(useMaterial3: false);
      final css = seoStylesheetFromTheme(theme);
      // The M2 divider is ThemeData.dividerColor — the scheme's
      // outlineVariant would be quasi-black and the shell would lie.
      expect(
          css, contains('--esen-color-divider:${hexOf(theme.dividerColor)}'));
      // Surfaces come from cardColor, not the flat M2 scheme fallback.
      expect(
        css,
        contains('--esen-color-surface-container:${hexOf(theme.cardColor)}'),
      );
    });

    test(
        'an alpha-carrying color becomes 8-digit hex — except the '
        'background, which is forced opaque', () {
      final theme = ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0x80FFFFFF),
        dividerTheme: const DividerThemeData(color: Color(0x1F000000)),
      );
      final css = seoStylesheetFromTheme(theme);
      // Divider keeps its alpha: black at 12% is what the app paints.
      expect(css, contains('--esen-color-divider:#0000001f'));
      // The shell background may not be translucent: Flutter's empty
      // boot surface would shine through — the alpha is stripped.
      expect(css, contains('--esen-color-background:#ffffff;'));
      expect(css, isNot(contains('--esen-color-background:#ffffff80')));
    });

    test('the theme font leads a system fallback chain, quoted', () {
      final css = seoStylesheetFromTheme(ThemeData(fontFamily: 'My Font'));
      expect(
        css,
        contains('--esen-font-sans:"My Font",system-ui,-apple-system,'
            '"Segoe UI",Roboto,sans-serif'),
      );
    });

    test('bodyRole controls what paragraphs read as', () {
      final medium = seoStylesheetFromTheme(
        ThemeData(),
        bodyRole: SeoBodyRole.bodyMedium,
      );
      expect(medium, contains('font-size:var(--esen-type-body-medium-size'));
    });

    test('the body role is applied completely — weight and tracking too', () {
      // Generating the tokens and consuming only size/line silently
      // dropped a themed body weight — and even standard Material
      // tracking (bodyLarge carries 0.5px).
      final theme = ThemeData(
        textTheme: const TextTheme(
          bodyLarge: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 2),
        ),
      );
      final css = seoStylesheetFromTheme(theme);
      expect(css, contains('--esen-type-body-large-weight:700'));
      expect(css, contains('--esen-type-body-large-tracking:2px'));
      expect(css, contains('font-weight:var(--esen-type-body-large-weight'));
      expect(
        css,
        contains('letter-spacing:var(--esen-type-body-large-tracking'),
      );
      // And the plain default: M3 bodyLarge tracking 0.5px reaches the
      // container instead of sitting unused in the token block.
      final plain = seoStylesheetFromTheme(ThemeData());
      expect(plain, contains('--esen-type-body-large-tracking:0.5px'));
      expect(
        plain,
        contains('letter-spacing:var(--esen-type-body-large-tracking'),
      );
    });

    test('bodyRole: bodyMedium sources the font family from bodyMedium', () {
      // Metrics from bodyMedium but the family from bodyLarge was a
      // half-applied role — the documented 1:1 parity has to mean the
      // whole role.
      final theme = ThemeData(
        textTheme: const TextTheme(
          bodyLarge: TextStyle(fontFamily: 'LargeFont'),
          bodyMedium: TextStyle(fontFamily: 'MediumFont'),
        ),
      );
      final medium = seoStylesheetFromTheme(
        theme,
        bodyRole: SeoBodyRole.bodyMedium,
      );
      expect(medium, contains('--esen-font-sans:MediumFont,'));
      expect(medium, isNot(contains('LargeFont')));
      final large = seoStylesheetFromTheme(theme);
      expect(large, contains('--esen-font-sans:LargeFont,'));
    });

    test(
        'a dark theme with different body typography lands in the '
        'media block', () {
      final light = ThemeData(colorSchemeSeed: Colors.teal);
      final dark = ThemeData(
        colorSchemeSeed: Colors.teal,
        brightness: Brightness.dark,
        textTheme: const TextTheme(
          bodyLarge: TextStyle(fontWeight: FontWeight.w300),
        ),
      );
      final css = seoStylesheetFromTheme(light, darkTheme: dark);
      final block = css.split('@media (prefers-color-scheme:dark)').last;
      expect(block, contains('--esen-type-body-large-weight:300'));
    });
  });

  group('the dark palette', () {
    final light = ThemeData(colorSchemeSeed: Colors.teal);
    final dark = ThemeData(
      colorSchemeSeed: Colors.teal,
      brightness: Brightness.dark,
    );

    test('system mode: media block with only the differing tokens', () {
      final css = seoStylesheetFromTheme(light, darkTheme: dark);
      expect(css, contains('@media (prefers-color-scheme:dark)'));
      final block = css.split('@media (prefers-color-scheme:dark)').last;
      expect(block, contains('color-scheme:dark'));
      expect(block, contains('--esen-color-background:'));
      // Same typography on both sides — the media block must not
      // repeat it, or the block is half the stylesheet again.
      expect(block, isNot(contains('--esen-type-')));
    });

    test('manual mode adds explicit dark without changing default output', () {
      final unchanged = seoStylesheetFromTheme(light, darkTheme: dark);
      final manual = seoStylesheetFromTheme(
        light,
        darkTheme: dark,
        enableManualTheme: true,
      );

      expect(unchanged, isNot(contains('data-esen-theme')));
      expect(
        manual,
        contains('html[data-esen-theme="dark"] #esen-seo-content{'),
      );
      expect(
        manual,
        contains('html:not([data-esen-theme="light"])'
            ':not([data-esen-theme="dark"]) #esen-seo-content{'),
      );
      expect(
        manual,
        isNot(contains('html[data-esen-theme="light"] #esen-seo-content{')),
      );
    });

    test('manual mode is ignored when the app forces one palette', () {
      final forced = seoStylesheetFromTheme(
        light,
        darkTheme: dark,
        mode: SeoThemeMode.dark,
        enableManualTheme: true,
      );

      expect(forced, isNot(contains('data-esen-theme')));
      expect(forced, isNot(contains('@media')));
    });

    test('forced dark: the dark palette IS the base, no media block', () {
      final css = seoStylesheetFromTheme(
        light,
        darkTheme: dark,
        mode: SeoThemeMode.dark,
      );
      expect(css, isNot(contains('@media')));
      expect(css, contains('color-scheme:dark;'));
      expect(
        css,
        contains('--esen-color-background:'
            '${hexOf(dark.scaffoldBackgroundColor)}'),
      );
    });

    test('forced light: darkTheme is ignored entirely', () {
      final css = seoStylesheetFromTheme(
        light,
        darkTheme: dark,
        mode: SeoThemeMode.light,
      );
      expect(css, isNot(contains('@media')));
      expect(css, contains('color-scheme:light;'));
    });

    test(
        'a darkTheme built without Brightness.dark is a light palette — '
        'the media block must not claim color-scheme:dark over it', () {
      // The common Flutter slip: colorSchemeSeed without brightness, so
      // theme.brightness is light. Keying the block on !light.dark used
      // to emit color-scheme:dark over those light colors.
      final fakeDark = ThemeData(colorSchemeSeed: Colors.orange);
      final css = seoStylesheetFromTheme(light, darkTheme: fakeDark);
      expect(fakeDark.brightness, Brightness.light);
      if (css.contains('@media (prefers-color-scheme:dark)')) {
        final block = css.split('@media (prefers-color-scheme:dark)').last;
        expect(block, isNot(contains('color-scheme:dark')));
      }
    });

    test('two identical light palettes produce no bare color-scheme flip', () {
      final css = seoStylesheetFromTheme(light, darkTheme: light);
      // No differing tokens and no brightness change: nothing to say
      // under prefers-dark, so no lone `color-scheme:dark` over light.
      if (css.contains('@media')) {
        final block = css.split('@media (prefers-color-scheme:dark)').last;
        expect(block, isNot(contains('color-scheme:dark')));
      }
    });
  });

  group('platform-independent output — the guard runs on both dev and CI', () {
    test('an app with no fontFamily generates the same chain everywhere', () {
      // The platform default (Roboto on Linux, .SF… on Apple) must not
      // leak into the committed file, or the drift guard fires on the
      // toolchain. Roboto is in the static chain (skipped), .SF… is
      // dropped — both collapse to a system-ui-leading chain.
      final css = seoStylesheetFromTheme(ThemeData());
      expect(css, contains('--esen-font-sans:system-ui,'));
      // Roboto appears at most once — the skip also dedupes it.
      final chain =
          RegExp('--esen-font-sans:([^;]*)').firstMatch(css)!.group(1)!;
      expect('Roboto'.allMatches(chain).length, lessThanOrEqualTo(1));
    });

    test('a real custom font still leads the chain', () {
      final css = seoStylesheetFromTheme(ThemeData(fontFamily: 'Inter'));
      expect(css, contains('--esen-font-sans:Inter,system-ui,'));
    });

    test('setting fontFamily to a chain member does not duplicate it', () {
      final css = seoStylesheetFromTheme(ThemeData(fontFamily: 'Roboto'));
      final chain =
          RegExp('--esen-font-sans:([^;]*)').firstMatch(css)!.group(1)!;
      expect('Roboto'.allMatches(chain).length, 1);
    });
  });

  group('the choke point — hostile token values', () {
    test('missing heading tokens fall back to the Material type scale', () {
      final css = seoThemeCss(
        light: const SeoThemeTokens(dark: false, properties: {}),
      );

      for (final rule in const [
        'font-size:var(--esen-type-headline-large-size,2rem);'
            'font-weight:var(--esen-type-headline-large-weight,400)',
        'font-size:var(--esen-type-headline-medium-size,1.75rem);'
            'font-weight:var(--esen-type-headline-medium-weight,400)',
        'font-size:var(--esen-type-headline-small-size,1.5rem);'
            'font-weight:var(--esen-type-headline-small-weight,400)',
        'font-size:var(--esen-type-title-large-size,1.375rem);'
            'font-weight:var(--esen-type-title-large-weight,400)',
        'font-size:var(--esen-type-title-medium-size,1rem);'
            'font-weight:var(--esen-type-title-medium-weight,500)',
        'font-size:var(--esen-type-title-small-size,0.875rem);'
            'font-weight:var(--esen-type-title-small-weight,500)',
        'font-size:var(--esen-type-body-medium-size,0.875rem);'
            'font-weight:var(--esen-type-body-medium-weight,400)',
        'font-size:var(--esen-type-body-small-size,0.75rem);'
            'font-weight:var(--esen-type-body-small-weight,400)',
      ]) {
        expect(css, contains(rule));
      }
    });

    test('a CSS breakout in fontFamily is dropped, not escaped', () {
      const payload = 'a"}#esen-seo-content{position:fixed!important}';
      final css = seoStylesheetFromTheme(ThemeData(fontFamily: payload));
      expect(css, isNot(contains('!important')));
      expect(css, isNot(contains('position:fixed')));
      expect(css, isNot(contains(payload)));
      // The chain degrades to the system fonts instead of breaking.
      expect(css, contains('--esen-font-sans:system-ui,'));
    });

    test(
        "Apple's dot-prefixed platform names are dropped by the same "
        'rule', () {
      final css = seoStylesheetFromTheme(ThemeData(fontFamily: '.SF UI Text'));
      expect(css, isNot(contains('.SF UI Text')));
      expect(css, contains('--esen-font-sans:system-ui,'));
    });

    test(
        'hostile values on every token kind are refused by the pure '
        'generator', () {
      final css = seoThemeCss(
        light: const SeoThemeTokens(dark: false, properties: {
          '--esen-color-primary': 'red}body{display:none',
          '--esen-color-background': 'url(javascript:alert(1))',
          '--esen-type-body-large-size': '1rem}*{margin:0',
          '--esen-type-body-large-weight': '400;position:fixed',
          '--esen-not-a-known-kind': '1',
          'no-token-at-all': 'x',
        }),
      );
      expect(css, isNot(contains('body{')));
      expect(css, isNot(contains('javascript')));
      expect(css, isNot(contains('*{margin')));
      expect(css, isNot(contains('position:fixed')));
      expect(css, isNot(contains('no-token-at-all')));
      expect(css, isNot(contains('--esen-not-a-known-kind')));
    });
  });

  group('output invariants', () {
    final css = seoStylesheetFromTheme(
      ThemeData(colorSchemeSeed: Colors.teal),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.teal,
        brightness: Brightness.dark,
      ),
    );

    test('never !important — the inline geometry pin must stay unbeatable', () {
      expect(css, isNot(contains('!important')));
    });

    test('every rule is scoped to the container', () {
      // String scan, not a rendering proof: each selector must start
      // with the container id. The media block opens with `{` before
      // its inner selector, so `{` is an anchor too — otherwise a
      // future unscoped rule inside @media would slip past this check.
      final rules = RegExp(r'(^|[\n}{])([^@{}]+)\{').allMatches(css);
      for (final rule in rules) {
        final selector = rule.group(2)!.trim();
        if (selector.isEmpty) continue;
        expect(
          selector.startsWith('#esen-seo-content'),
          isTrue,
          reason: 'unscoped selector: "$selector"',
        );
      }
    });

    test('deterministic: same theme, same bytes', () {
      final again = seoStylesheetFromTheme(
        ThemeData(colorSchemeSeed: Colors.teal),
        darkTheme: ThemeData(
          colorSchemeSeed: Colors.teal,
          brightness: Brightness.dark,
        ),
      );
      expect(again, css);
    });

    test('no </style — the head embedding stays intact downstream', () {
      expect(css.toLowerCase(), isNot(contains('</style')));
    });
  });

  group('one layout skeleton for both stylesheets', () {
    test('default and themed output share the fragments verbatim', () {
      final themed = seoStylesheetFromTheme(ThemeData());
      for (final fragment in [
        seoLayoutDeclarations,
        seoLayoutChildRules,
        seoLayoutSpacingRules,
      ]) {
        expect(seoDefaultStylesheet, contains(fragment));
        expect(themed, contains(fragment));
      }
    });
  });
}
