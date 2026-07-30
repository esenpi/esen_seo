// Micro-benchmark for esen_seo's hot paths. Reproduce with:
//
//   dart run benchmark/hot_paths.dart
//
// Numbers vary by machine — treat them as ballpark, not gospel.
// ignore_for_file: avoid_print
import 'package:esen_seo/server.dart';

SeoNode _tree(int depth, int breadth) {
  if (depth == 0) {
    return SeoNode(tag: 'p', text: 'A paragraph with text & a few words');
  }
  return SeoNode(
    tag: 'section',
    attributes: {'id': 'sec-$depth', 'lang': 'en'},
    children: [
      SeoNode(tag: 'h2', text: 'Heading $depth'),
      for (var i = 0; i < breadth; i++) _tree(depth - 1, breadth),
    ],
  );
}

void main() {
  final tree = _tree(4, 7); // ~2,800 nodes
  const renderer = HtmlRenderer();
  const detector = BotDetector();
  final routes = [
    for (var i = 0; i < 20; i++)
      SeoRoute(path: '/page$i', meta: (_) => const SeoMeta(title: 'x')),
    SeoRoute(path: '/blog/:slug', meta: (_) => const SeoMeta(title: 'x')),
  ];
  const userAgent =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36';
  const botAgent = 'Mozilla/5.0 (compatible; Googlebot/2.1)';

  // Checksum keeps the optimizer honest and proves identical output
  // across runs and refactorings.
  var checksum = 0;

  // Warmup.
  for (var i = 0; i < 20; i++) {
    checksum += renderer.render([tree]).length;
  }

  var sw = Stopwatch()..start();
  const renders = 200;
  for (var i = 0; i < renders; i++) {
    checksum += renderer.render([tree]).length;
  }
  sw.stop();
  print('render ~2,800-node tree : '
      '${(sw.elapsedMicroseconds / renders).toStringAsFixed(0)} µs/render');

  sw = Stopwatch()..start();
  const iterations = 500000;
  for (var i = 0; i < iterations; i++) {
    if (detector.isBot(userAgent)) checksum++;
    if (detector.isBot(botAgent)) checksum++;
  }
  sw.stop();
  print('BotDetector.isBot       : '
      '${(sw.elapsedMicroseconds * 1000 / (iterations * 2)).toStringAsFixed(0)} ns/check');

  sw = Stopwatch()..start();
  const lookups = 200000;
  for (var i = 0; i < lookups; i++) {
    checksum += matchSeoRoute(routes, '/blog/my-article-$i') == null ? 0 : 1;
    checksum += matchSeoRoute(routes, '/missing') == null ? 1 : 0;
  }
  sw.stop();
  print('route match (21 routes) : '
      '${(sw.elapsedMicroseconds * 1000 / (lookups * 2)).toStringAsFixed(0)} ns/lookup');

  print('(checksum: $checksum)');
}
