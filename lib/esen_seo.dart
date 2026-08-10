/// esen_seo — real semantic HTML for Flutter Web.
///
/// No Puppeteer, no headless Chrome, no hidden-HTML tricks: pure Dart that
/// mirrors your widget tree as clean semantic HTML.
///
/// ```dart
/// Text('Willkommen').seo(SeoTextTag.h1);  // oder kurz: .h1
/// Image.network(url).seo(alt: 'Foto');
/// Column(children: [...]).seo();
/// ```
library;

export 'core.dart';
export 'src/controller/seo_controller.dart' show EsenSeo, SeoMode;
export 'src/extensions/column_seo.dart';
export 'src/extensions/image_seo.dart';
export 'src/extensions/link_seo.dart';
export 'src/extensions/row_seo.dart';
export 'src/extensions/seo_shortcuts.dart';
export 'src/extensions/text_seo.dart';
export 'src/extensions/widget_seo.dart';
export 'src/renderer/seo_theme_css.dart' show SeoBodyRole, SeoThemeMode;
export 'src/routing/seo_route_observer.dart';
export 'src/theme/seo_theme_stylesheet.dart' show seoStylesheetFromTheme;
export 'src/tags/seo_tags.dart';
export 'src/widgets/seo_bar_chart.dart';
export 'src/widgets/seo_block.dart';
export 'src/widgets/seo_breadcrumbs.dart';
export 'src/widgets/seo_carousel.dart';
export 'src/widgets/seo_data_table.dart';
export 'src/widgets/seo_faq.dart';
export 'src/widgets/seo_figure.dart';
export 'src/widgets/seo_list_view.dart';
export 'src/widgets/seo_nav_menu.dart';
export 'src/widgets/seo_pie_chart.dart';
export 'src/widgets/seo_rating.dart';
export 'src/widgets/seo_tabs.dart';
export 'src/widgets/seo_testimonial.dart';
