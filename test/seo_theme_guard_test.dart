import 'dart:io';

import 'package:esen_seo/testing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;
  late String path;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('esen_seo_guard_');
    path = '${dir.path}/seo_theme.g.dart';
  });

  tearDown(() => dir.deleteSync(recursive: true));

  group('checkOrUpdateSeoThemeCss', () {
    test('a missing file fails with the regenerate command', () {
      expect(
        () => checkOrUpdateSeoThemeCss('a{b:c}', path: path, update: false),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('esenSeoUpdate=true'),
        )),
      );
    });

    test('update writes, the next plain run is green', () {
      checkOrUpdateSeoThemeCss('a{b:c}', path: path, update: true);
      expect(File(path).existsSync(), isTrue);
      expect(
        () => checkOrUpdateSeoThemeCss('a{b:c}', path: path, update: false),
        returnsNormally,
      );
    });

    test('drift fails loudly, names both toolchains and the fix', () {
      checkOrUpdateSeoThemeCss('a{b:c}', path: path, update: true);
      expect(
        () =>
            checkOrUpdateSeoThemeCss('a{b:CHANGED}', path: path, update: false),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          allOf(
            contains('does not match'),
            contains('esenSeoUpdate=true'),
            contains('First difference'),
          ),
        )),
      );
    });

    test(
        'the toolchain header is informational — tampering with it is '
        'not drift', () {
      checkOrUpdateSeoThemeCss('a{b:c}', path: path, update: true);
      final file = File(path);
      file.writeAsStringSync(file.readAsStringSync().replaceFirst(
          RegExp(r'// Toolchain: .*'), '// Toolchain: Dart 0.0.0'));
      expect(
        () => checkOrUpdateSeoThemeCss('a{b:c}', path: path, update: false),
        returnsNormally,
      );
    });

    test('the writer escapes everything Dart string syntax cares about', () {
      // Quotes, dollars, backslashes, newlines — and the triple quote
      // that a raw-string writer could never escape at all.
      const hostile = "a{content:'\\'; font-family:\"x\$y\"}\n'''\nb{c:d}";
      checkOrUpdateSeoThemeCss(hostile, path: path, update: true);
      final generated = File(path).readAsStringSync();
      expect(generated, contains(r'\$'));
      expect(generated, contains(r'\\'));
      expect(generated, contains(r'\n'));
      expect(generated, isNot(contains("'''")));
      // And the round trip agrees: the same input verifies green.
      expect(
        () => checkOrUpdateSeoThemeCss(hostile, path: path, update: false),
        returnsNormally,
      );
    });

    test('dart format reflowing the generated file is not drift', () {
      // The guard's first real-world catch was itself: `dart format`
      // rewraps the assignment around the literal, and a byte compare
      // called that a theme change. Only the literal's CONTENT counts.
      checkOrUpdateSeoThemeCss('a{b:c}', path: path, update: true);
      final file = File(path);
      // Simulate a formatter with different wrapping taste.
      file.writeAsStringSync(file
          .readAsStringSync()
          .replaceFirst("=\n    '", " = '")
          .replaceFirst('// GENERATED', '  // GENERATED'));
      expect(
        () => checkOrUpdateSeoThemeCss('a{b:c}', path: path, update: false),
        returnsNormally,
      );
    });

    test('a variable name that is not a Dart identifier is refused', () {
      expect(
        () => checkOrUpdateSeoThemeCss('a{b:c}',
            path: path, variable: 'x; }', update: true),
        throwsArgumentError,
      );
    });

    test('a Dart reserved word is refused — it would not compile', () {
      // 'class' matches the identifier shape but `const String class ='
      // is a syntax error in the file that imports the g.dart.
      for (final word in ['class', 'const', 'void']) {
        expect(
          () => checkOrUpdateSeoThemeCss('a{b:c}',
              path: path, variable: word, update: true),
          throwsArgumentError,
          reason: word,
        );
      }
    });
  });
}
