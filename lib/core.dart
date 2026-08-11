/// Pure-Dart core of esen_seo — no Flutter, no shelf.
///
/// Import this in files shared between the Flutter app and the SSR
/// server, e.g. the SEO route table:
///
/// ```dart
/// // lib/seo_routes.dart — imported by main.dart AND bin/server.dart
/// import 'package:esen_seo/core.dart';
///
/// final seoRoutes = [
///   SeoRoute(path: '/', meta: (_) => SeoMeta(title: 'Home')),
/// ];
/// ```
///
/// The full Flutter API lives in `package:esen_seo/esen_seo.dart`,
/// the server API in `package:esen_seo/server.dart` — both re-export
/// this core.
library;

export 'src/components/seo_component_format.dart';
export 'src/components/seo_components.dart';
export 'src/components/seo_collection_transition.dart';
export 'src/components/seo_collection_url.dart';
export 'src/components/seo_motion.dart' show SeoMotionPreset;
export 'src/components/seo_rich_text.dart';
export 'src/components/seo_tabs_transition.dart';
export 'src/components/seo_theme_transition.dart';
export 'src/meta/seo_meta.dart';
export 'src/meta/seo_schema.dart';
export 'src/renderer/html_renderer.dart';
export 'src/renderer/seo_container.dart'
    show SeoRenderMode, seoDomFirstAttribute;
export 'src/renderer/seo_dom_first.dart'
    show
        seoDomFirstFeatureScriptHtml,
        seoDomFirstFeatureBootstrapScriptHtml,
        seoDomFirstFeatureStyleHtml,
        seoDomFirstBootstrapScriptAttribute,
        seoDomFirstScriptAttribute,
        seoDomFirstCollectionStylesheet,
        seoDomFirstTabsStylesheet,
        seoDomFirstThemeToggleStylesheet;
export 'src/renderer/seo_interactions.dart';
export 'src/renderer/seo_motion_stylesheet.dart' show seoMotionStylesheet;
export 'src/renderer/seo_node.dart';
export 'src/renderer/seo_stylesheet.dart' show seoDefaultStylesheet;
export 'src/routing/seo_resolution.dart';
export 'src/routing/seo_resolved_page.dart';
export 'src/routing/seo_route.dart';
export 'src/routing/seo_route_delivery.dart';
