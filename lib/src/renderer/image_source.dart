import 'package:flutter/widgets.dart';

/// Best-effort extraction of a usable URL from an [ImageProvider].
///
/// Network images expose their URL directly. Asset images are served by
/// Flutter Web under the `assets/` path. Providers without a stable URL
/// (memory, file) return an empty string — the page must never break.
String seoImageSource(ImageProvider provider) {
  if (provider is NetworkImage) return provider.url;
  if (provider is AssetImage) return 'assets/${provider.assetName}';
  if (provider is ExactAssetImage) return 'assets/${provider.assetName}';
  if (provider is ResizeImage) return seoImageSource(provider.imageProvider);
  return '';
}
