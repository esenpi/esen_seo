import 'dart:io';

import 'package:esen_seo/server.dart' show SeoDomFirstRuntimeArtifact;
import 'package:esen_seo/src/tooling/application_runtime_builder.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.contains('--help') || arguments.contains('-h')) {
    stdout.write(_usage);
    return;
  }
  try {
    final checkCount = arguments.where((value) => value == '--check').length;
    if (checkCount > 1) {
      throw const FormatException('Duplicate option "--check".');
    }
    final check = checkCount == 1;
    final values = _arguments(
      arguments.where((value) => value != '--check').toList(),
    );
    final output = values['output'] ?? 'build/esen_seo/runtimes';
    final artifacts = values.containsKey('plan')
        ? await _buildPlan(values, output, check)
        : [
            values.containsKey('bundle')
                ? await _buildBundle(values, output, check)
                : await _buildSingle(values, output, check),
          ];
    for (final artifact in artifacts) {
      final members = artifact.reference.kind == 'bundle'
          ? ', members '
              '${artifact.reference.memberKinds.map((kind) => kind.value).join(',')}'
          : '';
      stdout.writeln(
        '${check ? 'Verified' : 'Built'} ${artifact.reference.kind} runtime '
        '"${artifact.reference.id}"$members: '
        'schema ${artifact.manifest.schemaVersion}, '
        'contract revision ${artifact.manifest.contractRevision}, '
        '${artifact.manifest.bytes} bytes, '
        '${artifact.manifest.gzipBytes} gzip bytes, '
        'sha256 ${artifact.manifest.sha256}.',
      );
    }
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    stderr.write(_usage);
    exitCode = 64;
  } on ArgumentError catch (error) {
    stderr.writeln(error.message);
    exitCode = 64;
  } on StateError catch (error) {
    stderr.writeln(error.message);
    exitCode = 1;
  } on FileSystemException catch (error) {
    stderr.writeln(error.message);
    exitCode = 1;
  }
}

Future<List<SeoDomFirstRuntimeArtifact>> _buildPlan(
  Map<String, String> values,
  String output,
  bool check,
) async {
  const allowed = {'plan', 'output'};
  final incompatible = values.keys.toSet().difference(allowed);
  if (incompatible.isNotEmpty) {
    throw FormatException(
      'Option "--plan" cannot be combined with '
      '${incompatible.map((name) => '"--$name"').join(', ')}.',
    );
  }
  final plan = await loadSeoRuntimeBuildPlan(
    _required(values, 'plan'),
    outputDirectory: output,
  );
  return buildSeoApplicationRuntimePlan(plan, check: check);
}

Future<SeoDomFirstRuntimeArtifact> _buildBundle(
  Map<String, String> values,
  String output,
  bool check,
) async {
  const allowed = {'bundle', 'output'};
  final incompatible = values.keys.toSet().difference(allowed);
  if (incompatible.isNotEmpty) {
    throw FormatException(
      'Option "--bundle" cannot be combined with '
      '${incompatible.map((name) => '"--$name"').join(', ')}.',
    );
  }
  final request = await loadSeoRuntimeBundleBuildRequest(
    _required(values, 'bundle'),
    outputDirectory: output,
  );
  return buildSeoApplicationRuntimeBundle(request, write: !check);
}

Future<SeoDomFirstRuntimeArtifact> _buildSingle(
  Map<String, String> values,
  String output,
  bool check,
) async {
  final id = _required(values, 'id');
  final library = _required(values, 'library');
  final symbol = _required(values, 'symbol');
  final kind = values['kind'] ?? 'tabs';
  final Set<String> interactionIds;
  if (kind == 'stepper-effects' ||
      kind == 'configurator' ||
      kind == 'editorial-workflow' ||
      kind == 'approval-checklist') {
    interactionIds = _interactionIds(_required(values, 'interaction-ids'));
  } else {
    if (values.containsKey('interaction-ids')) {
      throw const FormatException(
        'Option "--interaction-ids" is only valid for "stepper-effects", '
        '"configurator", "editorial-workflow" or "approval-checklist".',
      );
    }
    interactionIds = const {};
  }
  if (kind != 'configurator' &&
      kind != 'editorial-workflow' &&
      kind != 'approval-checklist' &&
      values.containsKey('projection-symbol')) {
    throw const FormatException(
      'Option "--projection-symbol" is only valid for "configurator", '
      '"editorial-workflow" or "approval-checklist".',
    );
  }
  return switch (kind) {
    'tabs' => await buildSeoTabsApplicationRuntime(
        SeoTabsRuntimeBuildRequest(
          id: id,
          library: library,
          symbol: symbol,
          outputDirectory: output,
        ),
        write: !check,
      ),
    'carousel' => await buildSeoCarouselApplicationRuntime(
        SeoCarouselRuntimeBuildRequest(
          id: id,
          library: library,
          symbol: symbol,
          outputDirectory: output,
        ),
        write: !check,
      ),
    'collection' => await buildSeoCollectionApplicationRuntime(
        SeoCollectionRuntimeBuildRequest(
          id: id,
          library: library,
          symbol: symbol,
          outputDirectory: output,
        ),
        write: !check,
      ),
    'configurator' => await buildSeoConfiguratorApplicationRuntime(
        SeoConfiguratorRuntimeBuildRequest(
          id: id,
          library: library,
          transitionSymbol: symbol,
          projectionSymbol: _required(values, 'projection-symbol'),
          interactionIds: interactionIds,
          outputDirectory: output,
        ),
        write: !check,
      ),
    'editorial-workflow' => await buildSeoEditorialWorkflowApplicationRuntime(
        SeoEditorialWorkflowRuntimeBuildRequest(
          id: id,
          library: library,
          transitionSymbol: symbol,
          projectionSymbol: _required(values, 'projection-symbol'),
          interactionIds: interactionIds,
          outputDirectory: output,
        ),
        write: !check,
      ),
    'approval-checklist' => await buildSeoApprovalChecklistApplicationRuntime(
        SeoApprovalChecklistRuntimeBuildRequest(
          id: id,
          library: library,
          transitionSymbol: symbol,
          projectionSymbol: _required(values, 'projection-symbol'),
          interactionIds: interactionIds,
          outputDirectory: output,
        ),
        write: !check,
      ),
    'stepper' => await buildSeoStepperApplicationRuntime(
        SeoStepperRuntimeBuildRequest(
          id: id,
          library: library,
          symbol: symbol,
          outputDirectory: output,
        ),
        write: !check,
      ),
    'stepper-effects' => await buildSeoStepperEffectsApplicationRuntime(
        SeoStepperEffectsRuntimeBuildRequest(
          id: id,
          library: library,
          symbol: symbol,
          interactionIds: interactionIds,
          outputDirectory: output,
        ),
        write: !check,
      ),
    _ => throw FormatException(
        'Unknown runtime kind "$kind"; expected "tabs", "carousel", '
        '"collection", "configurator", "editorial-workflow", '
        '"approval-checklist", "stepper" or "stepper-effects".',
      ),
  };
}

Map<String, String> _arguments(List<String> arguments) {
  const allowed = {
    'id',
    'library',
    'symbol',
    'output',
    'kind',
    'interaction-ids',
    'projection-symbol',
    'bundle',
    'plan',
  };
  final values = <String, String>{};
  for (var index = 0; index < arguments.length; index++) {
    final argument = arguments[index];
    if (!argument.startsWith('--') || argument.length == 2) {
      throw FormatException('Unknown argument "$argument".');
    }
    final name = argument.substring(2);
    if (!allowed.contains(name)) {
      throw FormatException('Unknown option "--$name".');
    }
    if (values.containsKey(name)) {
      throw FormatException('Duplicate option "--$name".');
    }
    if (++index >= arguments.length || arguments[index].startsWith('--')) {
      throw FormatException('Option "--$name" needs a value.');
    }
    values[name] = arguments[index];
  }
  return values;
}

String _required(Map<String, String> values, String name) {
  final value = values[name];
  if (value == null || value.isEmpty) {
    throw FormatException('Missing required option "--$name".');
  }
  return value;
}

Set<String> _interactionIds(String value) {
  final ids = value.split(',');
  final unique = ids.toSet();
  if (ids.any((id) => id.isEmpty) || unique.length != ids.length) {
    throw const FormatException(
      'Option "--interaction-ids" requires unique comma-separated ids.',
    );
  }
  return Set<String>.unmodifiable(unique);
}

const String _usage = '''
Usage: dart run esen_seo:esen_seo_runtime \\
  --id <runtime-id> \\
  --library package:<app>/<file.dart> \\
  --symbol <top-level-transition> \\
  [--kind tabs|carousel|collection|configurator|editorial-workflow|approval-checklist|stepper|stepper-effects] \\
  [--projection-symbol <top-level-view-projection>] \\
  [--interaction-ids <id[,id...]>] \\
  [--output build/esen_seo/runtimes] [--check]

--interaction-ids is required for stepper-effects, configurator,
editorial-workflow and approval-checklist.
--projection-symbol is required for configurator, editorial-workflow and
approval-checklist and rejected for other kinds.

Bundle mode:
  dart run esen_seo:esen_seo_runtime \\
    --bundle <relative-config.json> \\
    [--output build/esen_seo/runtimes] [--check]

Bundle config schema:
  {"schemaVersion":1,"id":"page-runtime","entries":[
    {"kind":"tabs","library":"package:app/tabs.dart","symbol":"transitionTabs"},
    {"kind":"carousel","library":"package:app/carousel.dart","symbol":"transitionCarousel"}
  ]}

Plan mode:
  dart run esen_seo:esen_seo_runtime \\
    --plan <relative-plan.json> \\
    [--output build/esen_seo/runtimes] [--check]

Plan schema:
  {"schemaVersion":1,"runtimes":[
    {"kind":"tabs","id":"page-tabs","library":"package:app/tabs.dart","symbol":"transitionTabs"},
    {"kind":"bundle","id":"page-runtime","entries":[
      {"kind":"tabs","library":"package:app/tabs.dart","symbol":"transitionTabs"},
      {"kind":"carousel","library":"package:app/carousel.dart","symbol":"transitionCarousel"}
    ]}
  ]}
''';
