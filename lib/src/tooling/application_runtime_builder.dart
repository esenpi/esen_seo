import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../components/seo_component_format.dart';
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

/// Inputs for one closed application-authored configurator runtime build.
final class SeoConfiguratorRuntimeBuildRequest {
  const SeoConfiguratorRuntimeBuildRequest({
    required this.id,
    required this.library,
    required this.transitionSymbol,
    required this.projectionSymbol,
    required this.interactionIds,
    this.outputDirectory = 'build/esen_seo/runtimes',
  });

  final String id;
  final String library;
  final String transitionSymbol;
  final String projectionSymbol;

  /// Stable configurator ids this runtime may enhance.
  final Set<String> interactionIds;
  final String outputDirectory;
}

/// Inputs for one closed application-authored editorial workflow runtime.
final class SeoEditorialWorkflowRuntimeBuildRequest {
  const SeoEditorialWorkflowRuntimeBuildRequest({
    required this.id,
    required this.library,
    required this.transitionSymbol,
    required this.projectionSymbol,
    required this.interactionIds,
    this.outputDirectory = 'build/esen_seo/runtimes',
  });

  final String id;
  final String library;
  final String transitionSymbol;
  final String projectionSymbol;

  /// Stable workflow ids this runtime may enhance.
  final Set<String> interactionIds;
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

/// Inputs for one application-authored stepper effects runtime build.
final class SeoStepperEffectsRuntimeBuildRequest {
  const SeoStepperEffectsRuntimeBuildRequest({
    required this.id,
    required this.library,
    required this.symbol,
    required this.interactionIds,
    this.outputDirectory = 'build/esen_seo/runtimes',
  });

  final String id;
  final String library;
  final String symbol;

  /// Stable Stepper ids this runtime may enhance.
  final Set<String> interactionIds;
  final String outputDirectory;
}

/// One checked transition included in an application runtime bundle.
///
/// Bundles admit Tabs, Carousel and one Stepper ownership family. Collection,
/// configurator and editorial workflow use standalone application runtimes.
sealed class SeoRuntimeBundleEntry {
  const SeoRuntimeBundleEntry._({
    required this.library,
    required this.symbol,
  });

  const factory SeoRuntimeBundleEntry.tabs({
    required String library,
    required String symbol,
  }) = SeoTabsRuntimeBundleEntry;

  const factory SeoRuntimeBundleEntry.carousel({
    required String library,
    required String symbol,
  }) = SeoCarouselRuntimeBundleEntry;

  const factory SeoRuntimeBundleEntry.stepper({
    required String library,
    required String symbol,
  }) = SeoStepperRuntimeBundleEntry;

  const factory SeoRuntimeBundleEntry.stepperEffects({
    required String library,
    required String symbol,
    required Set<String> interactionIds,
  }) = SeoStepperEffectsRuntimeBundleEntry;

  final String library;
  final String symbol;
  SeoDomFirstApplicationRuntimeKind get kind;
  Set<String> get interactionIds => const {};
}

final class SeoTabsRuntimeBundleEntry extends SeoRuntimeBundleEntry {
  const SeoTabsRuntimeBundleEntry({
    required super.library,
    required super.symbol,
  }) : super._();

  @override
  SeoDomFirstApplicationRuntimeKind get kind =>
      SeoDomFirstApplicationRuntimeKind.tabs;
}

final class SeoCarouselRuntimeBundleEntry extends SeoRuntimeBundleEntry {
  const SeoCarouselRuntimeBundleEntry({
    required super.library,
    required super.symbol,
  }) : super._();

  @override
  SeoDomFirstApplicationRuntimeKind get kind =>
      SeoDomFirstApplicationRuntimeKind.carousel;
}

final class SeoStepperRuntimeBundleEntry extends SeoRuntimeBundleEntry {
  const SeoStepperRuntimeBundleEntry({
    required super.library,
    required super.symbol,
  }) : super._();

  @override
  SeoDomFirstApplicationRuntimeKind get kind =>
      SeoDomFirstApplicationRuntimeKind.stepper;
}

final class SeoStepperEffectsRuntimeBundleEntry extends SeoRuntimeBundleEntry {
  const SeoStepperEffectsRuntimeBundleEntry({
    required super.library,
    required super.symbol,
    required this.interactionIds,
  }) : super._();

  @override
  SeoDomFirstApplicationRuntimeKind get kind =>
      SeoDomFirstApplicationRuntimeKind.stepperEffects;

  @override
  final Set<String> interactionIds;
}

/// Inputs for one route-scoped bundle of two or three checked transitions.
final class SeoRuntimeBundleBuildRequest {
  const SeoRuntimeBundleBuildRequest({
    required this.id,
    required this.entries,
    this.outputDirectory = 'build/esen_seo/runtimes',
  });

  final String id;
  final List<SeoRuntimeBundleEntry> entries;
  final String outputDirectory;
}

/// Reads one bounded, strictly shaped bundle build configuration.
Future<SeoRuntimeBundleBuildRequest> loadSeoRuntimeBundleBuildRequest(
  String configPath, {
  String? packageRoot,
  String outputDirectory = 'build/esen_seo/runtimes',
}) async {
  final root = Directory(packageRoot ?? Directory.current.path).absolute;
  final file = await _checkedBundleConfigFile(root, configPath);
  final String source;
  try {
    final handle = await file.open();
    try {
      if (await handle.length() > _runtimeBundleConfigMaxBytes) {
        throw StateError(
          'Runtime bundle config "$configPath" exceeds '
          '$_runtimeBundleConfigMaxBytes bytes.',
        );
      }
      final bytes = await handle.read(_runtimeBundleConfigMaxBytes + 1);
      if (bytes.length > _runtimeBundleConfigMaxBytes) {
        throw StateError(
          'Runtime bundle config "$configPath" exceeds '
          '$_runtimeBundleConfigMaxBytes bytes.',
        );
      }
      source = utf8.decode(bytes);
    } finally {
      await handle.close();
    }
  } on FileSystemException catch (error) {
    throw StateError('Cannot read runtime bundle config "$configPath": $error');
  } on FormatException catch (error) {
    throw FormatException(
      'Runtime bundle config "$configPath" is not valid UTF-8: '
      '${error.message}',
    );
  }

  final Object? decoded;
  try {
    decoded = jsonDecode(source);
  } on FormatException catch (error) {
    throw FormatException(
      'Runtime bundle config "$configPath" is not valid JSON: '
      '${error.message}',
    );
  }
  if (decoded is! Map<String, Object?>) {
    throw const FormatException('Runtime bundle config must be a JSON object.');
  }
  _requireExactFields(
    decoded,
    const {'schemaVersion', 'id', 'entries'},
    'Runtime bundle config',
  );
  if (decoded['schemaVersion'] is! int ||
      decoded['schemaVersion'] != 1 ||
      decoded['id'] is! String ||
      decoded['entries'] is! List) {
    throw const FormatException(
        'Runtime bundle config has invalid field types.');
  }

  final entries = <SeoRuntimeBundleEntry>[];
  for (final (index, raw) in (decoded['entries']! as List).indexed) {
    if (raw is! Map<String, Object?>) {
      throw FormatException('Runtime bundle entry $index must be an object.');
    }
    final rawKind = raw['kind'];
    final kind = rawKind is String
        ? SeoDomFirstApplicationRuntimeKind.tryParse(rawKind)
        : null;
    if (kind == null) {
      throw FormatException('Runtime bundle entry $index has an unknown kind.');
    }
    final expectedFields =
        kind == SeoDomFirstApplicationRuntimeKind.stepperEffects
            ? const {'kind', 'library', 'symbol', 'interactionIds'}
            : const {'kind', 'library', 'symbol'};
    _requireExactFields(raw, expectedFields, 'Runtime bundle entry $index');
    final library = raw['library'];
    final symbol = raw['symbol'];
    if (library is! String || symbol is! String) {
      throw FormatException(
        'Runtime bundle entry $index has invalid field types.',
      );
    }
    entries.add(switch (kind) {
      SeoDomFirstApplicationRuntimeKind.tabs => SeoRuntimeBundleEntry.tabs(
          library: library,
          symbol: symbol,
        ),
      SeoDomFirstApplicationRuntimeKind.carousel =>
        SeoRuntimeBundleEntry.carousel(
          library: library,
          symbol: symbol,
        ),
      SeoDomFirstApplicationRuntimeKind.collection => throw FormatException(
          'Runtime bundle entry $index uses collection, which requires a '
          'standalone artifact.',
        ),
      SeoDomFirstApplicationRuntimeKind.configurator => throw FormatException(
          'Runtime bundle entry $index uses configurator, which requires a '
          'standalone artifact.',
        ),
      SeoDomFirstApplicationRuntimeKind.editorialWorkflow =>
        throw FormatException(
          'Runtime bundle entry $index uses editorial-workflow, which requires '
          'a standalone artifact.',
        ),
      SeoDomFirstApplicationRuntimeKind.stepper =>
        SeoRuntimeBundleEntry.stepper(
          library: library,
          symbol: symbol,
        ),
      SeoDomFirstApplicationRuntimeKind.stepperEffects =>
        SeoRuntimeBundleEntry.stepperEffects(
          library: library,
          symbol: symbol,
          interactionIds: _configInteractionIds(
            raw['interactionIds'],
            index,
          ),
        ),
    });
  }
  return SeoRuntimeBundleBuildRequest(
    id: decoded['id']! as String,
    entries: List<SeoRuntimeBundleEntry>.unmodifiable(entries),
    outputDirectory: outputDirectory,
  );
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

/// Compiles one checked configurator transition and view projection.
Future<SeoDomFirstRuntimeArtifact> buildSeoConfiguratorApplicationRuntime(
  SeoConfiguratorRuntimeBuildRequest request, {
  String? packageRoot,
  bool write = true,
}) =>
    _buildApplicationRuntime(
      _ApplicationRuntimeBuildRequest(
        reference: SeoDomFirstApplicationRuntime.configurator(request.id),
        library: request.library,
        symbol: request.transitionSymbol,
        projectionSymbol: request.projectionSymbol,
        interactionIds: request.interactionIds,
        outputDirectory: request.outputDirectory,
      ),
      packageRoot: packageRoot,
      write: write,
    );

/// Compiles one checked editorial workflow transition and view projection.
Future<SeoDomFirstRuntimeArtifact> buildSeoEditorialWorkflowApplicationRuntime(
  SeoEditorialWorkflowRuntimeBuildRequest request, {
  String? packageRoot,
  bool write = true,
}) =>
    _buildApplicationRuntime(
      _ApplicationRuntimeBuildRequest(
        reference: SeoDomFirstApplicationRuntime.editorialWorkflow(request.id),
        library: request.library,
        symbol: request.transitionSymbol,
        projectionSymbol: request.projectionSymbol,
        interactionIds: request.interactionIds,
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

/// Compiles one checked stepper effects transition and writes its files.
Future<SeoDomFirstRuntimeArtifact> buildSeoStepperEffectsApplicationRuntime(
  SeoStepperEffectsRuntimeBuildRequest request, {
  String? packageRoot,
  bool write = true,
}) =>
    _buildApplicationRuntime(
      _ApplicationRuntimeBuildRequest(
        reference: SeoDomFirstApplicationRuntime.stepperEffects(request.id),
        library: request.library,
        symbol: request.symbol,
        interactionIds: request.interactionIds,
        outputDirectory: request.outputDirectory,
      ),
      packageRoot: packageRoot,
      write: write,
    );

/// Compiles different checked adapter families into one verified artifact.
Future<SeoDomFirstRuntimeArtifact> buildSeoApplicationRuntimeBundle(
  SeoRuntimeBundleBuildRequest request, {
  String? packageRoot,
  bool write = true,
}) async {
  final root = Directory(packageRoot ?? Directory.current.path).absolute;
  final entries = request.entries.toList(growable: false)
    ..sort((left, right) => left.kind.index.compareTo(right.kind.index));
  final reference = SeoDomFirstApplicationRuntime.bundle(
    request.id,
    members: entries.map((entry) => entry.kind),
  );
  final output = _checkedOutputDirectory(root, request.outputDirectory);
  final prepared = <_PreparedRuntimeBundleEntry>[];
  for (final entry in entries) {
    _validateSymbol(entry.symbol);
    prepared.add(_PreparedRuntimeBundleEntry(
      kind: entry.kind,
      library: entry.library,
      symbol: entry.symbol,
      interactionIds:
          entry.kind == SeoDomFirstApplicationRuntimeKind.stepperEffects
              ? _validatedStepperEffectInteractionIds(entry.interactionIds)
              : const <String>[],
    ));
  }

  final packageConfig = File('${root.path}/.dart_tool/package_config.json');
  if (!await packageConfig.exists()) {
    throw StateError(
      'Missing ${packageConfig.path}. Run dart pub get in ${root.path}.',
    );
  }
  final graph = await _PackageGraph.load(packageConfig, root);
  final checked = <_CheckedRuntimeBundleEntry>[];
  for (final entry in prepared) {
    final libraryUri = _checkedApplicationLibraryUri(
      graph,
      entry.library,
    );
    checked.add(_CheckedRuntimeBundleEntry(
      kind: entry.kind,
      library: libraryUri,
      symbol: entry.symbol,
      interactionIds: entry.interactionIds,
    ));
  }

  return _compileApplicationRuntime(
    root: root,
    output: output,
    reference: reference,
    entrypointSource: _bundleEntrypointSource(checked),
    write: write,
  );
}

final class _PreparedRuntimeBundleEntry {
  const _PreparedRuntimeBundleEntry({
    required this.kind,
    required this.library,
    required this.symbol,
    required this.interactionIds,
  });

  final SeoDomFirstApplicationRuntimeKind kind;
  final String library;
  final String symbol;
  final List<String> interactionIds;
}

final class _CheckedRuntimeBundleEntry {
  const _CheckedRuntimeBundleEntry({
    required this.kind,
    required this.library,
    required this.symbol,
    required this.interactionIds,
  });

  final SeoDomFirstApplicationRuntimeKind kind;
  final Uri library;
  final String symbol;
  final List<String> interactionIds;
}

const int _runtimeBundleConfigMaxBytes = 32 * 1024;

Future<File> _checkedBundleConfigFile(Directory root, String relative) async {
  final uri = Uri.tryParse(relative);
  if (uri == null ||
      uri.hasScheme ||
      uri.hasAuthority ||
      uri.hasQuery ||
      uri.hasFragment ||
      uri.path.startsWith('/') ||
      uri.pathSegments.isEmpty ||
      !uri.path.endsWith('.json') ||
      uri.pathSegments.any(_isUnsafePathSegment)) {
    throw ArgumentError.value(
      relative,
      'configPath',
      'must be a relative JSON file below the application root',
    );
  }
  final file = File.fromUri(root.uri.resolveUri(uri));
  try {
    final rootPath = await root.resolveSymbolicLinks();
    final filePath = await file.resolveSymbolicLinks();
    if (!_isWithinDirectory(rootPath, filePath)) {
      throw ArgumentError.value(
        relative,
        'configPath',
        'resolves outside the application through a symbolic link',
      );
    }
    return File(filePath);
  } on FileSystemException catch (error) {
    throw StateError(
        'Cannot resolve runtime bundle config "$relative": $error');
  }
}

void _requireExactFields(
  Map<String, Object?> value,
  Set<String> expected,
  String description,
) {
  final actual = value.keys.toSet();
  if (actual.difference(expected).isNotEmpty ||
      expected.difference(actual).isNotEmpty) {
    throw FormatException('$description has missing or unknown fields.');
  }
}

Set<String> _configInteractionIds(Object? value, int index) {
  if (value is! List || value.any((id) => id is! String)) {
    throw FormatException(
      'Runtime bundle entry $index has invalid interactionIds.',
    );
  }
  final ids = value.cast<String>();
  final unique = ids.toSet();
  if (ids.isEmpty || unique.length != ids.length) {
    throw FormatException(
      'Runtime bundle entry $index requires unique interactionIds.',
    );
  }
  return Set<String>.unmodifiable(unique);
}

final class _ApplicationRuntimeBuildRequest {
  const _ApplicationRuntimeBuildRequest({
    required this.reference,
    required this.library,
    required this.symbol,
    required this.outputDirectory,
    this.interactionIds = const {},
    this.projectionSymbol,
  });

  final SeoDomFirstApplicationRuntime reference;
  final String library;
  final String symbol;
  final String outputDirectory;
  final Set<String> interactionIds;
  final String? projectionSymbol;
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
  _validateSymbol(request.symbol);
  if (request.projectionSymbol case final projectionSymbol?) {
    _validateSymbol(projectionSymbol);
  }
  final interactionIds =
      reference is SeoDomFirstStepperEffectsApplicationRuntime ||
              reference is SeoDomFirstConfiguratorApplicationRuntime ||
              reference is SeoDomFirstEditorialWorkflowApplicationRuntime
          ? _validatedStepperEffectInteractionIds(request.interactionIds)
          : const <String>[];
  final output = _checkedOutputDirectory(root, request.outputDirectory);

  final packageConfig = File('${root.path}/.dart_tool/package_config.json');
  if (!await packageConfig.exists()) {
    throw StateError(
      'Missing ${packageConfig.path}. Run dart pub get in ${root.path}.',
    );
  }
  final graph = await _PackageGraph.load(packageConfig, root);
  final libraryUri = _checkedApplicationLibraryUri(graph, request.library);

  final entrypointSource = switch (reference) {
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
    SeoDomFirstConfiguratorApplicationRuntime() =>
      _configuratorEntrypointSource(
        libraryUri,
        request.symbol,
        request.projectionSymbol!,
        interactionIds,
      ),
    SeoDomFirstEditorialWorkflowApplicationRuntime() =>
      _editorialWorkflowEntrypointSource(
        libraryUri,
        request.symbol,
        request.projectionSymbol!,
        interactionIds,
      ),
    SeoDomFirstStepperApplicationRuntime() => _stepperEntrypointSource(
        libraryUri,
        request.symbol,
      ),
    SeoDomFirstStepperEffectsApplicationRuntime() =>
      _stepperEffectsEntrypointSource(
        libraryUri,
        request.symbol,
        interactionIds,
      ),
    SeoDomFirstApplicationRuntimeBundle() => throw StateError(
        'Bundle references require buildSeoApplicationRuntimeBundle.',
      ),
  };
  return _compileApplicationRuntime(
    root: root,
    output: output,
    reference: reference,
    entrypointSource: entrypointSource,
    write: write,
  );
}

void _validateSymbol(String symbol) {
  if (!_dartIdentifier.hasMatch(symbol) ||
      Keyword.keywords.containsKey(symbol)) {
    throw ArgumentError.value(
      symbol,
      'symbol',
      'must be a valid non-reserved Dart identifier',
    );
  }
}

Uri _checkedApplicationLibraryUri(_PackageGraph graph, String library) {
  final libraryUri = Uri.tryParse(library);
  if (libraryUri == null ||
      libraryUri.scheme != 'package' ||
      libraryUri.hasQuery ||
      libraryUri.hasFragment) {
    throw ArgumentError.value(
      library,
      'library',
      'must be a package: URI below the application lib directory',
    );
  }
  final rootLibrary = graph.resolveApplicationLibrary(libraryUri);
  _PureApplicationGraph(graph).check(rootLibrary);
  return libraryUri;
}

Future<SeoDomFirstRuntimeArtifact> _compileApplicationRuntime({
  required Directory root,
  required Directory output,
  required SeoDomFirstApplicationRuntime reference,
  required String entrypointSource,
  required bool write,
}) async {
  final scratchRoot = Directory('${root.path}/.dart_tool');
  final scratch = await scratchRoot.createTemp('esen-seo-runtime-');
  try {
    final entrypoint = File('${scratch.path}/entrypoint.dart');
    final compiled = File('${scratch.path}/runtime.js');
    await entrypoint.writeAsString(entrypointSource);

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

String _configuratorEntrypointSource(
  Uri library,
  String transitionSymbol,
  String projectionSymbol,
  List<String> interactionIds,
) {
  final encodedIds = interactionIds.map(jsonEncode).join(', ');
  return '''
import 'package:esen_seo/src/components/seo_configurator_transition.dart';
import 'package:esen_seo/src/renderer/dom_first_configurator_adapter_web.dart';
import ${jsonEncode(library.toString())} as application;

const _interactionIds = <String>{$encodedIds};

SeoConfiguratorState _applicationTransition(
  SeoConfiguratorState state,
  SeoConfiguratorAction action,
  SeoConfiguratorConstraints constraints,
) => application.$transitionSymbol(state, action, constraints);

SeoConfiguratorView _applicationProjection(
  SeoConfiguratorState state,
) => application.$projectionSymbol(state);

void main() => enhanceSeoDomFirstConfigurators(
  interactionIds: _interactionIds,
  transition: _applicationTransition,
  project: _applicationProjection,
);
''';
}

String _editorialWorkflowEntrypointSource(
  Uri library,
  String transitionSymbol,
  String projectionSymbol,
  List<String> interactionIds,
) {
  final encodedIds = interactionIds.map(jsonEncode).join(', ');
  return '''
import 'package:esen_seo/src/components/seo_editorial_workflow_transition.dart';
import 'package:esen_seo/src/renderer/dom_first_editorial_workflow_adapter_web.dart';
import ${jsonEncode(library.toString())} as application;

const _interactionIds = <String>{$encodedIds};

SeoEditorialWorkflowState _applicationTransition(
  SeoEditorialWorkflowState state,
  SeoEditorialWorkflowAction action,
) => application.$transitionSymbol(state, action);

SeoEditorialWorkflowView _applicationProjection(
  SeoEditorialWorkflowState state,
) => application.$projectionSymbol(state);

void main() => enhanceSeoDomFirstEditorialWorkflows(
  interactionIds: _interactionIds,
  transition: _applicationTransition,
  project: _applicationProjection,
);
''';
}

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

String _stepperEffectsEntrypointSource(
  Uri library,
  String symbol,
  List<String> interactionIds,
) {
  final encodedIds = interactionIds.map(jsonEncode).join(', ');
  return '''
import 'package:esen_seo/src/components/seo_stepper_transition.dart';
import 'package:esen_seo/src/renderer/dom_first_stepper_adapter_web.dart';
import ${jsonEncode(library.toString())} as application;

const _interactionIds = <String>{$encodedIds};

SeoStepperEffectResult _applicationTransition(
  SeoStepperState state,
  SeoStepperAction action,
  SeoStepperEffectContext context,
) => application.$symbol(state, action, context);

void main() => enhanceSeoDomFirstStepperEffects(
  interactionIds: _interactionIds,
  transition: _applicationTransition,
);
''';
}

String _bundleEntrypointSource(List<_CheckedRuntimeBundleEntry> entries) {
  final packageImports = <String>{};
  final applicationImports = StringBuffer();
  final declarations = StringBuffer();
  final initializers = StringBuffer();

  void addPackageImport(String path) {
    packageImports.add("import '$path';");
  }

  for (var index = 0; index < entries.length; index++) {
    final entry = entries[index];
    switch (entry.kind) {
      case SeoDomFirstApplicationRuntimeKind.tabs:
        addPackageImport(
          'package:esen_seo/src/components/seo_tabs_transition.dart',
        );
        addPackageImport(
          'package:esen_seo/src/renderer/dom_first_tabs_adapter_web.dart',
        );
      case SeoDomFirstApplicationRuntimeKind.carousel:
        addPackageImport(
          'package:esen_seo/src/components/seo_carousel_transition.dart',
        );
        addPackageImport(
          'package:esen_seo/src/renderer/dom_first_carousel_adapter_web.dart',
        );
      case SeoDomFirstApplicationRuntimeKind.collection:
        throw StateError(
          'Collection runtimes must use a standalone artifact.',
        );
      case SeoDomFirstApplicationRuntimeKind.configurator:
        throw StateError(
          'Configurator runtimes must use a standalone artifact.',
        );
      case SeoDomFirstApplicationRuntimeKind.editorialWorkflow:
        throw StateError(
          'Editorial workflow runtimes must use a standalone artifact.',
        );
      case SeoDomFirstApplicationRuntimeKind.stepper ||
            SeoDomFirstApplicationRuntimeKind.stepperEffects:
        addPackageImport(
          'package:esen_seo/src/components/seo_stepper_transition.dart',
        );
        addPackageImport(
          'package:esen_seo/src/renderer/dom_first_stepper_adapter_web.dart',
        );
    }
    applicationImports.writeln(
      'import ${jsonEncode(entry.library.toString())} as application$index;',
    );

    switch (entry.kind) {
      case SeoDomFirstApplicationRuntimeKind.tabs:
        declarations.writeln('''
SeoTabsState _transition$index(
  SeoTabsState state,
  SeoTabsAction action,
) => application$index.${entry.symbol}(state, action);
''');
        initializers.writeln('''
  enhanceSeoDomFirstTabs(
    transition: _transition$index,
  );''');
      case SeoDomFirstApplicationRuntimeKind.carousel:
        declarations.writeln('''
SeoCarouselState _transition$index(
  SeoCarouselState state,
  SeoCarouselAction action,
) => application$index.${entry.symbol}(state, action);
''');
        initializers.writeln('''
  enhanceSeoDomFirstCarousels(
    transition: _transition$index,
  );''');
      case SeoDomFirstApplicationRuntimeKind.collection:
        throw StateError(
          'Collection runtimes must use a standalone artifact.',
        );
      case SeoDomFirstApplicationRuntimeKind.configurator:
        throw StateError(
          'Configurator runtimes must use a standalone artifact.',
        );
      case SeoDomFirstApplicationRuntimeKind.editorialWorkflow:
        throw StateError(
          'Editorial workflow runtimes must use a standalone artifact.',
        );
      case SeoDomFirstApplicationRuntimeKind.stepper:
        declarations.writeln('''
SeoStepperState _transition$index(
  SeoStepperState state,
  SeoStepperAction action,
) => application$index.${entry.symbol}(state, action);
''');
        initializers.writeln('''
  enhanceSeoDomFirstSteppers(
    transition: _transition$index,
  );''');
      case SeoDomFirstApplicationRuntimeKind.stepperEffects:
        final encodedIds = entry.interactionIds.map(jsonEncode).join(', ');
        declarations.writeln('''
const _interactionIds$index = <String>{$encodedIds};

SeoStepperEffectResult _transition$index(
  SeoStepperState state,
  SeoStepperAction action,
  SeoStepperEffectContext context,
) => application$index.${entry.symbol}(state, action, context);
''');
        initializers.writeln('''
  enhanceSeoDomFirstStepperEffects(
    interactionIds: _interactionIds$index,
    transition: _transition$index,
  );''');
    }
  }

  return '''
${packageImports.join('\n')}
$applicationImports
$declarations
void main() {$initializers
}
''';
}

List<String> _validatedStepperEffectInteractionIds(Set<String> interactionIds) {
  if (interactionIds.isEmpty ||
      interactionIds.any((id) => !isValidSeoInteractionId(id))) {
    throw ArgumentError.value(
      interactionIds,
      'interactionIds',
      'must contain at least one valid, stable interaction id',
    );
  }
  final sorted = interactionIds.toList()..sort();
  return List<String>.unmodifiable(sorted);
}

Directory _checkedOutputDirectory(Directory root, String relative) {
  final uri = Uri.tryParse(relative);
  if (uri == null ||
      uri.hasScheme ||
      uri.hasAuthority ||
      uri.hasQuery ||
      uri.hasFragment ||
      uri.pathSegments.isEmpty ||
      uri.pathSegments.first != 'build' ||
      uri.pathSegments.any(_isUnsafePathSegment)) {
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
              rawUri == 'package:esen_seo/configurator.dart' ||
              rawUri == 'package:esen_seo/workflow.dart' ||
              rawUri ==
                  'package:esen_seo/src/components/seo_tabs_transition.dart' ||
              rawUri ==
                  'package:esen_seo/src/components/seo_carousel_transition.dart' ||
              rawUri ==
                  'package:esen_seo/src/components/seo_collection_transition.dart' ||
              rawUri ==
                  'package:esen_seo/src/components/seo_stepper_transition.dart' ||
              rawUri ==
                  'package:esen_seo/src/components/seo_configurator_transition.dart' ||
              rawUri ==
                  'package:esen_seo/src/components/seo_editorial_workflow_transition.dart')) {
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

bool _isUnsafePathSegment(String segment) =>
    segment.isEmpty ||
    segment == '.' ||
    segment == '..' ||
    segment.contains('/') ||
    segment.contains('\\') ||
    segment.runes.any(_isControlCodePoint);

bool _isControlCodePoint(int codePoint) =>
    codePoint < 0x20 || codePoint == 0x7f;

bool _isWithinDirectory(String directory, String path) {
  final prefix = directory.endsWith(Platform.pathSeparator)
      ? directory
      : '$directory${Platform.pathSeparator}';
  return path == directory || path.startsWith(prefix);
}
