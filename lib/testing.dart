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
/// [checkOrUpdateSeoThemeCss]. The guard needs `dart:io`, so it is
/// exported conditionally: on the host VM (the normal place for it)
/// you get the real one; compiled for the web — someone running their
/// parity suite with `--platform chrome` — the entry point still
/// compiles, and only actually *calling* the guard throws. An
/// unconditional export would have made every consumer of this library
/// VM-only for the sake of one function they may never use.
///
/// Kept out of `esen_seo.dart` on purpose: this is test-time
/// scaffolding and has no business in an app's release build.
library;

export 'audit.dart';
export 'src/audit/parity_compare.dart' show SeoParityPolicy, compareSeoTrees;
export 'src/testing/parity.dart'
    show auditSeoParity, captureSeoNodes, enableSeoForParity;
export 'src/testing/theme_guard_stub.dart'
    if (dart.library.io) 'src/testing/theme_guard.dart'
    show checkOrUpdateSeoThemeCss;
