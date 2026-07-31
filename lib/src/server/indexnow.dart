import 'dart:convert';
import 'dart:io';

import '../routing/seo_route.dart';

/// Submits URLs to search engines via the IndexNow protocol
/// (https://www.indexnow.org — Bing, Seznam, Naver, Yandex share the
/// index; Google crawls the classic way via sitemap).
///
/// Instead of waiting days for a recrawl, you push changed pages
/// actively — typically right after a deploy or prerender run:
///
/// ```dart
/// await submitIndexNow(
///   siteBase: 'https://example.com',
///   key: 'a1b2c3d4e5f6...',
///   paths: ['/', '/blog/neuer-post'],
/// );
/// ```
///
/// [key] is a self-chosen hex/alphanumeric string (8–128 chars) that
/// must be reachable as `https://example.com/<key>.txt` containing the
/// key — `seoBotMiddleware(indexNowKey: ...)` and
/// `prerenderSite(indexNowKey: ...)` serve/write that file for you.
///
/// Returns `true` when the endpoint accepted the submission (HTTP
/// 200/202). Network errors surface as exceptions — decide at the call
/// site whether a failed ping may fail the deploy.
Future<bool> submitIndexNow({
  required String siteBase,
  required String key,
  required List<String> paths,
  Uri? endpoint,
  String? keyLocation,
}) async {
  if (paths.isEmpty) return true;
  final base = siteBase.endsWith('/')
      ? siteBase.substring(0, siteBase.length - 1)
      : siteBase;
  final host = Uri.parse(base).host;
  final urls = [
    for (final path in paths.map(normalizeSeoPath))
      path == '/' ? '$base/' : '$base$path',
  ];

  final body = jsonEncode({
    'host': host,
    'key': key,
    'keyLocation': keyLocation ?? '$base/$key.txt',
    'urlList': urls,
  });

  final client = HttpClient();
  try {
    final request = await client
        .postUrl(endpoint ?? Uri.parse('https://api.indexnow.org/indexnow'));
    request.headers.contentType =
        ContentType('application', 'json', charset: 'utf-8');
    request.write(body);
    final response = await request.close();
    await response.drain<void>();
    return response.statusCode == 200 || response.statusCode == 202;
  } finally {
    client.close();
  }
}
