import 'dart:convert';
import 'dart:io';

import 'package:esen_seo/server.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const reference = SeoDomFirstApplicationRuntime.tabs('application-tabs');
  const stepperReference =
      SeoDomFirstApplicationRuntime.stepper('application-tabs');
  const stepperEffectsReference =
      SeoDomFirstApplicationRuntime.stepperEffects('application-tabs');
  const carouselReference =
      SeoDomFirstApplicationRuntime.carousel('application-tabs');
  final bundleReference = SeoDomFirstApplicationRuntime.bundle(
    'application-page',
    members: const {
      SeoDomFirstApplicationRuntimeKind.stepperEffects,
      SeoDomFirstApplicationRuntimeKind.tabs,
      SeoDomFirstApplicationRuntimeKind.collection,
    },
  );
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
      expect(artifact.manifest.toJson(), isNot(contains('members')));
    });

    test('bundle manifests bind canonical members in schema two', () {
      final artifact = SeoDomFirstRuntimeArtifact.create(
        reference: bundleReference,
        javascript: javascript,
        dartVersion: dartVersion,
      );

      expect(artifact.manifest.schemaVersion, 2);
      expect(artifact.manifest.kind, 'bundle');
      expect(
        artifact.manifest.memberKinds,
        ['tabs', 'collection', 'stepper-effects'],
      );
      expect(
        artifact.manifest.toJson()['members'],
        ['tabs', 'collection', 'stepper-effects'],
      );
    });

    test('verification snapshots bundle members supplied by its caller', () {
      final members = <String>['tabs', 'collection'];
      final source = SeoDomFirstRuntimeArtifact.create(
        reference: SeoDomFirstApplicationRuntime.bundle(
          'application-page',
          members: const {
            SeoDomFirstApplicationRuntimeKind.tabs,
            SeoDomFirstApplicationRuntimeKind.collection,
          },
        ),
        javascript: javascript,
        dartVersion: dartVersion,
      );
      final manifest = SeoDomFirstRuntimeManifest(
        schemaVersion: seoDomFirstRuntimeBundleManifestSchema,
        id: 'application-page',
        kind: 'bundle',
        dartVersion: dartVersion,
        sha256: source.manifest.sha256,
        bytes: source.manifest.bytes,
        gzipBytes: source.manifest.gzipBytes,
        memberKinds: members,
      );
      final verified = SeoDomFirstRuntimeArtifact.verify(
        reference: source.reference,
        manifest: manifest,
        javascript: javascript,
      );
      members
        ..clear()
        ..add('carousel');

      expect(verified.manifest.memberKinds, ['tabs', 'collection']);
      expect(
        () => verified.manifest.memberKinds.add('stepper'),
        throwsUnsupportedError,
      );
    });

    test('bundle verification rejects missing or reordered members', () {
      final artifact = SeoDomFirstRuntimeArtifact.create(
        reference: bundleReference,
        javascript: javascript,
        dartVersion: dartVersion,
      );
      for (final members in const <List<String>>[
        ['tabs', 'collection'],
        ['collection', 'tabs', 'stepper-effects'],
        ['tabs', 'collection', 'unknown'],
      ]) {
        final manifest = SeoDomFirstRuntimeManifest.fromJson({
          ...artifact.manifest.toJson(),
          'members': members,
        });
        expect(
          () => SeoDomFirstRuntimeArtifact.verify(
            reference: bundleReference,
            manifest: manifest,
            javascript: javascript,
          ),
          throwsStateError,
        );
      }
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
      const carouselJavascript = '(function(){var slide=3;return slide;})();';
      const stepperEffectsJavascript =
          '(function(){var effect=4;return effect;})();';
      final stepperArtifact = SeoDomFirstRuntimeArtifact.create(
        reference: stepperReference,
        javascript: stepperJavascript,
        dartVersion: dartVersion,
      );
      await _write(directory, stepperArtifact);
      final stepperEffectsArtifact = SeoDomFirstRuntimeArtifact.create(
        reference: stepperEffectsReference,
        javascript: stepperEffectsJavascript,
        dartVersion: dartVersion,
      );
      await _write(directory, stepperEffectsArtifact);
      final carouselArtifact = SeoDomFirstRuntimeArtifact.create(
        reference: carouselReference,
        javascript: carouselJavascript,
        dartVersion: dartVersion,
      );
      await _write(directory, carouselArtifact);
      final bundleArtifact = SeoDomFirstRuntimeArtifact.create(
        reference: bundleReference,
        javascript: '(function(){var bundle=5;return bundle;})();',
        dartVersion: dartVersion,
      );
      await _write(directory, bundleArtifact);

      final store = SeoDirectoryRuntimeStore(directory.path);
      expect((await store.load(reference)).javascript, javascript);
      expect(
        (await store.load(stepperReference)).javascript,
        stepperJavascript,
      );
      expect(
        (await store.load(carouselReference)).javascript,
        carouselJavascript,
      );
      expect(
        (await store.load(stepperEffectsReference)).javascript,
        stepperEffectsJavascript,
      );
      expect(
        (await store.load(bundleReference)).reference,
        bundleReference,
      );
      expect(await _javascriptFile(directory, reference).exists(), isTrue);
      expect(
        await _javascriptFile(directory, stepperReference).exists(),
        isTrue,
      );
      expect(
        await _javascriptFile(directory, carouselReference).exists(),
        isTrue,
      );
      expect(
        await _javascriptFile(directory, stepperEffectsReference).exists(),
        isTrue,
      );
      expect(
          await _javascriptFile(directory, bundleReference).exists(), isTrue);
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
