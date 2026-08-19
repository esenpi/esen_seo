import 'dart:io';

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
    final id = _required(values, 'id');
    final library = _required(values, 'library');
    final symbol = _required(values, 'symbol');
    final output = values['output'] ?? 'build/esen_seo/runtimes';
    final kind = values['kind'] ?? 'tabs';
    final artifact = switch (kind) {
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
      'stepper' => await buildSeoStepperApplicationRuntime(
          SeoStepperRuntimeBuildRequest(
            id: id,
            library: library,
            symbol: symbol,
            outputDirectory: output,
          ),
          write: !check,
        ),
      _ => throw FormatException(
          'Unknown runtime kind "$kind"; expected "tabs", "carousel" or '
          '"stepper".',
        ),
    };
    stdout.writeln(
      '${check ? 'Verified' : 'Built'} ${artifact.reference.kind} runtime '
      '"${artifact.reference.id}": '
      '${artifact.manifest.bytes} bytes, '
      '${artifact.manifest.gzipBytes} gzip bytes, '
      'sha256 ${artifact.manifest.sha256}.',
    );
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
  }
}

Map<String, String> _arguments(List<String> arguments) {
  const allowed = {'id', 'library', 'symbol', 'output', 'kind'};
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

const String _usage = '''
Usage: dart run esen_seo:esen_seo_runtime \\
  --id <runtime-id> \\
  --library package:<app>/<file.dart> \\
  --symbol <top-level-transition> \\
  [--kind tabs|carousel|stepper] \\
  [--output build/esen_seo/runtimes] [--check]
''';
