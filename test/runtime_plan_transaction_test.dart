import 'dart:io';

import 'package:esen_seo/src/tooling/runtime_plan_transaction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;
  late Directory output;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('esen_runtime_plan');
    output = Directory('${root.path}/runtimes');
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  Future<void> writeArtifactSet(
    Directory directory, {
    String javascript = 'runtime',
    String manifest = 'manifest',
  }) async {
    await directory.create(recursive: true);
    await File('${directory.path}/tabs-demo.js').writeAsString(javascript);
    await File('${directory.path}/tabs-demo.json').writeAsString(manifest);
  }

  const expected = {'tabs-demo.js', 'tabs-demo.json'};

  test('a later staging failure leaves prior output byte-identical', () async {
    await output.create();
    final sentinel = File('${output.path}/prior.txt');
    await sentinel.writeAsString('prior output\n');

    await expectLater(
      runSeoRuntimePlanTransaction<void>(
        output: output,
        expectedFiles: expected,
        check: false,
        build: (staging) async {
          await File('${staging.path}/tabs-demo.js').writeAsString('runtime');
          throw StateError('second runtime failed');
        },
      ),
      throwsStateError,
    );

    expect(await sentinel.readAsString(), 'prior output\n');
    expect(await output.list().map((entry) => entry.path).toList(), [
      sentinel.path,
    ]);
    expect(await _temporarySiblings(output), isEmpty);
  });

  test('success replaces the complete directory and removes stale files',
      () async {
    await output.create();
    await File('${output.path}/stale.js').writeAsString('stale');

    final result = await runSeoRuntimePlanTransaction<String>(
      output: output,
      expectedFiles: expected,
      check: false,
      build: (staging) async {
        await writeArtifactSet(staging);
        return 'built';
      },
    );

    expect(result, 'built');
    expect(await _fileNames(output), ['tabs-demo.js', 'tabs-demo.json']);
    expect(await _temporarySiblings(output), isEmpty);
  });

  test('check compares bytes and the complete file set without mutation',
      () async {
    await writeArtifactSet(output);
    final before = await _snapshot(output);

    await runSeoRuntimePlanTransaction<void>(
      output: output,
      expectedFiles: expected,
      check: true,
      build: (staging) => writeArtifactSet(staging),
    );
    expect(await _snapshot(output), before);

    final extra = File('${output.path}/old-runtime.js');
    await extra.writeAsString('old');
    final withExtra = await _snapshot(output);
    await expectLater(
      runSeoRuntimePlanTransaction<void>(
        output: output,
        expectedFiles: expected,
        check: true,
        build: (staging) => writeArtifactSet(staging),
      ),
      throwsStateError,
    );
    expect(await _snapshot(output), withExtra);
    await extra.delete();

    await File('${output.path}/tabs-demo.js').writeAsString('changed');
    final changed = await _snapshot(output);
    await expectLater(
      runSeoRuntimePlanTransaction<void>(
        output: output,
        expectedFiles: expected,
        check: true,
        build: (staging) => writeArtifactSet(staging),
      ),
      throwsStateError,
    );
    expect(await _snapshot(output), changed);
    expect(await _temporarySiblings(output), isEmpty);
  });

  test('incomplete, additional and nested staged entries are never admitted',
      () async {
    for (final build in <Future<void> Function(Directory)>[
      (staging) async {
        await File('${staging.path}/tabs-demo.js').writeAsString('runtime');
      },
      (staging) async {
        await writeArtifactSet(staging);
        await File('${staging.path}/extra.txt').writeAsString('extra');
      },
      (staging) async {
        await writeArtifactSet(staging);
        await Directory('${staging.path}/nested').create();
      },
    ]) {
      await output.create();
      await File('${output.path}/prior.txt').writeAsString('prior');
      await expectLater(
        runSeoRuntimePlanTransaction<void>(
          output: output,
          expectedFiles: expected,
          check: false,
          build: build,
        ),
        throwsStateError,
      );
      expect(await _fileNames(output), ['prior.txt']);
      await output.delete(recursive: true);
    }
  });

  test('an output replaced by a symlink during build is never followed',
      () async {
    for (final check in [false, true]) {
      output = Directory('${root.path}/runtimes-$check');
      await writeArtifactSet(output, javascript: 'prior');
      final target = Directory('${root.path}/foreign-$check');
      await writeArtifactSet(target, javascript: 'foreign');

      await expectLater(
        runSeoRuntimePlanTransaction<void>(
          output: output,
          expectedFiles: expected,
          check: check,
          build: (staging) async {
            await writeArtifactSet(staging);
            await output.delete(recursive: true);
            await Link(output.path).create(target.path);
          },
        ),
        throwsStateError,
      );

      expect(
        await FileSystemEntity.type(output.path, followLinks: false),
        FileSystemEntityType.link,
      );
      expect(
          await File('${target.path}/tabs-demo.js').readAsString(), 'foreign');
      expect(await _temporarySiblings(output), isEmpty);
      await Link(output.path).delete();
    }
  });
}

Future<List<String>> _fileNames(Directory directory) async {
  final names = await directory
      .list()
      .map((entry) => entry.path.split(Platform.pathSeparator).last)
      .toList();
  return names..sort();
}

Future<List<String>> _temporarySiblings(Directory output) async => output.parent
    .list()
    .where((entry) =>
        entry.path.startsWith('${output.path}.staging.') ||
        entry.path.startsWith('${output.path}.backup.'))
    .map((entry) => entry.path)
    .toList();

Future<Map<String, List<int>>> _snapshot(Directory directory) async {
  final snapshot = <String, List<int>>{};
  for (final name in await _fileNames(directory)) {
    snapshot[name] = await File('${directory.path}/$name').readAsBytes();
  }
  return snapshot;
}
