/// The web half of the conditional export in `testing.dart`.
///
/// The real guard reads and writes files, which needs `dart:io` — and
/// an unconditional export of `dart:io` code would make the WHOLE
/// `testing.dart` entry point VM-only, breaking
/// `flutter test --platform chrome` for users who only ever wanted
/// `auditSeoParity`. On the web platform the guard is therefore this
/// stub: same signature, throws when actually called.
library;

/// See `theme_guard.dart` — this platform cannot run the guard.
void checkOrUpdateSeoThemeCss(
  String css, {
  String path = 'lib/seo_theme.g.dart',
  String variable = 'seoThemeCss',
  bool? update,
}) {
  throw UnsupportedError(
    'checkOrUpdateSeoThemeCss reads and writes the generated file, which '
    'needs dart:io — run this test on the host VM (the default), not with '
    '--platform chrome.',
  );
}
