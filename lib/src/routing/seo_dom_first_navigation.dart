/// Pure route manifest for the profile-bound DOM-first navigation pilot.
library;

import 'dart:convert';

export '../renderer/seo_container.dart' show seoDomFirstNavigationHeadAttribute;

import 'seo_route.dart';
import 'seo_route_delivery.dart';

const int seoDomFirstNavigationManifestSchema = 1;
const int seoDomFirstNavigationMaxRoutes = 256;
const int seoDomFirstNavigationMaxPatternLength = 256;
const int seoDomFirstNavigationMaxManifestBytes = 32768;
const String seoDomFirstNavigationManifestAttribute =
    'data-esen-seo-navigation-manifest';

/// One ordered route-pattern entry in a DOM-first navigation manifest.
final class SeoDomFirstNavigationEntry {
  const SeoDomFirstNavigationEntry({required this.pattern, this.profile});

  final String pattern;
  final String? profile;
}

/// The package-owned route information embedded in one navigable document.
final class SeoDomFirstNavigationPlan {
  const SeoDomFirstNavigationPlan._({
    required this.basePath,
    required this.profile,
    required this.entries,
    required this.manifestJson,
  });

  /// Decoded deployment prefix, `/` for an origin-root deployment.
  final String basePath;

  /// Exact runtime profile required for an in-document replacement.
  final String profile;

  /// Route patterns in their server declaration order.
  final List<SeoDomFirstNavigationEntry> entries;

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
}) {
  final profile = seoDomFirstNavigationProfile(currentRoute);
  if (profile == null) return null;
  if (routes.length > seoDomFirstNavigationMaxRoutes) {
    throw ArgumentError.value(
      routes.length,
      'routes',
      'navigation supports at most $seoDomFirstNavigationMaxRoutes routes',
    );
  }
  if (!routes.any((route) => identical(route, currentRoute))) {
    throw ArgumentError.value(
      currentRoute,
      'currentRoute',
      'must be the route instance contained in routes',
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
      ),
    );
  }
  final encoded = jsonEncode({
    'schema': seoDomFirstNavigationManifestSchema,
    'base': basePath,
    'profile': profile,
    'routes': [
      for (final entry in entries) [entry.pattern, entry.profile],
    ],
  });
  final bytes = utf8.encode(encoded).length;
  if (bytes > seoDomFirstNavigationMaxManifestBytes) {
    throw ArgumentError.value(
      bytes,
      'routes',
      'navigation manifest exceeds $seoDomFirstNavigationMaxManifestBytes '
          'UTF-8 bytes',
    );
  }
  return SeoDomFirstNavigationPlan._(
    basePath: basePath,
    profile: profile,
    entries: List.unmodifiable(entries),
    manifestJson: _scriptSafeJson(encoded),
  );
}

/// Returns the exact compatible runtime profile, or `null` when navigation is
/// disabled for [route].
String? seoDomFirstNavigationProfile(SeoRoute route) {
  if (!route.domFirstFeatures.contains(SeoDomFirstFeature.navigation)) {
    return null;
  }
  if (!route.isDomFirst || route.applicationRuntime != null) {
    throw StateError('Invalid DOM-first navigation route');
  }
  return seoDomFirstNavigationFeatureProfile(route.domFirstFeatures);
}

/// Returns the stable profile represented by a compatible [features] set.
String? seoDomFirstNavigationFeatureProfile(
  Set<SeoDomFirstFeature> features,
) {
  if (!features.contains(SeoDomFirstFeature.navigation)) return null;
  if (!isSeoDomFirstNavigationFeatureProfile(features)) {
    throw StateError('Invalid DOM-first navigation feature profile');
  }
  final names = features.map((feature) => feature.name).toList()..sort();
  return names.join('.');
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

String _scriptSafeJson(String value) => value
    .replaceAll('&', r'\u0026')
    .replaceAll('<', r'\u003c')
    .replaceAll('>', r'\u003e')
    .replaceAll('\u2028', r'\u2028')
    .replaceAll('\u2029', r'\u2029');
