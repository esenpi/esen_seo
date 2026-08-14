import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import '../routing/seo_application_runtime.dart';
import '../routing/seo_application_runtime_artifact.dart';

/// Current on-disk format of an application DOM-first runtime manifest.
const int seoDomFirstRuntimeManifestSchema = 1;

/// Maximum accepted application runtime size after level-9 gzip compression.
const int seoDomFirstRuntimeMaxGzipBytes = 25 * 1024;

/// Maximum accepted application runtime size before compression.
///
/// The separate ceiling bounds file reads, hashing, compression and browser
/// parse work even when highly repetitive JavaScript compresses unusually
/// well.
const int seoDomFirstRuntimeMaxBytes = 512 * 1024;

const int _seoDomFirstRuntimeMaxManifestBytes = 8 * 1024;

/// Describes one compiled and content-addressed application runtime.
final class SeoDomFirstRuntimeManifest {
  const SeoDomFirstRuntimeManifest({
    required this.schemaVersion,
    required this.id,
    required this.kind,
    required this.dartVersion,
    required this.sha256,
    required this.bytes,
    required this.gzipBytes,
  });

  final int schemaVersion;
  final String id;
  final String kind;
  final String dartVersion;
  final String sha256;
  final int bytes;
  final int gzipBytes;

  Map<String, Object> toJson() => {
        'schemaVersion': schemaVersion,
        'id': id,
        'kind': kind,
        'dartVersion': dartVersion,
        'sha256': sha256,
        'bytes': bytes,
        'gzipBytes': gzipBytes,
      };

  factory SeoDomFirstRuntimeManifest.fromJson(Object? value) {
    if (value is! Map<String, Object?>) {
      throw const FormatException('Runtime manifest must be a JSON object.');
    }
    const fields = {
      'schemaVersion',
      'id',
      'kind',
      'dartVersion',
      'sha256',
      'bytes',
      'gzipBytes',
    };
    if (value.keys.toSet().difference(fields).isNotEmpty ||
        fields.difference(value.keys.toSet()).isNotEmpty) {
      throw const FormatException(
        'Runtime manifest has missing or unknown fields.',
      );
    }
    final schemaVersion = value['schemaVersion'];
    final id = value['id'];
    final kind = value['kind'];
    final dartVersion = value['dartVersion'];
    final hash = value['sha256'];
    final bytes = value['bytes'];
    final gzipBytes = value['gzipBytes'];
    if (schemaVersion is! int ||
        id is! String ||
        kind is! String ||
        dartVersion is! String ||
        hash is! String ||
        bytes is! int ||
        gzipBytes is! int) {
      throw const FormatException('Runtime manifest has invalid field types.');
    }
    return SeoDomFirstRuntimeManifest(
      schemaVersion: schemaVersion,
      id: id,
      kind: kind,
      dartVersion: dartVersion,
      sha256: hash,
      bytes: bytes,
      gzipBytes: gzipBytes,
    );
  }
}

/// JavaScript that passed manifest, identity, size, and content verification.
final class SeoDomFirstRuntimeArtifact {
  const SeoDomFirstRuntimeArtifact._({
    required this.reference,
    required this.manifest,
    required this.javascript,
  });

  final SeoDomFirstApplicationRuntime reference;
  final SeoDomFirstRuntimeManifest manifest;
  final String javascript;

  /// Creates and verifies an artifact from compiler output.
  factory SeoDomFirstRuntimeArtifact.create({
    required SeoDomFirstApplicationRuntime reference,
    required String javascript,
    required String dartVersion,
  }) {
    final encoded = utf8.encode(javascript);
    if (encoded.isEmpty || encoded.length > seoDomFirstRuntimeMaxBytes) {
      throw StateError(
        'Runtime "${reference.id}" exceeds its uncompressed size budget.',
      );
    }
    final manifest = SeoDomFirstRuntimeManifest(
      schemaVersion: seoDomFirstRuntimeManifestSchema,
      id: reference.id,
      kind: reference.kind,
      dartVersion: dartVersion,
      sha256: sha256.convert(encoded).toString(),
      bytes: encoded.length,
      gzipBytes: GZipCodec(level: 9).encode(encoded).length,
    );
    return SeoDomFirstRuntimeArtifact.verify(
      reference: reference,
      manifest: manifest,
      javascript: javascript,
    );
  }

  /// Verifies identity and file consistency for a build-owned artifact.
  ///
  /// The manifest hash detects stale, partial or accidentally changed files;
  /// it does not authenticate a coordinated replacement of both files. The
  /// build directory remains trusted deployment input.
  factory SeoDomFirstRuntimeArtifact.verify({
    required SeoDomFirstApplicationRuntime reference,
    required SeoDomFirstRuntimeManifest manifest,
    required String javascript,
  }) {
    if (!isValidSeoApplicationRuntimeId(reference.id)) {
      throw StateError('Invalid application runtime id "${reference.id}".');
    }
    if (manifest.schemaVersion != seoDomFirstRuntimeManifestSchema) {
      throw StateError(
        'Unsupported runtime manifest schema ${manifest.schemaVersion} '
        'for "${reference.id}".',
      );
    }
    if (manifest.id != reference.id || manifest.kind != reference.kind) {
      throw StateError(
        'Runtime manifest identity does not match "${reference.id}" '
        '(${reference.kind}).',
      );
    }
    if (manifest.dartVersion.isEmpty ||
        manifest.dartVersion.length > 64 ||
        manifest.dartVersion.runes.any(_isControlCodePoint)) {
      throw StateError('Invalid Dart version in runtime "${reference.id}".');
    }
    if (!_sha256.hasMatch(manifest.sha256)) {
      throw StateError('Invalid SHA-256 in runtime "${reference.id}".');
    }
    if (manifest.bytes < 1 ||
        manifest.bytes > seoDomFirstRuntimeMaxBytes ||
        manifest.gzipBytes < 1 ||
        manifest.gzipBytes > seoDomFirstRuntimeMaxGzipBytes) {
      throw StateError('Runtime "${reference.id}" exceeds its size budget.');
    }
    final encoded = utf8.encode(javascript);
    if (encoded.length > seoDomFirstRuntimeMaxBytes) {
      throw StateError(
        'Runtime "${reference.id}" exceeds its uncompressed size budget.',
      );
    }
    final actualHash = sha256.convert(encoded).toString();
    final actualGzipBytes = GZipCodec(level: 9).encode(encoded).length;
    if (manifest.bytes != encoded.length ||
        manifest.gzipBytes != actualGzipBytes ||
        manifest.sha256 != actualHash) {
      throw StateError('Runtime "${reference.id}" failed integrity checks.');
    }
    final lower = javascript.toLowerCase();
    if (lower.contains('</script') ||
        javascript.contains('<!--') ||
        _eval.hasMatch(javascript) ||
        _functionConstructor.hasMatch(javascript)) {
      throw StateError('Runtime "${reference.id}" contains forbidden code.');
    }
    return SeoDomFirstRuntimeArtifact._(
      reference: reference,
      manifest: manifest,
      javascript: javascript,
    );
  }
}

/// Loads verified application runtimes for server and prerender delivery.
abstract interface class SeoDomFirstRuntimeStore {
  FutureOr<SeoDomFirstRuntimeArtifact> load(
    SeoDomFirstApplicationRuntime reference,
  );
}

/// Loads a runtime and rejects stores that return a different identity.
Future<SeoDomFirstRuntimeArtifact> loadSeoDomFirstRuntime(
  SeoDomFirstRuntimeStore store,
  SeoDomFirstApplicationRuntime reference,
) async {
  final artifact = await store.load(reference);
  if (artifact.reference != reference) {
    throw StateError(
      'Runtime store returned "${artifact.reference.id}" '
      '(${artifact.reference.kind}) for "${reference.id}" '
      '(${reference.kind}).',
    );
  }
  return artifact;
}

/// Loads `<kind>-<id>.json` and `<kind>-<id>.js` from a build-owned directory.
///
/// A successful verification is cached for this store's lifetime. Build
/// artifacts are immutable deployment inputs; create a new store after
/// rebuilding them. Failed loads are evicted so a temporarily incomplete
/// deployment can recover.
final class SeoDirectoryRuntimeStore implements SeoDomFirstRuntimeStore {
  SeoDirectoryRuntimeStore(
    this.directory, {
    String? expectedDartVersion,
  }) : expectedDartVersion =
            expectedDartVersion ?? Platform.version.split(' ').first;

  final String directory;
  final String expectedDartVersion;
  final Map<SeoDomFirstApplicationRuntime, Future<SeoDomFirstRuntimeArtifact>>
      _cache = {};

  @override
  Future<SeoDomFirstRuntimeArtifact> load(
    SeoDomFirstApplicationRuntime reference,
  ) async {
    if (!isValidSeoApplicationRuntimeId(reference.id)) {
      throw StateError('Invalid application runtime id "${reference.id}".');
    }
    final cached = _cache[reference];
    if (cached != null) return cached;
    final pending = _load(reference);
    _cache[reference] = pending;
    try {
      return await pending;
    } catch (_) {
      if (identical(_cache[reference], pending)) _cache.remove(reference);
      rethrow;
    }
  }

  Future<SeoDomFirstRuntimeArtifact> _load(
    SeoDomFirstApplicationRuntime reference,
  ) async {
    final stem = seoApplicationRuntimeArtifactStem(reference);
    final manifestFile = File('$directory/$stem.json');
    final javascriptFile = File('$directory/$stem.js');
    if (!await manifestFile.exists() || !await javascriptFile.exists()) {
      throw StateError(
        'Application runtime "${reference.id}" is missing from $directory.',
      );
    }
    try {
      final SeoDomFirstRuntimeManifest manifest;
      try {
        manifest = SeoDomFirstRuntimeManifest.fromJson(
          jsonDecode(await _readUtf8File(
            manifestFile,
            maxBytes: _seoDomFirstRuntimeMaxManifestBytes,
            description: 'Runtime manifest "${reference.id}"',
          )),
        );
      } on FormatException catch (error) {
        throw StateError(
          'Invalid manifest for application runtime "${reference.id}": '
          '${error.message}',
        );
      }
      if (manifest.dartVersion != expectedDartVersion) {
        throw StateError(
          'Application runtime "${reference.id}" was built with Dart '
          '${manifest.dartVersion}, expected $expectedDartVersion.',
        );
      }
      final javascript = await _readUtf8File(
        javascriptFile,
        maxBytes: seoDomFirstRuntimeMaxBytes,
        description: 'Application runtime "${reference.id}"',
      );
      return SeoDomFirstRuntimeArtifact.verify(
        reference: reference,
        manifest: manifest,
        javascript: javascript,
      );
    } on FileSystemException catch (error) {
      throw StateError(
        'Cannot read application runtime "${reference.id}": $error',
      );
    }
  }
}

Future<String> _readUtf8File(
  File file, {
  required int maxBytes,
  required String description,
}) async {
  final handle = await file.open();
  try {
    if (await handle.length() > maxBytes) {
      throw StateError('$description exceeds $maxBytes bytes.');
    }
    final bytes = await handle.read(maxBytes + 1);
    if (bytes.length > maxBytes) {
      throw StateError('$description exceeds $maxBytes bytes.');
    }
    try {
      return utf8.decode(bytes);
    } on FormatException catch (error) {
      throw StateError('$description is not valid UTF-8: ${error.message}');
    }
  } finally {
    await handle.close();
  }
}

bool _isControlCodePoint(int codePoint) =>
    codePoint < 0x20 || codePoint == 0x7f;

final RegExp _sha256 = RegExp(r'^[0-9a-f]{64}$');
final RegExp _eval = RegExp(r'\beval\s*\(');
final RegExp _functionConstructor = RegExp(r'\b(?:new\s+)?Function\s*\(');
