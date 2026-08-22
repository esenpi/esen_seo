import 'seo_application_runtime.dart';

/// Collision-free file stem for one build-owned runtime artifact.
String seoApplicationRuntimeArtifactStem(
  SeoDomFirstApplicationRuntime runtime,
) => switch (runtime) {
  SeoDomFirstApplicationRuntimeBundle(:final memberKinds) =>
    'bundle+${memberKinds.map((kind) => kind.value).join('+')}+${runtime.id}',
  SeoDomFirstStepperApplicationRuntime()
      when runtime.id.startsWith('effects-') =>
    'stepper+${runtime.id}',
  _ => '${runtime.kind}-${runtime.id}',
};
