import 'dart:convert';
import 'dart:io';

import 'package:esen_seo/server.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const reference = SeoDomFirstApplicationRuntime.tabs('application-tabs');
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
      final loaded = await SeoDirectoryRuntimeStore(directory.path).load(
        reference,
      );

      expect(loaded.reference, reference);
      expect(loaded.javascript, javascript);
      expect(loaded.manifest.sha256, artifact.manifest.sha256);
    });

    test('rejects tampered JavaScript', () async {
      await File('${directory.path}/application-tabs.js')
          .writeAsString('$javascript// changed');

      await expectLater(
        SeoDirectoryRuntimeStore(directory.path).load(reference),
        throwsStateError,
      );
    });

    test('rejects stale and foreign manifest identity', () async {
      final json = artifact.manifest.toJson()..['id'] = 'other-tabs';
      await File('${directory.path}/application-tabs.json')
          .writeAsString(jsonEncode(json));

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
      await File('${directory.path}/application-tabs.json')
          .writeAsString(jsonEncode(json));

      await expectLater(
        SeoDirectoryRuntimeStore(directory.path).load(reference),
        throwsStateError,
      );
    });

    test('names a missing artifact instead of falling back', () async {
      await File('${directory.path}/application-tabs.js').delete();

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
  await File('${directory.path}/${artifact.reference.id}.js')
      .writeAsString(artifact.javascript);
  await File('${directory.path}/${artifact.reference.id}.json')
      .writeAsString(jsonEncode(artifact.manifest.toJson()));
}
