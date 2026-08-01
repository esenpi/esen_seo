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
  /// is no prerendered HTML to show. Requires `EsenSeo.init()` in the
  /// app so the handoff actually runs.
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
const String seoContainerStyle =
    'position:absolute;top:0;left:0;width:0;height:0;'
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
