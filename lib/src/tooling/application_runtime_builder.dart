import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../routing/seo_application_runtime.dart';
import '../routing/seo_application_runtime_artifact.dart';
import '../server/seo_runtime_store.dart';

/// Inputs for one application-authored tabs runtime build.
final class SeoTabsRuntimeBuildRequest {
  const SeoTabsRuntimeBuildRequest({
    required this.id,
    required this.library,
    required this.symbol,
    this.outputDirectory = 'build/esen_seo/runtimes',
  });

  final String id;
  final String library;
  final String symbol;
  final String outputDirectory;
}

/// Inputs for one application-authored carousel runtime build.
final class SeoCarouselRuntimeBuildRequest {
  const SeoCarouselRuntimeBuildRequest({
    required this.id,
    required this.library,
    required this.symbol,
    this.outputDirectory = 'build/esen_seo/runtimes',
  });

  final String id;
  final String library;
  final String symbol;
  final String outputDirectory;
}

/// Inputs for one application-authored collection runtime build.
final class SeoCollectionRuntimeBuildRequest {
  const SeoCollectionRuntimeBuildRequest({
    required this.id,
    required this.library,
    required this.symbol,
    this.outputDirectory = 'build/esen_seo/runtimes',
  });

  final String id;
  final String library;
  final String symbol;
  final String outputDirectory;
}

/// Inputs for one application-authored stepper runtime build.
final class SeoStepperRuntimeBuildRequest {
  const SeoStepperRuntimeBuildRequest({
    required this.id,
    required this.library,
    required this.symbol,
    this.outputDirectory = 'build/esen_seo/runtimes',
  });

  final String id;
  final String library;
  final String symbol;
  final String outputDirectory;
}

/// Compiles one checked application transition and writes its verified files.
Future<SeoDomFirstRuntimeArtifact> buildSeoTabsApplicationRuntime(
  SeoTabsRuntimeBuildRequest request, {
  String? packageRoot,
  bool write = true,
}) =>
    _buildApplicationRuntime(
      _ApplicationRuntimeBuildRequest(
        reference: SeoDomFirstApplicationRuntime.tabs(request.id),
        library: request.library,
        symbol: request.symbol,
        outputDirectory: request.outputDirectory,
      ),
      packageRoot: packageRoot,
      write: write,
    );

/// Compiles one checked carousel transition and writes its verified files.
Future<SeoDomFirstRuntimeArtifact> buildSeoCarouselApplicationRuntime(
  SeoCarouselRuntimeBuildRequest request, {
  String? packageRoot,
  bool write = true,
}) =>
    _buildApplicationRuntime(
      _ApplicationRuntimeBuildRequest(
        reference: SeoDomFirstApplicationRuntime.carousel(request.id),
        library: request.library,
        symbol: request.symbol,
        outputDirectory: request.outputDirectory,
      ),
      packageRoot: packageRoot,
      write: write,
    );

/// Compiles one checked collection transition and writes its verified files.
Future<SeoDomFirstRuntimeArtifact> buildSeoCollectionApplicationRuntime(
  SeoCollectionRuntimeBuildRequest request, {
  String? packageRoot,
  bool write = true,
}) =>
    _buildApplicationRuntime(
      _ApplicationRuntimeBuildRequest(
        reference: SeoDomFirstApplicationRuntime.collection(request.id),
        library: request.library,
        symbol: request.symbol,
        outputDirectory: request.outputDirectory,
      ),
      packageRoot: packageRoot,
      write: write,
    );

/// Compiles one checked stepper transition and writes its verified files.
Future<SeoDomFirstRuntimeArtifact> buildSeoStepperApplicationRuntime(
  SeoStepperRuntimeBuildRequest request, {
  String? packageRoot,
  bool write = true,
}) =>
    _buildApplicationRuntime(
      _ApplicationRuntimeBuildRequest(
        reference: SeoDomFirstApplicationRuntime.stepper(request.id),
        library: request.library,
        symbol: request.symbol,
        outputDirectory: request.outputDirectory,
      ),
      packageRoot: packageRoot,
      write: write,
    );

final class _ApplicationRuntimeBuildRequest {
  const _ApplicationRuntimeBuildRequest({
    required this.reference,
    required this.library,
    required this.symbol,
    required this.outputDirectory,
  });

  final SeoDomFirstApplicationRuntime reference;
  final String library;
  final String symbol;
  final String outputDirectory;
}

Future<SeoDomFirstRuntimeArtifact> _buildApplicationRuntime(
  _ApplicationRuntimeBuildRequest request, {
  String? packageRoot,
  required bool write,
}) async {
  final root = Directory(packageRoot ?? Directory.current.path).absolute;
  final reference = request.reference;
  if (!isValidSeoApplicationRuntimeId(reference.id)) {
    throw ArgumentError.value(
      reference.id,
      'id',
      'must start with a lowercase letter and contain at most 64 lowercase '
          'letters, digits, underscores or dashes',
    );
  }
  if (!_dartIdentifier.hasMatch(request.symbol) ||
      _dartReservedWords.contains(request.symbol)) {
    throw ArgumentError.value(
      request.symbol,
      'symbol',
      'must be a valid non-reserved Dart identifier',
    );
  }
  final output = _checkedOutputDirectory(root, request.outputDirectory);

  final packageConfig = File('${root.path}/.dart_tool/package_config.json');
  if (!await packageConfig.exists()) {
    throw StateError(
      'Missing ${packageConfig.path}. Run dart pub get in ${root.path}.',
    );
  }
  final graph = await _PackageGraph.load(packageConfig, root);
  final libraryUri = Uri.tryParse(request.library);
  if (libraryUri == null ||
      libraryUri.scheme != 'package' ||
      libraryUri.hasQuery ||
      libraryUri.hasFragment) {
    throw ArgumentError.value(
      request.library,
      'library',
      'must be a package: URI below the application lib directory',
    );
  }
  final rootLibrary = graph.resolveApplicationLibrary(libraryUri);
  _PureApplicationGraph(graph).check(rootLibrary);

  final scratchRoot = Directory('${root.path}/.dart_tool');
  final scratch = await scratchRoot.createTemp('esen-seo-runtime-');
  try {
    final entrypoint = File('${scratch.path}/entrypoint.dart');
    final compiled = File('${scratch.path}/runtime.js');
    await entrypoint.writeAsString(switch (reference) {
      SeoDomFirstTabsApplicationRuntime() => _tabsEntrypointSource(
          libraryUri,
          request.symbol,
        ),
      SeoDomFirstCarouselApplicationRuntime() => _carouselEntrypointSource(
          libraryUri,
          request.symbol,
        ),
      SeoDomFirstCollectionApplicationRuntime() => _collectionEntrypointSource(
          libraryUri,
          request.symbol,
        ),
      SeoDomFirstStepperApplicationRuntime() => _stepperEntrypointSource(
          libraryUri,
          request.symbol,
        ),
    });

    final result = await Process.run(
      Platform.resolvedExecutable,
      [
        'compile',
        'js',
        '-O2',
        '--csp',
        '--no-source-maps',
        '--fatal-warnings',
        '-o',
        compiled.path,
        entrypoint.path,
      ],
      workingDirectory: root.path,
      runInShell: false,
    );
    if (result.exitCode != 0) {
      throw StateError(
        'Application ${reference.kind} runtime compilation failed.\n'
        '${result.stdout}${result.stderr}',
      );
    }

    final javascript = await compiled.readAsString();
    final artifact = SeoDomFirstRuntimeArtifact.create(
      reference: reference,
      javascript: javascript,
      dartVersion: Platform.version.split(' ').first,
    );
    if (write) {
      await _writeArtifact(output, artifact);
    } else {
      await _verifyCurrentArtifact(output, artifact);
    }
    return artifact;
  } finally {
    if (await scratch.exists()) await scratch.delete(recursive: true);
  }
}

String _tabsEntrypointSource(Uri library, String symbol) => '''
import 'package:esen_seo/src/components/seo_tabs_transition.dart';
import 'package:esen_seo/src/renderer/dom_first_tabs_adapter_web.dart';
import ${jsonEncode(library.toString())} as application;

SeoTabsState _applicationTransition(
  SeoTabsState state,
  SeoTabsAction action,
) => application.$symbol(state, action);

void main() => enhanceSeoDomFirstTabs(
  transition: _applicationTransition,
);
''';

String _carouselEntrypointSource(Uri library, String symbol) => '''
import 'package:esen_seo/src/components/seo_carousel_transition.dart';
import 'package:esen_seo/src/renderer/dom_first_carousel_adapter_web.dart';
import ${jsonEncode(library.toString())} as application;

SeoCarouselState _applicationTransition(
  SeoCarouselState state,
  SeoCarouselAction action,
) => application.$symbol(state, action);

void main() => enhanceSeoDomFirstCarousels(
  transition: _applicationTransition,
);
''';

String _collectionEntrypointSource(Uri library, String symbol) => '''
import 'package:esen_seo/src/renderer/dom_first_collection_adapter_web.dart';
import ${jsonEncode(library.toString())} as application;

void main() => enhanceSeoDomFirstCollections(
  transition: application.$symbol,
);
''';

String _stepperEntrypointSource(Uri library, String symbol) => '''
import 'package:esen_seo/src/components/seo_stepper_transition.dart';
import 'package:esen_seo/src/renderer/dom_first_stepper_adapter_web.dart';
import ${jsonEncode(library.toString())} as application;

SeoStepperState _applicationTransition(
  SeoStepperState state,
  SeoStepperAction action,
) => application.$symbol(state, action);

void main() => enhanceSeoDomFirstSteppers(
  transition: _applicationTransition,
);
''';

Directory _checkedOutputDirectory(Directory root, String relative) {
  final uri = Uri.tryParse(relative);
  if (uri == null ||
      uri.hasScheme ||
      uri.hasAuthority ||
      uri.hasQuery ||
      uri.hasFragment ||
      uri.pathSegments.isEmpty ||
      uri.pathSegments.first != 'build' ||
      uri.pathSegments.any(
        (segment) =>
            segment.isEmpty ||
            segment == '.' ||
            segment == '..' ||
            segment.contains('\\') ||
            segment.runes.any(_isControlCodePoint),
      )) {
    throw ArgumentError.value(
      relative,
      'outputDirectory',
      'must be a relative directory below build/',
    );
  }
  final output = Directory.fromUri(root.uri.resolveUri(uri));
  var existing = output;
  while (!existing.existsSync() && existing.path != existing.parent.path) {
    existing = existing.parent;
  }
  final rootPath = root.resolveSymbolicLinksSync();
  final existingPath = existing.resolveSymbolicLinksSync();
  if (!_isWithinDirectory(rootPath, existingPath)) {
    throw ArgumentError.value(
      relative,
      'outputDirectory',
      'resolves outside the application through a symbolic link',
    );
  }
  return output;
}

Future<void> _writeArtifact(
  Directory output,
  SeoDomFirstRuntimeArtifact artifact,
) async {
  await output.create(recursive: true);
  final stem = seoApplicationRuntimeArtifactStem(artifact.reference);
  final javascript = File('${output.path}/$stem.js');
  final manifest = File('${output.path}/$stem.json');
  final temporarySuffix = '.tmp.$pid.${DateTime.now().microsecondsSinceEpoch}';
  final temporaryJavascript = File('${javascript.path}$temporarySuffix');
  final temporaryManifest = File('${manifest.path}$temporarySuffix');
  try {
    await temporaryJavascript.writeAsString(artifact.javascript, flush: true);
    await temporaryManifest.writeAsString(
      '${const JsonEncoder.withIndent('  ').convert(artifact.manifest.toJson())}\n',
      flush: true,
    );
    if (await javascript.exists()) await javascript.delete();
    await temporaryJavascript.rename(javascript.path);
    if (await manifest.exists()) await manifest.delete();
    await temporaryManifest.rename(manifest.path);
  } finally {
    if (await temporaryJavascript.exists()) await temporaryJavascript.delete();
    if (await temporaryManifest.exists()) await temporaryManifest.delete();
  }
}

Future<void> _verifyCurrentArtifact(
  Directory output,
  SeoDomFirstRuntimeArtifact expected,
) async {
  final actual = await SeoDirectoryRuntimeStore(output.path).load(
    expected.reference,
  );
  if (actual.javascript != expected.javascript ||
      actual.manifest.sha256 != expected.manifest.sha256 ||
      actual.manifest.dartVersion != expected.manifest.dartVersion ||
      actual.manifest.bytes != expected.manifest.bytes ||
      actual.manifest.gzipBytes != expected.manifest.gzipBytes) {
    throw StateError(
      'Application runtime "${expected.reference.id}" is stale. Rebuild it '
      'without --check.',
    );
  }
}

final class _PackageGraph {
  _PackageGraph({
    required this.applicationLib,
    required this.applicationPackage,
    required this.packages,
  });

  final Directory applicationLib;
  final String applicationPackage;
  final Map<String, Uri> packages;

  static Future<_PackageGraph> load(
    File packageConfig,
    Directory applicationRoot,
  ) async {
    final decoded = jsonDecode(await packageConfig.readAsString());
    if (decoded is! Map<String, Object?> || decoded['packages'] is! List) {
      throw StateError('Invalid package config at ${packageConfig.path}.');
    }
    final packages = <String, Uri>{};
    for (final raw in decoded['packages']! as List) {
      if (raw is! Map<String, Object?> ||
          raw['name'] is! String ||
          raw['rootUri'] is! String) {
        throw StateError('Invalid package entry in ${packageConfig.path}.');
      }
      final name = raw['name']! as String;
      final rootUri = packageConfig.uri.resolve(raw['rootUri']! as String);
      final packageUri = raw['packageUri'] is String
          ? Uri.parse(raw['packageUri']! as String)
          : Uri.parse('lib/');
      if (packages.containsKey(name)) {
        throw StateError('Duplicate package "$name" in package config.');
      }
      packages[name] = rootUri.resolveUri(packageUri);
    }

    final rootPath = await applicationRoot.resolveSymbolicLinks();
    String? applicationPackage;
    Uri? applicationLibUri;
    for (final entry in packages.entries) {
      final lib = Directory.fromUri(entry.value);
      if (!await lib.exists()) continue;
      final packageRoot = lib.parent;
      if (await packageRoot.resolveSymbolicLinks() == rootPath) {
        applicationPackage = entry.key;
        applicationLibUri = entry.value;
        break;
      }
    }
    if (applicationPackage == null || applicationLibUri == null) {
      throw StateError(
        'The current package is missing from ${packageConfig.path}.',
      );
    }
    return _PackageGraph(
      applicationLib: Directory.fromUri(applicationLibUri),
      applicationPackage: applicationPackage,
      packages: Map.unmodifiable(packages),
    );
  }

  File resolveApplicationLibrary(Uri uri) {
    final segments = uri.pathSegments;
    if (segments.length < 2 || segments.first != applicationPackage) {
      throw ArgumentError.value(
        uri,
        'library',
        'must belong to the current application package '
            '"$applicationPackage"',
      );
    }
    final file = _resolvePackageUri(uri);
    if (!file.path.endsWith('.dart') || !file.existsSync()) {
      throw ArgumentError.value(uri, 'library', 'does not name a Dart file');
    }
    _requireInsideApplicationLib(file);
    return file;
  }

  File resolveDependency(File from, String rawUri) {
    final uri = Uri.parse(rawUri);
    if (uri.scheme == 'package') {
      final segments = uri.pathSegments;
      if (segments.isEmpty) {
        throw StateError('Empty package URI imported by ${from.path}.');
      }
      if (segments.first == 'esen_seo' &&
          (rawUri == 'package:esen_seo/core.dart' ||
              rawUri ==
                  'package:esen_seo/src/components/seo_tabs_transition.dart' ||
              rawUri ==
                  'package:esen_seo/src/components/seo_carousel_transition.dart' ||
              rawUri ==
                  'package:esen_seo/src/components/seo_collection_transition.dart' ||
              rawUri ==
                  'package:esen_seo/src/components/seo_stepper_transition.dart')) {
        return File('');
      }
      if (segments.first != applicationPackage) {
        throw StateError(
          'Forbidden package import "$rawUri" in ${from.path}.',
        );
      }
      final file = _resolvePackageUri(uri);
      if (!file.existsSync()) {
        throw StateError('Missing Dart dependency "$rawUri" in ${from.path}.');
      }
      _requireInsideApplicationLib(file);
      return file;
    }
    if (uri.hasScheme) {
      throw StateError('Forbidden import "$rawUri" in ${from.path}.');
    }
    final file = File.fromUri(from.parent.uri.resolveUri(uri));
    if (!file.existsSync()) {
      throw StateError('Missing Dart dependency "$rawUri" in ${from.path}.');
    }
    _requireInsideApplicationLib(file);
    return file;
  }

  File _resolvePackageUri(Uri uri) {
    final segments = uri.pathSegments;
    final base = packages[segments.first];
    if (base == null) throw StateError('Unknown package "${segments.first}".');
    return File.fromUri(base.resolve(segments.skip(1).join('/')));
  }

  void _requireInsideApplicationLib(File file) {
    final lexicalLibPath = applicationLib.absolute.path;
    final absolutePath = file.absolute.path;
    if (!_isWithinDirectory(lexicalLibPath, absolutePath)) {
      throw StateError('${file.path} escapes the application lib directory.');
    }
    final libPath = applicationLib.resolveSymbolicLinksSync();
    final filePath = file.resolveSymbolicLinksSync();
    if (!_isWithinDirectory(libPath, filePath)) {
      throw StateError('${file.path} escapes the application lib directory.');
    }
  }
}

final class _PureApplicationGraph {
  _PureApplicationGraph(this.graph);

  final _PackageGraph graph;
  final Set<String> _visited = {};

  void check(File root) => _walk(root);

  void _walk(File file) {
    final path = file.resolveSymbolicLinksSync();
    if (!_visited.add(path)) return;
    final result = parseString(
      content: file.readAsStringSync(),
      path: path,
      throwIfDiagnostics: false,
    );
    if (result.errors.isNotEmpty) {
      final diagnostics =
          result.errors.map((error) => error.message).join('; ');
      throw StateError('Cannot parse $path: $diagnostics');
    }
    result.unit.accept(_NoHeldStateVisitor(path));

    for (final directive in result.unit.directives) {
      if (directive is ImportDirective && directive.deferredKeyword != null) {
        throw StateError('Deferred import is forbidden in $path.');
      }
      if (directive is NamespaceDirective &&
          directive.configurations.isNotEmpty) {
        throw StateError('Conditional import or export is forbidden in $path.');
      }
      if (directive is! ImportDirective &&
          directive is! ExportDirective &&
          directive is! PartDirective) {
        continue;
      }
      final rawUri = (directive as UriBasedDirective).uri.stringValue;
      if (rawUri == null) {
        throw StateError('Non-literal directive URI is forbidden in $path.');
      }
      if (rawUri.startsWith('dart:')) {
        if (!_allowedDartLibraries.contains(rawUri)) {
          throw StateError('Forbidden Dart library "$rawUri" in $path.');
        }
        continue;
      }
      final dependency = graph.resolveDependency(file, rawUri);
      if (dependency.path.isEmpty) continue;
      if (!dependency.existsSync() || !dependency.path.endsWith('.dart')) {
        throw StateError('Missing Dart dependency "$rawUri" in $path.');
      }
      _walk(dependency);
    }
  }
}

final class _NoHeldStateVisitor extends RecursiveAstVisitor<void> {
  _NoHeldStateVisitor(this.path);

  final String path;

  @override
  void visitTopLevelVariableDeclaration(TopLevelVariableDeclaration node) {
    if (!node.variables.isConst) {
      throw StateError(
        'Application transition graph holds non-const top-level state in '
        '$path.',
      );
    }
    super.visitTopLevelVariableDeclaration(node);
  }

  @override
  void visitFieldDeclaration(FieldDeclaration node) {
    if (node.isStatic && !node.fields.isConst) {
      throw StateError(
        'Application transition graph holds non-const static state in $path.',
      );
    }
    super.visitFieldDeclaration(node);
  }
}

const Set<String> _allowedDartLibraries = {'dart:core', 'dart:collection'};

final RegExp _dartIdentifier = RegExp(r'^[a-zA-Z][a-zA-Z0-9_]*$');

const Set<String> _dartReservedWords = {
  'abstract',
  'as',
  'assert',
  'async',
  'await',
  'base',
  'break',
  'case',
  'catch',
  'class',
  'const',
  'continue',
  'covariant',
  'default',
  'deferred',
  'do',
  'dynamic',
  'else',
  'enum',
  'export',
  'extends',
  'extension',
  'external',
  'factory',
  'false',
  'final',
  'finally',
  'for',
  'Function',
  'get',
  'hide',
  'if',
  'implements',
  'import',
  'in',
  'interface',
  'is',
  'late',
  'library',
  'mixin',
  'new',
  'null',
  'of',
  'on',
  'operator',
  'part',
  'required',
  'rethrow',
  'return',
  'sealed',
  'set',
  'show',
  'static',
  'super',
  'switch',
  'sync',
  'this',
  'throw',
  'true',
  'try',
  'var',
  'void',
  'when',
  'while',
  'with',
  'yield',
};

bool _isControlCodePoint(int codePoint) =>
    codePoint < 0x20 || codePoint == 0x7f;

bool _isWithinDirectory(String directory, String path) {
  final prefix = directory.endsWith(Platform.pathSeparator)
      ? directory
      : '$directory${Platform.pathSeparator}';
  return path == directory || path.startsWith(prefix);
}
