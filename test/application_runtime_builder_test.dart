import 'dart:convert';
import 'dart:io';

import 'package:esen_seo/src/tooling/application_runtime_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('esen_runtime_builder');
    await Directory('${root.path}/lib').create();
    await Directory('${root.path}/.dart_tool').create();
    await File('${root.path}/.dart_tool/package_config.json').writeAsString(
      jsonEncode({
        'configVersion': 2,
        'packages': [
          {
            'name': 'fixture_app',
            'rootUri': '../',
            'packageUri': 'lib/',
            'languageVersion': '3.6',
          },
        ],
      }),
    );
  });

  tearDown(() => root.delete(recursive: true));

  Future<void> write(String path, String source) async {
    final file = File('${root.path}/$path');
    await file.parent.create(recursive: true);
    await file.writeAsString(source);
  }

  Future<Object> build() async {
    try {
      await buildSeoTabsApplicationRuntime(
        const SeoTabsRuntimeBuildRequest(
          id: 'fixture-tabs',
          library: 'package:fixture_app/transition.dart',
          symbol: 'transitionTabs',
        ),
        packageRoot: root.path,
      );
      return const _UnexpectedSuccess();
    } catch (error) {
      return error;
    }
  }

  test('rejects a direct IO import before compilation', () async {
    await write('lib/transition.dart', "import 'dart:io';");

    expect(await build(), isA<StateError>());
  });

  test('rejects a forbidden transitive import', () async {
    await write('lib/transition.dart', "import 'helper.dart';");
    await write('lib/helper.dart', "import 'dart:io';");

    expect(await build(), isA<StateError>());
  });

  test('rejects conditional and deferred imports', () async {
    await write(
      'lib/transition.dart',
      "import 'helper.dart' if (dart.library.io) 'io.dart';",
    );
    await write('lib/helper.dart', 'const value = 1;');
    await write('lib/io.dart', 'const value = 2;');

    expect(await build(), isA<StateError>());

    await write(
      'lib/transition.dart',
      "import 'helper.dart' deferred as helper;",
    );
    expect(await build(), isA<StateError>());
  });

  test('rejects third-party packages and browser libraries', () async {
    await write('lib/transition.dart', "import 'package:web/web.dart';");

    expect(await build(), isA<StateError>());

    await write('lib/transition.dart', "import 'dart:js_interop';");
    expect(await build(), isA<StateError>());
  });

  test('rejects a part that escapes lib through a real file', () async {
    await write('outside.dart', 'part of transition;');
    await write('lib/transition.dart', "part '../outside.dart';");

    expect(await build(), isA<StateError>());
  });

  test('rejects malformed source through the Dart parser', () async {
    await write('lib/transition.dart', 'void broken( {');

    expect(await build(), isA<StateError>());
  });

  test('rejects held top-level and static application state', () async {
    await write('lib/transition.dart', 'var selected = 0;');

    expect(
      (await build() as StateError).message,
      contains('non-const top-level state'),
    );

    await write(
      'lib/transition.dart',
      'class Selection { static final values = <int>[]; }',
    );
    expect(
      (await build() as StateError).message,
      contains('non-const static state'),
    );
  });

  test('accepts a library below a package URI with a trailing slash', () async {
    await write('lib/transition.dart', "import 'dart:io';");

    final error = await build();

    expect(error, isA<StateError>());
    expect((error as StateError).message, contains('Forbidden Dart library'));
    expect(error.message, isNot(contains('escapes the application lib')));
  });

  test('rejects path traversal in the output before compilation', () async {
    await write('lib/transition.dart', 'const value = 1;');

    await expectLater(
      buildSeoTabsApplicationRuntime(
        const SeoTabsRuntimeBuildRequest(
          id: 'fixture-tabs',
          library: 'package:fixture_app/transition.dart',
          symbol: 'transitionTabs',
          outputDirectory: 'build/../lib',
        ),
        packageRoot: root.path,
      ),
      throwsArgumentError,
    );
  });

  test('rejects an output directory that escapes through a symlink', () async {
    final outside =
        await Directory.systemTemp.createTemp('esen_runtime_output');
    addTearDown(() => outside.delete(recursive: true));
    await Link('${root.path}/build').create(outside.path);

    await expectLater(
      buildSeoTabsApplicationRuntime(
        const SeoTabsRuntimeBuildRequest(
          id: 'fixture-tabs',
          library: 'package:fixture_app/transition.dart',
          symbol: 'transitionTabs',
        ),
        packageRoot: root.path,
      ),
      throwsArgumentError,
    );
  });

  test('rejects reserved symbols and unsafe runtime ids', () async {
    await expectLater(
      buildSeoTabsApplicationRuntime(
        const SeoTabsRuntimeBuildRequest(
          id: '../tabs',
          library: 'package:fixture_app/transition.dart',
          symbol: 'break',
        ),
        packageRoot: root.path,
      ),
      throwsArgumentError,
    );
  });
}

final class _UnexpectedSuccess {
  const _UnexpectedSuccess();
}
