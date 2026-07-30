/// The DOM container that carries the semantic HTML mirror.
///
/// Shared between the runtime DOM injector (web) and the static
/// prerenderer (server) so both produce the identical container — the
/// running app finds and reuses a prerendered one by its id.
library;

/// The element id of the semantic HTML container.
const String seoContainerId = 'esen-seo-content';

/// Keeps the container invisible and non-interactive: the Flutter
/// canvas stays the visible UI, screen readers use Flutter's own
/// semantics tree.
const String seoContainerStyle =
    'position:absolute;top:0;left:0;width:0;height:0;'
    'overflow:hidden;pointer-events:none;';

/// The complete container element around a rendered [bodyHtml] fragment.
String seoContainerHtml(String bodyHtml) =>
    '<div id="$seoContainerId" aria-hidden="true" '
    'style="$seoContainerStyle">$bodyHtml</div>';
