/// The pure half of the theme bridge: turns a set of design tokens
/// into the shell stylesheet.
///
/// ThemeData lives on the Flutter side (`seoStylesheetFromTheme` in
/// `lib/src/theme/`); this file never sees it. The split is the same
/// one the whole package is built on: the Flutter half reads the
/// framework, the pure half produces strings — and `prerenderSite`,
/// which runs without Flutter, only ever meets the string.
///
/// **This generator is the choke point for token safety.** Every token
/// value is validated against an allow list before it is written,
/// no matter where it came from — the Flutter bridge today, a CMS
/// tomorrow. `escapeStylesheet` only neutralizes `</style`; it does
/// not parse CSS, so a hostile value like
/// `a"}#esen-seo-content{position:fixed!important}` would otherwise
/// break out of its declaration, beat the inline geometry pin and
/// reintroduce the 40×64 px incident. Values that fail validation are
/// dropped — the element rules carry fallbacks, so the page degrades
/// to the default look instead of breaking (the smart-defaults ethos).
library;

import 'seo_container.dart';

/// Which palette the generated stylesheet serves.
///
/// `themeMode` is a `MaterialApp` argument, not a `ThemeData` field —
/// the bridge cannot read it, so the developer states it here.
enum SeoThemeMode {
  /// Light palette by default, dark palette inside a
  /// `prefers-color-scheme: dark` media block — mirrors a MaterialApp
  /// with `theme:` and `darkTheme:` left on `ThemeMode.system`.
  system,

  /// Only the light palette, no media block — the app forces
  /// `ThemeMode.light`.
  light,

  /// Only the dark palette as the base block, no media block — the
  /// app forces `ThemeMode.dark`.
  dark,
}

/// Which text role paragraphs and list items get.
///
/// Flutter's `DefaultTextStyle` under Material is `bodyMedium` (14 px);
/// the shell defaults to [bodyLarge] (16 px) because it is a reading
/// document and 16 px is the browser baseline. Pick [bodyMedium] for
/// 1:1 parity with the app's default text.
enum SeoBodyRole { bodyLarge, bodyMedium }

// ─────────────────────── shared layout skeleton ───────────────────────
//
// One source for the geometry that the default stylesheet and every
// themed stylesheet share. Two copies of this grid were the package's
// own SeoNavMenu lesson waiting to happen: whoever fixes the layout in
// one place must not be able to forget the other.

/// The container's layout declarations — grid with a readable measure.
const String seoLayoutDeclarations =
    'display:grid;grid-template-columns:1fr min(44rem,100%) 1fr;'
    'align-content:start;padding:2rem 1.25rem';

/// Child placement and box sizing, shared verbatim.
const String seoLayoutChildRules = '#$seoContainerId>*{grid-column:2}\n'
    '#$seoContainerId *{box-sizing:border-box}\n';

/// Structural spacing, shared verbatim between default and themed
/// output. Look — colors, sizes, weights — deliberately lives outside.
const String seoLayoutSpacingRules =
    '#$seoContainerId h1,#$seoContainerId h2,#$seoContainerId h3,'
    '#$seoContainerId h4,#$seoContainerId h5,#$seoContainerId h6'
    '{margin:2rem 0 .75rem}\n'
    '#$seoContainerId h1{margin-top:0}\n'
    '#$seoContainerId p,#$seoContainerId ul,#$seoContainerId ol'
    '{margin:0 0 1rem}\n'
    '#$seoContainerId ul,#$seoContainerId ol{padding-left:1.5rem}\n'
    '#$seoContainerId li{margin:.25rem 0}\n'
    '#$seoContainerId img{max-width:100%;height:auto}\n'
    '#$seoContainerId blockquote{margin:0 0 1rem;padding-left:1rem}\n';

// ──────────────────────────── token model ────────────────────────────

/// One resolved palette: the full ordered token set for one brightness.
///
/// Internal in 0.9 — the public surface is `seoStylesheetFromTheme` on
/// the Flutter side. The shape is designed to become public with the
/// CMS (tokens are data; mode and body role are generator options and
/// deliberately NOT part of this model).
class SeoThemeTokens {
  const SeoThemeTokens({required this.dark, required this.properties});

  /// Whether this palette is a dark one (`color-scheme: dark`).
  final bool dark;

  /// Ordered map of `--esen-…` custom property name to CSS value.
  /// Values are validated by the generator, not trusted from here.
  final Map<String, String> properties;
}

// ───────────────────────── value validation ─────────────────────────
//
// Allow lists per token kind. What does not match is dropped; the
// element rules fall back via `var(--x, fallback)`. Escaping free
// strings instead was rejected in review: a block list of dangerous
// characters loses the moment one is missed — the project's oldest
// lesson, applied to the eighth list.

final RegExp _hexColor = RegExp(r'^#[0-9a-f]{6}([0-9a-f]{2})?$');
final RegExp _remSize = RegExp(r'^\d+(\.\d+)?rem$');
final RegExp _fontWeight = RegExp(r'^[1-9]00$');
final RegExp _lineHeight = RegExp(r'^(\d+(\.\d+)?|normal)$');
final RegExp _tracking = RegExp(r'^(-?\d+(\.\d+)?px|0)$');
final RegExp _tokenName = RegExp(r'^--esen-[a-z0-9-]+$');

/// A single font family name. Deliberately narrow: letters first, then
/// letters, digits, spaces and hyphens. This one rule does two jobs at
/// once — it refuses every CSS breakout payload, and it drops Apple's
/// dot-prefixed platform names ('.SF UI Text') that are not valid CSS
/// family names anyway.
final RegExp _fontFamilyName = RegExp(r'^[A-Za-z][A-Za-z0-9 -]*$');

/// Generic family keywords that pass unquoted.
const Set<String> _genericFontFamilies = {
  'system-ui', 'sans-serif', 'serif', 'monospace', 'ui-monospace',
  'ui-sans-serif', 'ui-serif', 'ui-rounded', 'cursive', 'fantasy',
  // The classic cross-platform chain members.
  '-apple-system',
};

/// Validates and normalizes a comma-separated font family list.
/// Returns `null` when nothing legitimate survives.
String? _sanitizeFontList(String value) {
  final kept = <String>[];
  for (var family in value.split(',')) {
    family = family.trim();
    // Already-quoted names: strip the quotes, validate the inside.
    if (family.length >= 2 &&
        ((family.startsWith('"') && family.endsWith('"')) ||
            (family.startsWith("'") && family.endsWith("'")))) {
      family = family.substring(1, family.length - 1).trim();
    }
    if (family.isEmpty) continue;
    if (_genericFontFamilies.contains(family)) {
      kept.add(family);
      continue;
    }
    if (!_fontFamilyName.hasMatch(family)) continue; // dropped, by design
    kept.add(family.contains(' ') ? '"$family"' : family);
  }
  return kept.isEmpty ? null : kept.join(',');
}

/// Whether [value] is acceptable for the token [name].
///
/// The kind is derived from the name — color tokens end in nothing
/// special but live under `--esen-color-`, type tokens carry their
/// property as the last segment.
bool _validTokenValue(String name, String value) {
  if (name.startsWith('--esen-color-')) return _hexColor.hasMatch(value);
  if (name.endsWith('-size')) return _remSize.hasMatch(value);
  if (name.endsWith('-weight')) return _fontWeight.hasMatch(value);
  if (name.endsWith('-line')) return _lineHeight.hasMatch(value);
  if (name.endsWith('-tracking')) return _tracking.hasMatch(value);
  // Font lists are normalized rather than merely checked.
  if (name == '--esen-font-sans' || name == '--esen-font-mono') return true;
  return false; // unknown token kind: not on the list, not in the output
}

/// The one token that MUST be opaque: a translucent shell background
/// lets Flutter's still-empty boot surface shine through — the exact
/// effect visibleShell exists to prevent. Enforced, not documented.
const String _backgroundToken = '--esen-color-background';

Map<String, String> _sanitize(Map<String, String> raw) {
  final out = <String, String>{};
  raw.forEach((name, value) {
    if (!_tokenName.hasMatch(name)) return;
    if (name == '--esen-font-sans' || name == '--esen-font-mono') {
      final list = _sanitizeFontList(value);
      if (list != null) out[name] = list;
      return;
    }
    var v = value.trim().toLowerCase();
    if (name == _backgroundToken && _hexColor.hasMatch(v) && v.length == 9) {
      v = v.substring(0, 7); // strip alpha: the shell background is opaque
    }
    if (_validTokenValue(name, v)) out[name] = v;
  });
  return out;
}

// ───────────────────────────── generator ─────────────────────────────

/// The static fallback chains — also what invalid font tokens degrade to.
const String _sansFallback =
    'system-ui,-apple-system,"Segoe UI",Roboto,sans-serif';
const String _monoFallback = 'ui-monospace,SFMono-Regular,Menlo,monospace';

String _typeVars(String element, String role) => '#$seoContainerId $element{'
    'font-size:var(--esen-type-$role-size);'
    'font-weight:var(--esen-type-$role-weight);'
    'line-height:var(--esen-type-$role-line,normal);'
    'letter-spacing:var(--esen-type-$role-tracking,0)}';

/// Builds the themed shell stylesheet from validated tokens.
///
/// Internal in 0.9: reachable only through `seoStylesheetFromTheme`.
/// Replaces `seoDefaultStylesheet` — never concatenate the two, they
/// declare the same rules at the same specificity and source order
/// would decide.
String seoThemeCss({
  required SeoThemeTokens light,
  SeoThemeTokens? dark,
  SeoThemeMode mode = SeoThemeMode.system,
  SeoBodyRole bodyRole = SeoBodyRole.bodyLarge,
}) {
  final base = mode == SeoThemeMode.dark ? (dark ?? light) : light;
  final baseTokens = _sanitize(base.properties);
  final body = bodyRole == SeoBodyRole.bodyLarge ? 'body-large' : 'body-medium';

  final buffer = StringBuffer()
    ..write('#$seoContainerId{')
    ..write(seoLayoutDeclarations)
    ..write(';');
  baseTokens.forEach((name, value) => buffer.write('$name:$value;'));
  buffer
    ..write('color-scheme:${base.dark ? 'dark' : 'light'};')
    ..write('background:var($_backgroundToken,#fff);')
    ..write('color:var(--esen-color-on-surface,#1a1a1a);')
    ..write('font-family:var(--esen-font-sans,$_sansFallback);')
    ..write('font-size:var(--esen-type-$body-size,1rem);')
    ..write('line-height:var(--esen-type-$body-line,1.5)}\n')
    ..write(seoLayoutChildRules)
    ..write(seoLayoutSpacingRules)
    // Headings from the Material scale. All six get rules — the default
    // stylesheet styles only h1–h3, which is a documented deviation.
    ..write('${_typeVars('h1', 'headline-large')}\n')
    ..write('${_typeVars('h2', 'headline-medium')}\n')
    ..write('${_typeVars('h3', 'headline-small')}\n')
    ..write('${_typeVars('h4', 'title-large')}\n')
    ..write('${_typeVars('h5', 'title-medium')}\n')
    ..write('${_typeVars('h6', 'title-small')}\n')
    ..write('#$seoContainerId a{'
        'color:var(--esen-color-link,#0b57d0);text-decoration:underline}\n')
    ..write('#$seoContainerId blockquote{'
        'border-left:3px solid var(--esen-color-divider,#d0d0d0);'
        'color:var(--esen-color-on-surface-variant,#4a4a4a)}\n')
    ..write('#$seoContainerId code,#$seoContainerId pre{'
        'font-family:var(--esen-font-mono,$_monoFallback);font-size:.9em}\n')
    ..write('#$seoContainerId pre{'
        'background:var(--esen-color-surface-container,transparent);'
        'padding:1rem;overflow-x:auto}\n')
    ..write('#$seoContainerId hr{'
        'border:0;border-top:1px solid var(--esen-color-divider,#d0d0d0)}\n')
    ..write('#$seoContainerId table{border-collapse:collapse}\n')
    ..write('#$seoContainerId th,#$seoContainerId td{'
        'text-align:left;padding:.375rem .75rem;'
        'border-bottom:1px solid var(--esen-color-divider,#d0d0d0)}\n')
    ..write('${_typeVars('th', 'title-small')}\n')
    ..write('${_typeVars('td', 'body-medium')}\n')
    ..write('#$seoContainerId figcaption{'
        'color:var(--esen-color-on-surface-variant,#4a4a4a)}\n')
    ..write('${_typeVars('figcaption', 'body-small')}\n');

  // The dark palette rides in a media block — but only the tokens that
  // actually differ, and only in system mode. Forced modes have no
  // second palette at all: a shell that ignores the OS preference in
  // exactly the way the app does.
  if (mode == SeoThemeMode.system && dark != null) {
    final darkTokens = _sanitize(dark.properties);
    final diff = <String, String>{};
    darkTokens.forEach((name, value) {
      if (baseTokens[name] != value) diff[name] = value;
    });
    if (diff.isNotEmpty || !light.dark) {
      buffer.write('@media (prefers-color-scheme:dark){#$seoContainerId{');
      diff.forEach((name, value) => buffer.write('$name:$value;'));
      buffer.write('color-scheme:dark}}\n');
    }
  }

  return buffer.toString();
}
