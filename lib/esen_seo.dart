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
export 'src/routing/seo_route_observer.dart';
export 'src/tags/seo_tags.dart';
export 'src/widgets/seo_bar_chart.dart';
