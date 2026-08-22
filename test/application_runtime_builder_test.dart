import 'dart:collection';
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

  test('rejects conditional part syntax through the Dart parser', () async {
    await write(
      'lib/transition.dart',
      "part 'helper.dart' if (dart.library.io) 'io.dart';",
    );

    final error = await build();

    expect(error, isA<StateError>());
    expect((error as StateError).message, contains('Cannot parse'));
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

    for (final outputDirectory in const [
      'build/../lib',
      'build/%2Foutside',
      'build/nested%2Foutside',
    ]) {
      await expectLater(
        buildSeoTabsApplicationRuntime(
          SeoTabsRuntimeBuildRequest(
            id: 'fixture-tabs',
            library: 'package:fixture_app/transition.dart',
            symbol: 'transitionTabs',
            outputDirectory: outputDirectory,
          ),
          packageRoot: root.path,
        ),
        throwsArgumentError,
        reason: 'accepted: $outputDirectory',
      );
    }
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

    for (final symbol in const ['break', 'typedef', 'augment']) {
      await expectLater(
        buildSeoTabsApplicationRuntime(
          SeoTabsRuntimeBuildRequest(
            id: 'fixture-tabs',
            library: 'package:fixture_app/transition.dart',
            symbol: symbol,
          ),
          packageRoot: root.path,
        ),
        throwsArgumentError,
        reason: 'accepted Dart keyword: $symbol',
      );
    }
  });

  test('stepper builds use the same pre-compilation safety boundary', () async {
    await write('lib/transition.dart', "import 'dart:io';");

    await expectLater(
      buildSeoStepperApplicationRuntime(
        const SeoStepperRuntimeBuildRequest(
          id: 'fixture-stepper',
          library: 'package:fixture_app/transition.dart',
          symbol: 'transitionStepper',
        ),
        packageRoot: root.path,
      ),
      throwsStateError,
    );
    await expectLater(
      buildSeoStepperApplicationRuntime(
        const SeoStepperRuntimeBuildRequest(
          id: '../stepper',
          library: 'package:fixture_app/transition.dart',
          symbol: 'transitionStepper',
        ),
        packageRoot: root.path,
      ),
      throwsArgumentError,
    );
  });

  test('stepper effect builds use the same safety boundary', () async {
    await write('lib/transition.dart', "import 'dart:io';");

    await expectLater(
      buildSeoStepperEffectsApplicationRuntime(
        const SeoStepperEffectsRuntimeBuildRequest(
          id: 'fixture-stepper-effects',
          library: 'package:fixture_app/transition.dart',
          symbol: 'transitionStepperEffects',
          interactionIds: {'fixture-stepper'},
        ),
        packageRoot: root.path,
      ),
      throwsStateError,
    );
    await expectLater(
      buildSeoStepperEffectsApplicationRuntime(
        const SeoStepperEffectsRuntimeBuildRequest(
          id: '../stepper-effects',
          library: 'package:fixture_app/transition.dart',
          symbol: 'transitionStepperEffects',
          interactionIds: {'fixture-stepper'},
        ),
        packageRoot: root.path,
      ),
      throwsArgumentError,
    );
  });

  test('stepper effect builds require valid admitted interaction ids',
      () async {
    await write('lib/transition.dart', 'const value = 1;');

    for (final interactionIds in const <Set<String>>[
      {},
      {'Invalid ID'},
      {'valid-stepper', 'also invalid'},
    ]) {
      await expectLater(
        buildSeoStepperEffectsApplicationRuntime(
          SeoStepperEffectsRuntimeBuildRequest(
            id: 'fixture-stepper-effects',
            library: 'package:fixture_app/transition.dart',
            symbol: 'transitionStepperEffects',
            interactionIds: interactionIds,
          ),
          packageRoot: root.path,
        ),
        throwsArgumentError,
      );
    }
  });

  test('carousel builds use the same pre-compilation safety boundary',
      () async {
    await write('lib/transition.dart', "import 'dart:io';");

    await expectLater(
      buildSeoCarouselApplicationRuntime(
        const SeoCarouselRuntimeBuildRequest(
          id: 'fixture-carousel',
          library: 'package:fixture_app/transition.dart',
          symbol: 'transitionCarousel',
        ),
        packageRoot: root.path,
      ),
      throwsStateError,
    );
    await expectLater(
      buildSeoCarouselApplicationRuntime(
        const SeoCarouselRuntimeBuildRequest(
          id: '../carousel',
          library: 'package:fixture_app/transition.dart',
          symbol: 'transitionCarousel',
        ),
        packageRoot: root.path,
      ),
      throwsArgumentError,
    );
  });

  test('collection builds use the same pre-compilation safety boundary',
      () async {
    await write('lib/transition.dart', "import 'dart:io';");

    await expectLater(
      buildSeoCollectionApplicationRuntime(
        const SeoCollectionRuntimeBuildRequest(
          id: 'fixture-collection',
          library: 'package:fixture_app/transition.dart',
          symbol: 'transitionCollection',
        ),
        packageRoot: root.path,
      ),
      throwsStateError,
    );
    await expectLater(
      buildSeoCollectionApplicationRuntime(
        const SeoCollectionRuntimeBuildRequest(
          id: '../collection',
          library: 'package:fixture_app/transition.dart',
          symbol: 'transitionCollection',
        ),
        packageRoot: root.path,
      ),
      throwsArgumentError,
    );
  });

  test('bundle rejects invalid ownership before compilation', () async {
    const tabs = SeoRuntimeBundleEntry.tabs(
      library: 'package:fixture_app/tabs.dart',
      symbol: 'transitionTabs',
    );
    const stepper = SeoRuntimeBundleEntry.stepper(
      library: 'package:fixture_app/stepper.dart',
      symbol: 'transitionStepper',
    );
    const stepperEffects = SeoRuntimeBundleEntry.stepperEffects(
      library: 'package:fixture_app/stepper_effects.dart',
      symbol: 'transitionStepperEffects',
      interactionIds: {'fixture-stepper'},
    );

    for (final entries in const <List<SeoRuntimeBundleEntry>>[
      [tabs],
      [tabs, tabs],
      [stepper, stepperEffects],
    ]) {
      await expectLater(
        buildSeoApplicationRuntimeBundle(
          SeoRuntimeBundleBuildRequest(
            id: 'fixture-bundle',
            entries: entries,
          ),
          packageRoot: root.path,
        ),
        throwsArgumentError,
      );
    }
  });

  test('bundle checks every library and symbol before compilation', () async {
    await write('lib/tabs.dart', 'const tabs = 1;');
    await write('lib/collection.dart', "import 'dart:io';");

    await expectLater(
      buildSeoApplicationRuntimeBundle(
        const SeoRuntimeBundleBuildRequest(
          id: 'fixture-bundle',
          entries: [
            SeoRuntimeBundleEntry.tabs(
              library: 'package:fixture_app/tabs.dart',
              symbol: 'transitionTabs',
            ),
            SeoRuntimeBundleEntry.collection(
              library: 'package:fixture_app/collection.dart',
              symbol: 'transitionCollection',
            ),
          ],
        ),
        packageRoot: root.path,
      ),
      throwsStateError,
    );

    await expectLater(
      buildSeoApplicationRuntimeBundle(
        const SeoRuntimeBundleBuildRequest(
          id: 'fixture-bundle',
          entries: [
            SeoRuntimeBundleEntry.tabs(
              library: 'package:fixture_app/tabs.dart',
              symbol: 'transitionTabs',
            ),
            SeoRuntimeBundleEntry.collection(
              library: 'package:fixture_app/tabs.dart',
              symbol: 'await',
            ),
          ],
        ),
        packageRoot: root.path,
      ),
      throwsArgumentError,
    );
  });

  test('bundle validates Stepper effect admission ids', () async {
    await write('lib/tabs.dart', 'const tabs = 1;');
    await write('lib/stepper.dart', 'const stepper = 1;');

    await expectLater(
      buildSeoApplicationRuntimeBundle(
        const SeoRuntimeBundleBuildRequest(
          id: 'fixture-bundle',
          entries: [
            SeoRuntimeBundleEntry.tabs(
              library: 'package:fixture_app/tabs.dart',
              symbol: 'transitionTabs',
            ),
            SeoRuntimeBundleEntry.stepperEffects(
              library: 'package:fixture_app/stepper.dart',
              symbol: 'transitionStepperEffects',
              interactionIds: {'invalid id'},
            ),
          ],
        ),
        packageRoot: root.path,
      ),
      throwsArgumentError,
    );
  });

  test('bundle snapshots Stepper effect ids before its first await', () async {
    await write('lib/tabs.dart', 'const tabs = 1;');
    await write('lib/stepper.dart', 'const stepper = 1;');
    final interactionIds = _TrackingSet<String>({'fixture-stepper'});

    final build = buildSeoApplicationRuntimeBundle(
      SeoRuntimeBundleBuildRequest(
        id: 'fixture-bundle',
        entries: [
          const SeoRuntimeBundleEntry.tabs(
            library: 'package:fixture_app/tabs.dart',
            symbol: 'transitionTabs',
          ),
          SeoRuntimeBundleEntry.stepperEffects(
            library: 'package:fixture_app/stepper.dart',
            symbol: 'transitionStepperEffects',
            interactionIds: interactionIds,
          ),
        ],
      ),
      packageRoot: root.path,
    );
    final readBeforeFirstAwait = interactionIds.wasIterated;
    interactionIds
      ..clear()
      ..add('invalid id');
    await File('${root.path}/.dart_tool/package_config.json')
        .writeAsString('{}');

    await expectLater(build, throwsStateError);
    expect(readBeforeFirstAwait, isTrue);
  });

  test('bundle config parser accepts only its exact structured schema',
      () async {
    await write(
        'runtime_bundle.json',
        jsonEncode({
          'schemaVersion': 1,
          'id': 'fixture-bundle',
          'entries': [
            {
              'kind': 'collection',
              'library': 'package:fixture_app/collection.dart',
              'symbol': 'transitionCollection',
            },
            {
              'kind': 'stepper-effects',
              'library': 'package:fixture_app/stepper.dart',
              'symbol': 'transitionStepperEffects',
              'interactionIds': ['stepper-b', 'stepper-a'],
            },
          ],
        }));

    final request = await loadSeoRuntimeBundleBuildRequest(
      'runtime_bundle.json',
      packageRoot: root.path,
      outputDirectory: 'build/custom',
    );

    expect(request.id, 'fixture-bundle');
    expect(request.outputDirectory, 'build/custom');
    expect(request.entries, hasLength(2));
    expect(request.entries.first, isA<SeoCollectionRuntimeBundleEntry>());
    expect(
      request.entries.last.interactionIds,
      {'stepper-a', 'stepper-b'},
    );

    for (final invalid in [
      {
        'schemaVersion': 1.0,
        'id': 'fixture-bundle',
        'entries': const [],
      },
      {
        'schemaVersion': 1,
        'id': 'fixture-bundle',
        'entries': const [],
        'unknown': true,
      },
      {
        'schemaVersion': 1,
        'id': 'fixture-bundle',
        'entries': [
          {
            'kind': 'unknown',
            'library': 'package:fixture_app/a.dart',
            'symbol': 'transition',
          }
        ],
      },
      {
        'schemaVersion': 1,
        'id': 'fixture-bundle',
        'entries': [
          {
            'kind': 'stepper-effects',
            'library': 'package:fixture_app/a.dart',
            'symbol': 'transition',
            'interactionIds': ['same', 'same'],
          }
        ],
      },
    ]) {
      await write('invalid_bundle.json', jsonEncode(invalid));
      await expectLater(
        loadSeoRuntimeBundleBuildRequest(
          'invalid_bundle.json',
          packageRoot: root.path,
        ),
        throwsFormatException,
      );
    }
  });

  test('bundle config path and input size fail closed', () async {
    for (final path in const [
      '../outside.json',
      '%2e%2e/outside.json',
      '%2Foutside.json',
      'nested%2Foutside.json',
      'nested/%5coutside.json',
      '/absolute.json',
      'config.json?alternate=true',
    ]) {
      await expectLater(
        loadSeoRuntimeBundleBuildRequest(
          path,
          packageRoot: root.path,
        ),
        throwsArgumentError,
      );
    }

    await write('oversized.json', List.filled(32 * 1024 + 1, ' ').join());
    await expectLater(
      loadSeoRuntimeBundleBuildRequest(
        'oversized.json',
        packageRoot: root.path,
      ),
      throwsStateError,
    );

    final outside = await Directory.systemTemp.createTemp('esen_bundle_config');
    addTearDown(() => outside.delete(recursive: true));
    await File('${outside.path}/bundle.json').writeAsString('{}');
    await Link('${root.path}/linked.json')
        .create('${outside.path}/bundle.json');
    await expectLater(
      loadSeoRuntimeBundleBuildRequest(
        'linked.json',
        packageRoot: root.path,
      ),
      throwsArgumentError,
    );
  });
}

final class _UnexpectedSuccess {
  const _UnexpectedSuccess();
}

final class _TrackingSet<E> extends SetBase<E> {
  _TrackingSet(Set<E> values) : _values = values;

  final Set<E> _values;
  bool wasIterated = false;

  @override
  Iterator<E> get iterator {
    wasIterated = true;
    return _values.iterator;
  }

  @override
  int get length => _values.length;

  @override
  bool add(E value) => _values.add(value);

  @override
  bool contains(Object? element) => _values.contains(element);

  @override
  E? lookup(Object? element) => _values.lookup(element);

  @override
  bool remove(Object? value) => _values.remove(value);

  @override
  Set<E> toSet() {
    wasIterated = true;
    return _values.toSet();
  }
}
