/// CSS delivery for the visible shell.
///
/// Styles are inlined into the document `<head>` rather than linked as
/// an external file: the shell's whole point is to paint before Flutter
/// loads, and an extra round trip would give that advantage away.
library;

import 'html_renderer.dart';
import 'seo_container.dart';
import 'seo_theme_css.dart';

/// Marks the shell stylesheet as managed by esen_seo.
///
/// Deliberately **not** the `data-esen-seo` marker of the meta tags:
/// `injectMetaNodes` replaces everything carrying that marker on every
/// `setMeta` call, which would tear the shell's styles out from under
/// it while it is still on screen.
const String seoStyleAttribute = 'data-esen-seo-style';

/// Wraps [css] in a `<style>` element for the document head.
String seoStyleTagHtml(String css, {String? nonce}) {
  final value = nonce?.trim();
  final nonceAttribute = value == null || value.isEmpty
      ? ''
      : ' nonce="${HtmlRenderer.escapeAttribute(value)}"';
  return '<style $seoStyleAttribute$nonceAttribute>'
      '${escapeStylesheet(css)}</style>';
}

final RegExp _styleClose = RegExp(r'<(?=/\s*style)', caseSensitive: false);

/// Makes [css] safe to inline inside a `<style>` element.
///
/// CSS must not be HTML-escaped — `a > b`, `&` in nesting and the
/// `@media (400px <= width)` range syntax are all legitimate. The only
/// dangerous sequence is `</style`, which would close the element early
/// and let the rest of the CSS be parsed as markup. It is neutralized
/// with the CSS hex escape `\3c ` (same character, still valid CSS) —
/// the stylesheet equivalent of the `<` escape used for JSON-LD.
String escapeStylesheet(String css) => css.replaceAll(_styleClose, r'\3c ');

/// A minimal classless stylesheet so semantic HTML looks presentable
/// without any work — the visual counterpart to the smart defaults.
/// Used by default for DOM-first pages and available for
/// [SeoRenderMode.visibleShell]. In the invisible default mode there is
/// nothing to style.
///
/// Scoped to the semantic container, so it can never interfere with the
/// rest of the document. Deliberately opinion-free: system fonts, a
/// readable measure, sane spacing. To make the shell match your app,
/// generate a themed replacement with `seoStylesheetFromTheme` (or
/// pass your own CSS) — and give it an opaque `background`, otherwise
/// Flutter's still-empty surface shows through while it boots.
///
/// The layout skeleton is shared with the theme bridge
/// (`seo_theme_css.dart`): one source for the geometry, so a grid fix
/// in one stylesheet cannot quietly miss the other. Look — colors and
/// the type scale — stays separate by design: this file is the
/// opinion-free web scale (2/1.5/1.25 rem), the bridge mirrors the
/// app's Material scale.
///
/// The grid gives every block a centred, readable measure without
/// fighting the element margins below over specificity.
const String seoDefaultStylesheet = '''
#$seoContainerId{$seoLayoutDeclarations;background:#fff;color:#1a1a1a;font-family:system-ui,-apple-system,"Segoe UI",Roboto,sans-serif;line-height:1.6}
$seoLayoutChildRules$seoLayoutSpacingRules#$seoContainerId h1,#$seoContainerId h2,#$seoContainerId h3{line-height:1.25}
#$seoContainerId h1{font-size:2rem}
#$seoContainerId h2{font-size:1.5rem}
#$seoContainerId h3{font-size:1.25rem}
#$seoContainerId a{color:#0b57d0;text-decoration:underline}
#$seoContainerId blockquote{border-left:3px solid #d0d0d0;color:#4a4a4a}
#$seoContainerId code{font-family:ui-monospace,SFMono-Regular,Menlo,monospace;font-size:.9em}
@media (prefers-color-scheme:dark){
#$seoContainerId{background:#111;color:#e8e8e8}
#$seoContainerId a{color:#8ab4f8}
#$seoContainerId blockquote{border-left-color:#4a4a4a;color:#b0b0b0}
}
''';
