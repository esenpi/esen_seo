/// Pure route manifest for the profile-bound DOM-first navigation pilot.
library;

import 'dart:convert';

export '../renderer/seo_container.dart' show seoDomFirstNavigationHeadAttribute;

import '../renderer/seo_dom_first_runtime_handoff.dart';
import 'seo_application_runtime.dart';
import 'seo_route.dart';
import 'seo_route_delivery.dart';

const int seoDomFirstNavigationManifestSchema = 1;
const int seoDomFirstRuntimeHandoffManifestSchema = 2;
const int seoDomFirstApplicationRuntimeHandoffManifestSchema = 3;
const int seoDomFirstTypedApplicationRuntimeHandoffManifestSchema = 4;
const int seoDomFirstNavigationMaxRoutes = 256;
const int seoDomFirstNavigationMaxPatternLength = 256;
const int seoDomFirstNavigationMaxManifestBytes = 32768;
const int seoDomFirstApplicationHandoffRuntimeMaxBytes = 512 * 1024;
const String seoDomFirstNavigationManifestAttribute =
    'data-esen-seo-navigation-manifest';

/// One ordered route-pattern entry in a DOM-first navigation manifest.
final class SeoDomFirstNavigationEntry {
  const SeoDomFirstNavigationEntry({
    required this.pattern,
    this.profile,
    this.runtime,
  });

  final String pattern;
  final String? profile;

  /// Loadable runtime expected for this route, or `null` for a static route.
  final SeoDomFirstNavigationRuntimeEntry? runtime;
}

/// One runtime bound to a route in a handoff manifest.
final class SeoDomFirstNavigationRuntimeEntry {
  const SeoDomFirstNavigationRuntimeEntry({
    required this.kind,
    required this.sha256,
    required this.bytes,
    this.applicationId,
    this.contractRevision,
  });

  /// Closed package or application runtime kind.
  final String kind;

  /// Lowercase SHA-256 of the bound package body or application source.
  ///
  /// Application handoff hashes the verified artifact before the fixed
  /// package-owned readiness epilogue is appended.
  final String sha256;

  /// Exact UTF-8 length of the bytes covered by [sha256].
  final int bytes;

  /// Typed application artifact id, or `null` for a package-owned runtime.
  final String? applicationId;

  /// Application adapter contract, or `null` for a package-owned runtime.
  final int? contractRevision;

  bool get isApplication => applicationId != null;
}

/// The package-owned route information embedded in one navigable document.
final class SeoDomFirstNavigationPlan {
  const SeoDomFirstNavigationPlan._({
    required this.schemaVersion,
    required this.basePath,
    required this.profile,
    required this.entries,
    required this.currentRuntime,
    required this.profileRuntime,
    required this.manifestJson,
  });

  /// Manifest schema selected by the current route profile.
  final int schemaVersion;

  /// Decoded deployment prefix, `/` for an origin-root deployment.
  final String basePath;

  /// Exact runtime profile required for an in-document replacement.
  final String profile;

  /// Route patterns in their server declaration order.
  final List<SeoDomFirstNavigationEntry> entries;

  /// Runtime descriptor selected by the route for which this plan was built.
  final SeoDomFirstNavigationRuntimeEntry? currentRuntime;

  /// Verified runtime identity shared by this explicit handoff profile.
  ///
  /// The value is also available on static routes, whose [currentRuntime] is
  /// null. Legacy schema-3 profiles derive the same descriptor from their one
  /// admitted Collection route.
  final SeoDomFirstNavigationRuntimeEntry? profileRuntime;

  /// Script-safe JSON consumed by the package browser runtime.
  final String manifestJson;
}

/// Builds the bounded ordered manifest for [currentRoute].
///
/// Returns `null` when the route did not opt into navigation. The current
/// route must be the same instance contained in [routes], preserving the exact
/// declaration order used by [matchSeoRoute].
SeoDomFirstNavigationPlan? buildSeoDomFirstNavigationPlan({
  required List<SeoRoute> routes,
  required SeoRoute currentRoute,
  required String siteBase,
  Map<SeoDomFirstApplicationRuntime, SeoDomFirstNavigationRuntimeEntry>
      applicationRuntimes = const {},
}) {
  final profile = seoDomFirstNavigationProfile(currentRoute);
  if (profile == null) return null;
  final runtimeHandoff = currentRoute.domFirstFeatures.contains(
    SeoDomFirstFeature.runtimeHandoff,
  );
  final applicationRuntimeHandoff = currentRoute.domFirstFeatures.contains(
    SeoDomFirstFeature.applicationRuntimeHandoff,
  );
  final typedApplicationRuntimeHandoff = applicationRuntimeHandoff &&
      currentRoute.applicationRuntimeHandoffProfile != null;
  if (routes.length > seoDomFirstNavigationMaxRoutes) {
    throw ArgumentError.value(
      routes.length,
      'routes',
      'navigation supports at most $seoDomFirstNavigationMaxRoutes routes',
    );
  }
  final currentIndex =
      routes.indexWhere((route) => identical(route, currentRoute));
  if (currentIndex < 0) {
    throw ArgumentError.value(
      currentRoute,
      'currentRoute',
      'must be the route instance contained in routes',
    );
  }
  if (applicationRuntimeHandoff) {
    _validateApplicationHandoffProfile(
      routes,
      applicationRuntimes,
      profile,
      typed: typedApplicationRuntimeHandoff,
    );
  }
  final origin = Uri.tryParse(siteBase.trim());
  if (origin == null ||
      !origin.hasScheme ||
      (origin.scheme != 'http' && origin.scheme != 'https') ||
      origin.host.isEmpty ||
      origin.hasQuery ||
      origin.hasFragment ||
      origin.userInfo.isNotEmpty) {
    throw ArgumentError.value(
      siteBase,
      'siteBase',
      'must be an absolute HTTP(S) origin with an optional path prefix',
    );
  }
  final basePath = _decodedNormalizedPath(_rawPath(siteBase.trim()));
  if (basePath.length > seoDomFirstNavigationMaxPatternLength ||
      _unsafeManifestText(basePath)) {
    throw ArgumentError.value(
      siteBase,
      'siteBase',
      'path prefix must be bounded plain text',
    );
  }
  final entries = <SeoDomFirstNavigationEntry>[];
  for (final route in routes) {
    if (route.path.length > seoDomFirstNavigationMaxPatternLength ||
        _unsafeManifestText(route.path) ||
        _invalidNavigationPattern(route.path)) {
      throw ArgumentError.value(
        route.path,
        'routes',
        'navigation route patterns must be bounded plain text',
      );
    }
    entries.add(
      SeoDomFirstNavigationEntry(
        pattern: route.path,
        profile: seoDomFirstNavigationProfile(route),
        runtime: runtimeHandoff
            ? _packageHandoffRuntime(route)
            : applicationRuntimeHandoff
                ? _applicationHandoffRuntime(route, applicationRuntimes)
                : null,
      ),
    );
  }
  final schemaVersion = applicationRuntimeHandoff
      ? typedApplicationRuntimeHandoff
          ? seoDomFirstTypedApplicationRuntimeHandoffManifestSchema
          : seoDomFirstApplicationRuntimeHandoffManifestSchema
      : runtimeHandoff
          ? seoDomFirstRuntimeHandoffManifestSchema
          : seoDomFirstNavigationManifestSchema;
  final encoded = jsonEncode({
    'schema': schemaVersion,
    'base': basePath,
    'profile': profile,
    'routes': [
      for (final entry in entries)
        if (applicationRuntimeHandoff)
          [
            entry.pattern,
            entry.profile,
            switch (entry.runtime) {
              final runtime? => [
                  'application',
                  runtime.kind,
                  runtime.applicationId,
                  runtime.contractRevision,
                  runtime.sha256,
                  runtime.bytes,
                ],
              null => null,
            },
          ]
        else if (runtimeHandoff)
          [
            entry.pattern,
            entry.profile,
            switch (entry.runtime) {
              final runtime? => [runtime.kind, runtime.sha256, runtime.bytes],
              null => null,
            },
          ]
        else
          [entry.pattern, entry.profile],
    ],
  });
  final manifestJson = _scriptSafeJson(encoded);
  final bytes = utf8.encode(manifestJson).length;
  if (bytes > seoDomFirstNavigationMaxManifestBytes) {
    throw ArgumentError.value(
      bytes,
      'routes',
      'navigation manifest exceeds $seoDomFirstNavigationMaxManifestBytes '
          'UTF-8 bytes',
    );
  }
  return SeoDomFirstNavigationPlan._(
    schemaVersion: schemaVersion,
    basePath: basePath,
    profile: profile,
    entries: List.unmodifiable(entries),
    currentRuntime: entries[currentIndex].runtime,
    profileRuntime: applicationRuntimeHandoff
        ? _applicationHandoffProfileRuntime(
            routes,
            applicationRuntimes,
            profile,
            typed: typedApplicationRuntimeHandoff,
          )
        : null,
    manifestJson: manifestJson,
  );
}

/// Returns the exact compatible runtime profile, or `null` when navigation is
/// disabled for [route].
String? seoDomFirstNavigationProfile(SeoRoute route) {
  if (!route.domFirstFeatures.contains(SeoDomFirstFeature.navigation)) {
    return null;
  }
  final applicationHandoff = route.domFirstFeatures.contains(
    SeoDomFirstFeature.applicationRuntimeHandoff,
  );
  if (!route.isDomFirst ||
      (route.applicationRuntime != null && !applicationHandoff)) {
    throw StateError('Invalid DOM-first navigation route');
  }
  final featureProfile =
      seoDomFirstNavigationFeatureProfile(route.domFirstFeatures)!;
  final applicationProfile = route.applicationRuntimeHandoffProfile;
  if (applicationProfile == null) return featureProfile;
  return '$featureProfile.application.${applicationProfile.kind}.'
      '${applicationProfile.id}';
}

/// Returns the stable profile represented by a compatible [features] set.
String? seoDomFirstNavigationFeatureProfile(
  Set<SeoDomFirstFeature> features,
) {
  if (features.contains(SeoDomFirstFeature.prefetch) &&
      !features.contains(SeoDomFirstFeature.navigation)) {
    throw StateError('DOM-first prefetch requires navigation');
  }
  if (features.contains(SeoDomFirstFeature.runtimeHandoff) &&
      !features.contains(SeoDomFirstFeature.navigation)) {
    throw StateError('DOM-first runtime handoff requires navigation');
  }
  if (features.contains(SeoDomFirstFeature.applicationRuntimeHandoff) &&
      !features.contains(SeoDomFirstFeature.navigation)) {
    throw StateError(
      'DOM-first application runtime handoff requires navigation',
    );
  }
  if (!features.contains(SeoDomFirstFeature.navigation)) return null;
  if (!isSeoDomFirstNavigationFeatureProfile(features)) {
    throw StateError('Invalid DOM-first navigation feature profile');
  }
  final names = features
      .where(
        (feature) =>
            feature != SeoDomFirstFeature.collection ||
            !features.contains(SeoDomFirstFeature.runtimeHandoff),
      )
      .map((feature) => feature.name)
      .toList()
    ..sort();
  return names.join('.');
}

SeoDomFirstNavigationRuntimeEntry? _packageHandoffRuntime(SeoRoute route) {
  if (!route.domFirstFeatures.contains(SeoDomFirstFeature.runtimeHandoff) ||
      !route.domFirstFeatures.contains(SeoDomFirstFeature.collection)) {
    return null;
  }
  return SeoDomFirstNavigationRuntimeEntry(
    kind: seoDomFirstCollectionRuntimeKind,
    sha256: seoDomFirstCollectionHandoffRuntimeSha256,
    bytes: seoDomFirstCollectionHandoffRuntimeBytes,
  );
}

SeoDomFirstNavigationRuntimeEntry? _applicationHandoffRuntime(
  SeoRoute route,
  Map<SeoDomFirstApplicationRuntime, SeoDomFirstNavigationRuntimeEntry>
      runtimes,
) {
  if (!route.domFirstFeatures
      .contains(SeoDomFirstFeature.applicationRuntimeHandoff)) {
    return null;
  }
  final reference = route.applicationRuntime;
  if (reference == null) return null;
  final runtime = runtimes[reference];
  if (runtime == null) {
    throw ArgumentError.value(
      reference,
      'applicationRuntimes',
      'is missing from the verified application handoff snapshot',
    );
  }
  return runtime;
}

void _validateApplicationHandoffProfile(
  List<SeoRoute> routes,
  Map<SeoDomFirstApplicationRuntime, SeoDomFirstNavigationRuntimeEntry>
      runtimes,
  String profile, {
  required bool typed,
}) {
  final references = <SeoDomFirstApplicationRuntime>{};
  final profileReferences = <SeoDomFirstApplicationRuntime>{};
  for (final route in routes) {
    if (!route.domFirstFeatures
            .contains(SeoDomFirstFeature.applicationRuntimeHandoff) ||
        seoDomFirstNavigationProfile(route) != profile) {
      continue;
    }
    final profileReference = route.applicationRuntimeHandoffProfile;
    if (profileReference != null) profileReferences.add(profileReference);
    final reference = route.applicationRuntime;
    if (reference != null) references.add(reference);
  }
  if (typed && profileReferences.length != 1) {
    throw ArgumentError.value(
      profileReferences,
      'routes',
      'an explicit applicationRuntimeHandoff profile must bind one runtime '
          'reference on every compatible route',
    );
  }
  if (references.length > 1) {
    throw ArgumentError.value(
      references,
      'routes',
      'applicationRuntimeHandoff supports one distinct runtime per profile',
    );
  }
  if (typed &&
      references.any((reference) => !profileReferences.contains(reference))) {
    throw ArgumentError.value(
      references,
      'routes',
      'active runtimes must equal the explicit handoff profile reference',
    );
  }
  final admitted = {...references, ...profileReferences};
  for (final reference in admitted) {
    final allowed = typed
        ? reference is SeoDomFirstCollectionApplicationRuntime ||
            reference is SeoDomFirstConfiguratorApplicationRuntime ||
            reference is SeoDomFirstEditorialWorkflowApplicationRuntime
        : reference is SeoDomFirstCollectionApplicationRuntime;
    if (!allowed) {
      throw ArgumentError.value(
        reference,
        'routes',
        typed
            ? 'typed applicationRuntimeHandoff supports only collection, '
                'configurator or editorial-workflow runtimes'
            : 'implicit applicationRuntimeHandoff supports only collection '
                'runtimes',
      );
    }
    final runtime = runtimes[reference];
    if (runtime == null ||
        !runtime.isApplication ||
        runtime.applicationId != reference.id ||
        runtime.kind != reference.kind ||
        runtime.contractRevision == null ||
        runtime.contractRevision! < 1 ||
        !_sha256.hasMatch(runtime.sha256) ||
        runtime.bytes < 1 ||
        runtime.bytes > seoDomFirstApplicationHandoffRuntimeMaxBytes) {
      throw ArgumentError.value(
        runtime,
        'applicationRuntimes',
        'must contain the matching verified application runtime descriptor',
      );
    }
  }
}

SeoDomFirstNavigationRuntimeEntry? _applicationHandoffProfileRuntime(
  List<SeoRoute> routes,
  Map<SeoDomFirstApplicationRuntime, SeoDomFirstNavigationRuntimeEntry>
      runtimes,
  String profile, {
  required bool typed,
}) {
  SeoDomFirstApplicationRuntime? reference;
  for (final route in routes) {
    if (seoDomFirstNavigationProfile(route) != profile) continue;
    final candidate = typed
        ? route.applicationRuntimeHandoffProfile
        : route.applicationRuntime;
    if (candidate != null) {
      reference = candidate;
      break;
    }
  }
  return reference == null ? null : runtimes[reference];
}

String _decodedNormalizedPath(String raw) {
  final segments = <String>[];
  final rawSegments = raw.split('/');
  for (final (index, segment) in rawSegments.indexed) {
    if (segment.isEmpty && index != 0 && index != rawSegments.length - 1) {
      throw ArgumentError.value(
        raw,
        'siteBase',
        'contains an empty path segment',
      );
    }
    late final String decoded;
    try {
      decoded = Uri.decodeComponent(segment);
    } on FormatException {
      throw ArgumentError.value(raw, 'siteBase', 'contains invalid escapes');
    } on ArgumentError {
      throw ArgumentError.value(raw, 'siteBase', 'contains invalid escapes');
    }
    if (decoded == '.' ||
        decoded == '..' ||
        decoded.contains('/') ||
        decoded.contains(r'\')) {
      throw ArgumentError.value(
        raw,
        'siteBase',
        'contains an ambiguous path segment',
      );
    }
    segments.add(decoded);
  }
  var path = segments.join('/');
  if (!path.startsWith('/')) path = '/$path';
  while (path.length > 1 && path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }
  return path.isEmpty ? '/' : path;
}

String _rawPath(String absoluteUrl) {
  final authorityStart = absoluteUrl.indexOf('://') + 3;
  final pathStart = absoluteUrl.indexOf('/', authorityStart);
  return pathStart < 0 ? '' : absoluteUrl.substring(pathStart);
}

bool _invalidNavigationPattern(String path) {
  for (final segment in path.split('/')) {
    try {
      final decoded = Uri.decodeComponent(segment);
      if (decoded == '.' ||
          decoded == '..' ||
          decoded.contains(r'\') ||
          _unsafeManifestText(decoded)) {
        return true;
      }
    } on FormatException {
      return true;
    } on ArgumentError {
      return true;
    }
  }
  return false;
}

bool _unsafeManifestText(String value) => value.codeUnits.any(
      (unit) =>
          unit < 0x20 ||
          unit == 0x7f ||
          unit == 0x061c ||
          unit == 0x200e ||
          unit == 0x200f ||
          (unit >= 0x202a && unit <= 0x202e) ||
          (unit >= 0x2066 && unit <= 0x2069),
    );

final RegExp _sha256 = RegExp(r'^[a-f0-9]{64}$');

String _scriptSafeJson(String value) => value
    .replaceAll('&', r'\u0026')
    .replaceAll('<', r'\u003c')
    .replaceAll('>', r'\u003e')
    .replaceAll('\u2028', r'\u2028')
    .replaceAll('\u2029', r'\u2029');
