const _pageExtensions = <String>{
  'asp',
  'aspx',
  'cfm',
  'htm',
  'html',
  'jsp',
  'php',
  'xhtml',
};

final RegExp _versionSegment = RegExp(
  r'^v?\d+(?:\.\d+)+(?:[-+][a-z0-9.-]+)?$',
  caseSensitive: false,
);

/// Whether [path] is expected to represent a page rather than a static asset.
///
/// A dot alone is not enough to identify an asset: `.html` pages and slugs
/// such as `/releases/v1.2` are valid page URLs. Conversely, static downloads
/// may have any extension, so only known page extensions and version-shaped
/// segments override the conservative asset fallthrough.
bool looksLikeSeoPagePath(String path) {
  final segment = path.split('/').last.toLowerCase();
  final dot = segment.lastIndexOf('.');
  if (dot < 0) return true;
  if (dot == 0 || dot == segment.length - 1) return false;
  return _pageExtensions.contains(segment.substring(dot + 1)) ||
      _versionSegment.hasMatch(segment);
}
