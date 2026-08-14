import 'seo_application_runtime.dart';

/// Collision-free file stem for one build-owned runtime artifact.
String seoApplicationRuntimeArtifactStem(
  SeoDomFirstApplicationRuntime runtime,
) =>
    '${runtime.kind}-${runtime.id}';
