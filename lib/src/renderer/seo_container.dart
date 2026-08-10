/// The DOM container that carries the semantic HTML mirror.
///
/// Shared between the runtime DOM injector (web) and the static
/// prerenderer (server) so both produce the identical container — the
/// running app finds and reuses a prerendered one by its id.
library;

/// How the semantic HTML tree is presented in the browser.
///
/// The tree itself is identical in both modes — only its role differs:
/// an invisible mirror for crawlers, or the page the user actually sees
/// until Flutter takes over.
enum SeoRenderMode {
  /// The semantic HTML stays invisible next to the Flutter canvas: a
  /// pure crawler mirror. This is the default and the behaviour of
  /// every esen_seo version so far.
  seoOnly,

  /// The prerendered HTML **is** the first frame: visible, styleable
  /// and readable before the Flutter engine has even loaded. As soon as
  /// Flutter renders its first frame, the container hands the screen
  /// over and falls back to being the invisible mirror ([seoOnly]).
  ///
  /// Only meaningful for prerendered pages — during `flutter run` there
  /// is no prerendered HTML to show.
  ///
  /// **`EsenSeo.init()` is required**, not merely recommended. The
  /// handoff is triggered by the first mirror refresh, and the only
  /// things that schedule one are `init()` and a mounting `.seo()`
  /// widget. An app that calls neither leaves the shell exactly where it
  /// is: a full-viewport, opaque, clickable layer at `z-index:9999` over
  /// a Flutter app that has long since painted — and nothing times it
  /// out, because a shell that stays put is the correct behaviour when
  /// the engine never arrives. The package cannot tell the two apart
  /// from the outside, so this one call is the difference.
  visibleShell,
}

/// The element id of the semantic HTML container.
const String seoContainerId = 'esen-seo-content';

/// Marks a prerendered container that is currently the visible shell.
///
/// The runtime injector looks for this attribute to know that a handoff
/// is pending — so the app needs no configuration of its own and the
/// two sides can never drift apart.
const String seoShellAttribute = 'data-esen-seo-shell';

/// Marks a semantic container that permanently owns the browser route.
const String seoDomFirstAttribute = 'data-esen-seo-dom-first';

/// Marks the head elements the injector manages, so a repeated pass
/// replaces its own tags and leaves everything hardcoded in
/// `index.html` alone.
///
/// Lives here rather than in the injector because the attribute policy
/// has to refuse it: content that may wear the marker is content the
/// injector would later mistake for its own and remove.
const String seoMetaMarker = 'data-esen-seo';

/// Takes the invisible mirror out of the keyboard tab order and the
/// accessibility tree.
///
/// `aria-hidden` alone is not enough: the container is only clipped to
/// zero size, so links and `<summary>` elements inside it keep their
/// layout boxes and stay focusable — a keyboard user would tab into
/// content nobody can see. Browsers without `inert` simply ignore it.
const String seoInertAttribute = 'inert';

/// Keeps the container invisible and non-interactive: the Flutter
/// canvas stays the visible UI, screen readers use Flutter's own
/// semantics tree.
///
/// `width:0;height:0` alone does not make a box invisible — it only
/// empties its *content* box. Padding, borders, outlines and shadows
/// are drawn outside it, and a stylesheet that reaches
/// `#esen-seo-content` supplies them: [seoDefaultStylesheet] sets
/// `padding:2rem 1.25rem;background:#fff`, which turns the "zero-sized"
/// mirror into a 40×64 px white rectangle in the top-left corner —
/// permanently, and on every visible shell as well, because the handoff
/// restores exactly this style while the stylesheet stays in the head.
///
/// So the geometry is pinned here rather than assumed. Inline beats any
/// author rule short of `!important`, and everything that could give the
/// box a painted surface is set to nothing.
const String seoContainerStyle =
    'position:absolute;top:0;left:0;width:0;height:0;'
    'min-width:0;min-height:0;max-width:0;max-height:0;'
    'padding:0;border:0;outline:0;box-shadow:none;'
    'overflow:hidden;pointer-events:none;';

/// How long the shell takes to fade out once Flutter has painted.
const int seoShellFadeMs = 150;

/// Structural style of the visible shell — it covers the viewport and
/// sits above Flutter's view elements.
///
/// Covering matters: between creating its DOM host and painting the
/// first frame, the Flutter engine puts an empty surface on the page.
/// With the shell on top, that whole boot sequence stays invisible and
/// the user only ever sees content.
///
/// Only structure lives here (the app must not be able to break the
/// overlay); the look — background, colors, spacing — belongs to the
/// stylesheet, which an inline style would otherwise always beat. The
/// transition is baked in so the fade-out can start by changing nothing
/// but `opacity`.
const String seoShellStyle = 'position:fixed;inset:0;overflow:auto;'
    'z-index:9999;transition:opacity ${seoShellFadeMs}ms ease-out;';

/// The inline style for [mode].
String seoContainerStyleFor(SeoRenderMode mode) =>
    mode == SeoRenderMode.visibleShell ? seoShellStyle : seoContainerStyle;

/// The complete container element around a rendered [bodyHtml] fragment.
String seoContainerHtml(
  String bodyHtml, {
  SeoRenderMode mode = SeoRenderMode.seoOnly,
}) {
  if (mode == SeoRenderMode.visibleShell) {
    // Kein aria-hidden: in dieser Phase ist der Shell der echte Inhalt.
    return '<div id="$seoContainerId" $seoShellAttribute="visible" '
        'style="$seoShellStyle">$bodyHtml</div>';
  }
  return '<div id="$seoContainerId" aria-hidden="true" $seoInertAttribute '
      'style="$seoContainerStyle">$bodyHtml</div>';
}

/// The visible container for a route delivered without a Flutter runtime.
String seoDomFirstContainerHtml(String bodyHtml) =>
    '<div id="$seoContainerId" $seoDomFirstAttribute="true">$bodyHtml</div>';
