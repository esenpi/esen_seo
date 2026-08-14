import 'dart:convert';
import 'dart:io';

import 'package:esen_seo/server.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const reference = SeoDomFirstApplicationRuntime.tabs('application-tabs');
  const stepperReference =
      SeoDomFirstApplicationRuntime.stepper('application-tabs');
  const javascript = '(function(){var value=1;return value;})();';
  final dartVersion = Platform.version.split(' ').first;

  group('application runtime artifact', () {
    test('records and verifies its complete compiler identity', () {
      final artifact = SeoDomFirstRuntimeArtifact.create(
        reference: reference,
        javascript: javascript,
        dartVersion: dartVersion,
      );

      expect(artifact.manifest.schemaVersion, 1);
      expect(artifact.manifest.id, 'application-tabs');
      expect(artifact.manifest.kind, 'tabs');
      expect(artifact.manifest.dartVersion, dartVersion);
      expect(artifact.manifest.sha256, hasLength(64));
      expect(artifact.manifest.bytes, utf8.encode(javascript).length);
      expect(artifact.manifest.gzipBytes, greaterThan(0));
    });

    for (final forbidden in const [
      '</ScRiPt>',
      '<!--',
      'eval("code")',
      'new Function("return 1")',
      'Function("return 1")',
    ]) {
      test('rejects forbidden compiler output: $forbidden', () {
        expect(
          () => SeoDomFirstRuntimeArtifact.create(
            reference: reference,
            javascript: forbidden,
            dartVersion: dartVersion,
          ),
          throwsStateError,
        );
      });
    }

    test('rejects highly compressible output above the raw byte ceiling', () {
      final oversized = List.filled(
        seoDomFirstRuntimeMaxBytes + 1,
        'a',
      ).join();

      expect(
        () => SeoDomFirstRuntimeArtifact.create(
          reference: reference,
          javascript: oversized,
          dartVersion: dartVersion,
        ),
        throwsStateError,
      );
    });
  });

  group('directory runtime store', () {
    late Directory directory;
    late SeoDomFirstRuntimeArtifact artifact;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('esen_runtime_store');
      artifact = SeoDomFirstRuntimeArtifact.create(
        reference: reference,
        javascript: javascript,
        dartVersion: dartVersion,
      );
      await _write(directory, artifact);
    });

    tearDown(() => directory.delete(recursive: true));

    test('loads matching JavaScript and manifest', () async {
      final store = SeoDirectoryRuntimeStore(directory.path);
      final loaded = await store.load(reference);

      expect(loaded.reference, reference);
      expect(loaded.javascript, javascript);
      expect(loaded.manifest.sha256, artifact.manifest.sha256);

      await _javascriptFile(directory, reference).delete();
      expect(await store.load(reference), same(loaded));
    });

    test('keeps equal ids of different runtime kinds independent', () async {
      const stepperJavascript = '(function(){var step=2;return step;})();';
      final stepperArtifact = SeoDomFirstRuntimeArtifact.create(
        reference: stepperReference,
        javascript: stepperJavascript,
        dartVersion: dartVersion,
      );
      await _write(directory, stepperArtifact);

      final store = SeoDirectoryRuntimeStore(directory.path);
      expect((await store.load(reference)).javascript, javascript);
      expect(
        (await store.load(stepperReference)).javascript,
        stepperJavascript,
      );
      expect(await _javascriptFile(directory, reference).exists(), isTrue);
      expect(
        await _javascriptFile(directory, stepperReference).exists(),
        isTrue,
      );
    });

    test('bounds runtime files before reading or compressing them', () async {
      await _javascriptFile(directory, reference).writeAsString(
        List.filled(seoDomFirstRuntimeMaxBytes + 1, ' ').join(),
      );

      await expectLater(
        SeoDirectoryRuntimeStore(directory.path).load(reference),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('exceeds'),
          ),
        ),
      );
    });

    test('bounds the manifest before parsing it', () async {
      await _manifestFile(directory, reference).writeAsString(
        List.filled(8 * 1024 + 1, ' ').join(),
      );

      await expectLater(
        SeoDirectoryRuntimeStore(directory.path).load(reference),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('exceeds'),
          ),
        ),
      );
    });

    test('evicts a failed load so a completed deployment can recover',
        () async {
      final store = SeoDirectoryRuntimeStore(directory.path);
      await _javascriptFile(directory, reference).delete();

      await expectLater(store.load(reference), throwsStateError);
      await _write(directory, artifact);

      expect((await store.load(reference)).javascript, javascript);
    });

    test('rejects tampered JavaScript', () async {
      await _javascriptFile(directory, reference)
          .writeAsString('$javascript// changed');

      await expectLater(
        SeoDirectoryRuntimeStore(directory.path).load(reference),
        throwsStateError,
      );
    });

    test('rejects stale and foreign manifest identity', () async {
      final json = artifact.manifest.toJson()..['id'] = 'other-tabs';
      await _manifestFile(directory, reference).writeAsString(jsonEncode(json));

      await expectLater(
        SeoDirectoryRuntimeStore(directory.path).load(reference),
        throwsStateError,
      );
    });

    test('rejects artifacts built by another Dart compiler', () async {
      await expectLater(
        SeoDirectoryRuntimeStore(
          directory.path,
          expectedDartVersion: '0.0.0-test',
        ).load(reference),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            allOf(contains(dartVersion), contains('0.0.0-test')),
          ),
        ),
      );
    });

    test('rejects missing and unknown manifest fields', () async {
      final json = artifact.manifest.toJson()
        ..remove('sha256')
        ..['unexpected'] = true;
      await _manifestFile(directory, reference).writeAsString(jsonEncode(json));

      await expectLater(
        SeoDirectoryRuntimeStore(directory.path).load(reference),
        throwsStateError,
      );
    });

    test('names a missing artifact instead of falling back', () async {
      await _javascriptFile(directory, reference).delete();

      await expectLater(
        SeoDirectoryRuntimeStore(directory.path).load(reference),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('application-tabs'),
          ),
        ),
      );
    });
  });
}

Future<void> _write(
  Directory directory,
  SeoDomFirstRuntimeArtifact artifact,
) async {
  await _javascriptFile(directory, artifact.reference)
      .writeAsString(artifact.javascript);
  await _manifestFile(directory, artifact.reference)
      .writeAsString(jsonEncode(artifact.manifest.toJson()));
}

File _javascriptFile(
  Directory directory,
  SeoDomFirstApplicationRuntime reference,
) =>
    File(
      '${directory.path}/'
      '${_artifactStem(reference)}.js',
    );

File _manifestFile(
  Directory directory,
  SeoDomFirstApplicationRuntime reference,
) =>
    File(
      '${directory.path}/'
      '${_artifactStem(reference)}.json',
    );

String _artifactStem(SeoDomFirstApplicationRuntime reference) =>
    '${reference.kind}-${reference.id}';
