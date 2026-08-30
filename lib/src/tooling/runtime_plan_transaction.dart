import 'dart:io';

/// Builds a complete file set in staging and admits it as one transaction.
///
/// This internal filesystem boundary is separate from runtime compilation so
/// its failure and rollback behavior can be tested without invoking a compiler
/// from inside a Flutter test process.
Future<T> runSeoRuntimePlanTransaction<T>({
  required Directory output,
  required Set<String> expectedFiles,
  required bool check,
  required Future<T> Function(Directory staging) build,
}) async {
  final expected = Set<String>.unmodifiable(expectedFiles);
  await output.parent.create(recursive: true);
  final staging = await _freshSiblingDirectory(output, 'staging');
  try {
    await staging.create();
    final result = await build(staging);
    await _verifyExactDirectoryFiles(
      staging,
      expected,
      description: 'Staged runtime plan',
    );
    if (check) {
      if (await FileSystemEntity.type(output.path, followLinks: false) !=
          FileSystemEntityType.directory) {
        throw StateError(
          'Application runtime plan output changed during build.',
        );
      }
      await _verifyPlanOutput(output, staging, expected);
    } else {
      await _replacePlanOutput(output, staging);
    }
    return result;
  } finally {
    if (await staging.exists()) await staging.delete(recursive: true);
  }
}

Future<Directory> _freshSiblingDirectory(
  Directory output,
  String role,
) async {
  final nonce = '$pid.${DateTime.now().microsecondsSinceEpoch}';
  for (var attempt = 0; attempt < 100; attempt++) {
    final candidate = Directory('${output.path}.$role.$nonce.$attempt');
    if (await FileSystemEntity.type(
          candidate.path,
          followLinks: false,
        ) ==
        FileSystemEntityType.notFound) {
      return candidate;
    }
  }
  throw StateError('Cannot reserve a temporary runtime plan directory.');
}

Future<void> _verifyExactDirectoryFiles(
  Directory directory,
  Set<String> expected, {
  required String description,
}) async {
  if (!await directory.exists()) {
    throw StateError('$description directory is missing.');
  }
  final actual = <String>{};
  await for (final entity
      in directory.list(recursive: true, followLinks: false)) {
    final relative = entity.path.substring(directory.path.length + 1);
    final type = await FileSystemEntity.type(entity.path, followLinks: false);
    if (type != FileSystemEntityType.file) {
      throw StateError('$description contains unexpected entry "$relative".');
    }
    actual.add(relative.replaceAll(Platform.pathSeparator, '/'));
  }
  final missing = expected.difference(actual).toList()..sort();
  final additional = actual.difference(expected).toList()..sort();
  if (missing.isNotEmpty || additional.isNotEmpty) {
    throw StateError(
      '$description file set is stale; missing [${missing.join(', ')}], '
      'additional [${additional.join(', ')}].',
    );
  }
}

Future<void> _verifyPlanOutput(
  Directory output,
  Directory staging,
  Set<String> expected,
) async {
  await _verifyExactDirectoryFiles(
    output,
    expected,
    description: 'Application runtime plan output',
  );
  final names = expected.toList()..sort();
  for (final name in names) {
    final actual = await File('${output.path}/$name').readAsBytes();
    final staged = await File('${staging.path}/$name').readAsBytes();
    if (!_sameBytes(actual, staged)) {
      throw StateError(
        'Application runtime plan output "$name" is stale. Rebuild it '
        'without --check.',
      );
    }
  }
}

Future<void> _replacePlanOutput(
  Directory output,
  Directory staging,
) async {
  final existingType = await FileSystemEntity.type(
    output.path,
    followLinks: false,
  );
  if (existingType != FileSystemEntityType.notFound &&
      existingType != FileSystemEntityType.directory) {
    throw StateError('Application runtime plan output changed during build.');
  }
  final backup = await _freshSiblingDirectory(output, 'backup');
  var backedUp = false;
  var promoted = false;
  try {
    if (existingType == FileSystemEntityType.directory) {
      await output.rename(backup.path);
      backedUp = true;
    }
    if (await FileSystemEntity.type(output.path, followLinks: false) !=
        FileSystemEntityType.notFound) {
      throw StateError('Application runtime plan output changed during build.');
    }
    await staging.rename(output.path);
    promoted = true;
    if (backedUp) await backup.delete(recursive: true);
  } catch (error, stackTrace) {
    try {
      if (promoted && await output.exists()) {
        await output.delete(recursive: true);
      }
      if (backedUp && await backup.exists()) {
        await backup.rename(output.path);
      }
    } catch (rollbackError) {
      throw StateError(
        'Runtime plan replacement failed ($error) and rollback also failed '
        '($rollbackError).',
      );
    }
    Error.throwWithStackTrace(error, stackTrace);
  }
}

bool _sameBytes(List<int> left, List<int> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
