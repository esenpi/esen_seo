/// The half of the audit that needs Flutter: does the app actually
/// render what the route table promises?
///
/// Everything in `package:esen_seo/audit.dart` reads the route table,
/// so it can only ever confirm that the table agrees with itself. This
/// library compares it against the widget tree a visitor sees — the one
/// question that matters most, because serving crawlers a separately
/// built body is only defensible while the two say the same thing.
///
/// Import it from a widget test:
///
/// ```dart
/// import 'package:esen_seo/testing.dart';
///
/// testWidgets('bots and users see the same pages', (tester) async {
///   final report = await auditSeoParity(
///     routes: seoRoutes,
///     siteBase: siteBase,
///     paths: const ['/', '/docs'],
///     pump: (path) async {
///       await tester.pumpWidget(MyApp(initialRoute: path));
///       await tester.pumpAndSettle();
///     },
///   );
///   expect(report.passes(), isTrue, reason: '\n${report.describe()}');
/// });
/// ```
///
/// This library also carries the theme bridge's drift guard,
/// [checkOrUpdateSeoThemeCss] — which brings `dart:io` into this entry
/// point, so it runs in host tests only, not in web tests.
///
/// Kept out of `esen_seo.dart` on purpose: this is test-time
/// scaffolding and has no business in an app's release build.
library;

export 'audit.dart';
export 'src/audit/parity_compare.dart' show SeoParityPolicy, compareSeoTrees;
export 'src/testing/parity.dart'
    show auditSeoParity, captureSeoNodes, enableSeoForParity;
export 'src/testing/theme_guard.dart' show checkOrUpdateSeoThemeCss;
