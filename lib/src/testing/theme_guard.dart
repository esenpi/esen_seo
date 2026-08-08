/// The drift guard for the theme bridge.
///
/// The bridge's weak point is not the mapping — it is the month after:
/// someone changes the theme and forgets to regenerate the committed
/// CSS, and the shell silently shows last month's design. This guard
/// makes that a red CI run instead.
///
/// One function does both jobs, so generator and guard can never
/// disagree about the file format:
///
/// ```dart
/// // test/seo_theme_css_test.dart
/// test('the shell stylesheet matches the theme', () {
///   checkOrUpdateSeoThemeCss(
///     seoStylesheetFromTheme(buildLightTheme(), darkTheme: buildDarkTheme()),
///   );
/// });
/// ```
///
/// Every ordinary `flutter test` run verifies; regenerating is an
/// explicit, deliberate act:
///
/// ```
/// flutter test test/seo_theme_css_test.dart --dart-define=esenSeoUpdate=true
/// ```
///
/// Deliberately **only** the compile-time define, no environment
/// variable fallback: an ambient variable that happens to be set in CI
/// would flip the guard into write mode and make it silently green
/// forever — a guard you can switch off by accident is not a guard.
///
/// What this proves and what it does not: the guard compares the file
/// against the theme **the test built**. If the app's `MaterialApp`
/// uses an inline theme and the test rebuilds its own copy, the guard
/// stays green while the shell drifts. Share one `buildTheme()`
/// function between app and test — and, if you want the last gap
/// closed, add a widget test that pumps the app and asserts
/// `MaterialApp.theme == buildTheme()`.
library;

import 'dart:io';

final RegExp _dartIdentifier = RegExp(r'^[a-zA-Z_][a-zA-Z0-9_]*$');

/// The complete reserved-word list from the Dart language spec, plus
/// `await`/`yield`. Each matches the identifier shape but cannot be a
/// top-level variable name — writing `const String break = …` produces
/// a file that will not compile. A hand-picked subset held exactly
/// until review reached for a word that was not on it.
const Set<String> _dartReservedWords = {
  'assert', 'await', 'break', 'case', 'catch', 'class', 'const', 'continue',
  'default', 'do', 'else', 'enum', 'extends', 'false', 'final', 'finally',
  'for', 'if', 'in', 'is', 'new', 'null', 'rethrow', 'return', 'super',
  'switch', 'this', 'throw', 'true', 'try', 'var', 'void', 'while', 'with',
  'yield', //
};

/// Verifies that [css] matches the committed generated file — or, in
/// update mode (`--dart-define=esenSeoUpdate=true`), (re)writes it.
///
/// Throws [StateError] with the exact regenerate command when the file
/// is missing or has drifted. The generated header records the Dart
/// toolchain version as a comment that is *excluded* from the
/// comparison — so a pure SDK bump with identical CSS stays green,
/// while a real drift message can point out that dev and CI toolchains
/// differ instead of claiming "theme changed" when it did not.
void checkOrUpdateSeoThemeCss(
  String css, {
  String path = 'lib/seo_theme.g.dart',
  String variable = 'seoThemeCss',
  bool? update,
}) {
  // The variable name is interpolated into generated Dart source —
  // the same rule as every other value this package writes somewhere:
  // validate, don't hope.
  if (!_dartIdentifier.hasMatch(variable) ||
      _dartReservedWords.contains(variable)) {
    throw ArgumentError.value(
        variable, 'variable', 'must be a valid Dart identifier');
  }

  final write = update ?? const bool.fromEnvironment('esenSeoUpdate');
  final file = File(path);
  final expected = _generatedFile(css, variable);

  if (write) {
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(expected);
    return;
  }

  if (!file.existsSync()) {
    throw StateError(
      'No generated theme stylesheet at $path.\n'
      'Generate it once with:\n'
      '  flutter test <this test file> --dart-define=esenSeoUpdate=true\n'
      'and commit the file.',
    );
  }

  final actual = file.readAsStringSync();
  if (_payload(actual) == _payload(expected)) return;

  throw StateError(
    'The generated theme stylesheet at $path does not match the theme.\n'
    'Either the theme changed without regenerating, or the file was '
    'generated with a different Flutter/esen_seo version than this run '
    '(headers: ${_toolchainOf(actual) ?? 'unknown'} on disk, '
    '${_toolchainOf(expected)} here).\n'
    'Regenerate with:\n'
    '  flutter test <this test file> --dart-define=esenSeoUpdate=true\n'
    'First difference:\n${_firstDifference(_payload(actual), _payload(expected))}',
  );
}

/// The complete generated file. A single-quoted, fully escaped string
/// literal — never a raw `r'''` literal, which cannot escape a `'''`
/// occurring in the CSS at all.
String _generatedFile(String css, String variable) {
  final encoded = css
      .replaceAll(r'\', r'\\')
      .replaceAll("'", r"\'")
      .replaceAll(r'$', r'\$')
      .replaceAll('\r', r'\r')
      .replaceAll('\n', r'\n');
  // The wrapped assignment is what `dart format` produces for a line
  // this long — freshly generated files survive a format run
  // byte-identically instead of looking like drift.
  return '// GENERATED by esen_seo. Do not edit by hand.\n'
      '// Regenerate: flutter test <your theme test> '
      '--dart-define=esenSeoUpdate=true\n'
      '// Toolchain: Dart ${Platform.version.split(' ').first} '
      '(informational — excluded from the drift check)\n'
      '\n'
      '/// The shell stylesheet generated from the app theme.\n'
      "const String $variable =\n    '$encoded';\n";
}

final RegExp _declaration = RegExp(
  r"String\s+([A-Za-z_$][A-Za-z0-9_$]*)\s*=\s*'(.*)';",
  dotAll: true,
);

/// The comparison payload: the declared variable name plus the encoded
/// CSS literal.
///
/// Compared instead of file bytes because formatters rewrap the code
/// AROUND the literal — the guard's own first catch in the wild was
/// `dart format` reflowing the assignment, which is not drift. String
/// literal *contents* are the one thing no formatter touches. The name
/// is part of the payload: comparing the literal alone let a caller
/// switch `variable:` and stay green while the file still declared the
/// old name — and the import site would break, with the guard vouching
/// for the file. Files where no declaration can be found fall back to
/// a whole-text comparison minus the informational toolchain line.
String _payload(String content) {
  final declaration = _declaration.firstMatch(content);
  if (declaration != null) {
    return '${declaration.group(1)}|${declaration.group(2)}';
  }
  return content
      .split('\n')
      .where((line) => !line.startsWith('// Toolchain:'))
      .join('\n');
}

String? _toolchainOf(String content) {
  for (final line in content.split('\n')) {
    if (line.startsWith('// Toolchain: ')) {
      return line.substring('// Toolchain: '.length).split(' (').first;
    }
  }
  return null;
}

/// A short, quoted excerpt around the first differing character —
/// enough to see *what* changed without dumping two 5 KB strings.
String _firstDifference(String a, String b) {
  final length = a.length < b.length ? a.length : b.length;
  var index = 0;
  while (index < length && a[index] == b[index]) {
    index++;
  }
  String excerpt(String s) {
    final start = index < 40 ? 0 : index - 40;
    final end = (index + 40) > s.length ? s.length : index + 40;
    return s.substring(start, end).replaceAll('\n', r'\n');
  }

  return '  on disk : …${excerpt(a)}…\n  expected: …${excerpt(b)}…';
}
