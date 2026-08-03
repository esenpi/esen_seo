// Proves that the libraries advertised as pure Dart really are —
// including everything they import, transitively.
//
// This replaces a hand-written list of files in the CI workflow. That
// list had already fallen behind: seo_resolved_page.dart and
// seo_resolution.dart are exported by core.dart and were never in it,
// and the audit added five more. Worse, a flat list can only see the
// files named in it, so a Flutter import reached indirectly — a pure
// file importing a pure file that imports material.dart — was
// invisible to it.
//
// Walking the import graph is self-maintaining: add a file to core.dart
// and it is covered the moment it is reachable.
//
//   dart run tool/check_pure_dart.dart
import 'dart:io';

/// The libraries that must never reach Flutter. Everything they import
/// is checked with them.
const _roots = [
  'lib/core.dart',
  'lib/server.dart',
  'lib/audit.dart',
];

/// Imports that disqualify a file from being pure Dart.
final RegExp _forbidden =
    RegExp(r'''^\s*(import|export)\s+['"](package:flutter/|dart:ui)''');

final RegExp _directive =
    RegExp(r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''', multiLine: true);

/// The `if (dart.library.x) 'other.dart'` branch of a conditional
/// import — a second target the directive regex above never matches.
final RegExp _conditional = RegExp(r'''if\s*\([^)]*\)\s*['"]([^'"]+)['"]''');

void main() {
  final visited = <String>{};
  final failures = <String, List<String>>{};

  // Refuse to report success from the wrong directory or with a root
  // renamed away. Both used to print a cheerful "no Flutter imports"
  // over a graph that was missing entirely.
  final missing = _roots.where((r) => !File(r).existsSync()).toList();
  if (missing.isNotEmpty) {
    stderr.writeln(
      'Cannot check purity: ${missing.join(", ")} not found. Run this from '
      'the package root (cwd is ${Directory.current.path}); if a library '
      'was renamed, update _roots in this file.',
    );
    exit(2);
  }

  for (final root in _roots) {
    _walk(root, visited, failures, [root]);
  }

  if (failures.isEmpty) {
    stdout.writeln(
      'pure Dart: ${visited.length} files reachable from '
      '${_roots.join(", ")} — no Flutter imports.',
    );
    return;
  }

  stderr.writeln('A library advertised as pure Dart reaches Flutter:\n');
  failures.forEach((file, chain) {
    stderr.writeln('  $file');
    stderr.writeln('    via ${chain.join(" → ")}');
  });
  stderr.writeln(
    '\nThese libraries must run under a plain Dart SDK, without the '
    'Flutter one. Move the Flutter-dependent part behind a separate '
    'entry point (see lib/testing.dart).',
  );
  exit(1);
}

void _walk(
  String path,
  Set<String> visited,
  Map<String, List<String>> failures,
  List<String> chain,
) {
  final normalized = _normalize(path);
  if (!visited.add(normalized)) return;

  final file = File(normalized);
  if (!file.existsSync()) return;
  final source = file.readAsStringSync();

  for (final line in source.split('\n')) {
    if (_forbidden.hasMatch(line)) {
      failures[normalized] = chain;
      break;
    }
  }

  for (final match in _directive.allMatches(source)) {
    final target = match.group(1)!;
    if (target.startsWith('dart:')) continue;

    // A self-import reaches straight back into the Flutter half:
    // `package:esen_seo/esen_seo.dart` exports the controller, which
    // imports Flutter. Skipping every `package:` URI let that through
    // as a clean pass.
    if (target.startsWith('package:esen_seo/')) {
      final asPath = 'lib/${target.substring('package:esen_seo/'.length)}';
      _walk(asPath, visited, failures, [...chain, target]);
      continue;
    }
    if (target.startsWith('package:')) continue;

    final resolved = _resolve(normalized, target);
    _walk(resolved, visited, failures, [...chain, target]);
  }

  // Conditional imports name a second file that the plain directive
  // regex never sees — and a Flutter import hidden in that branch
  // passed CI green.
  for (final match in _conditional.allMatches(source)) {
    final target = match.group(1)!;
    if (target.startsWith('dart:')) continue;
    if (target.startsWith('package:esen_seo/')) {
      final asPath = 'lib/${target.substring('package:esen_seo/'.length)}';
      _walk(asPath, visited, failures, [...chain, '$target (conditional)']);
      continue;
    }
    if (target.startsWith('package:')) continue;
    _walk(
      _resolve(normalized, target),
      visited,
      failures,
      [...chain, '$target (conditional)'],
    );
  }
}

/// Resolves a relative import against the importing file's directory.
String _resolve(String from, String relative) {
  final dir =
      from.contains('/') ? from.substring(0, from.lastIndexOf('/')) : '.';
  final parts = <String>[...dir.split('/'), ...relative.split('/')];
  final stack = <String>[];
  for (final part in parts) {
    if (part == '.' || part.isEmpty) continue;
    if (part == '..') {
      if (stack.isNotEmpty) stack.removeLast();
      continue;
    }
    stack.add(part);
  }
  return stack.join('/');
}

String _normalize(String path) =>
    path.startsWith('./') ? path.substring(2) : path;
