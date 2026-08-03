/// Compares what the server says a page contains with what the app
/// actually renders.
///
/// This is the check the whole approach stands or falls on. Serving
/// crawlers a separately-built HTML body is only acceptable while it
/// says the same thing the visitor sees; the moment the two drift, the
/// site is cloaking — not by intent, but because someone edited a
/// widget and forgot the route body. Nothing else in the package can
/// notice that: the two trees come from different code.
///
/// Deliberately **pure**. Capturing the app's tree needs Flutter, but
/// the comparison does not, so the interesting logic stays in plain
/// Dart where it can be tested without pumping a widget.
library;

import '../renderer/seo_node.dart';
import 'node_walk.dart';
import 'seo_finding.dart';

/// How strict the comparison is.
class SeoParityPolicy {
  const SeoParityPolicy({
    this.compareHeadings = true,
    this.compareText = true,
    this.compareLinks = false,
    this.ignoreText = const {},
  });

  /// Headings must match exactly — this is the one string both sides
  /// have to agree on.
  final bool compareHeadings;

  /// Text present on the server but missing in the app is reported.
  /// The reverse (app-only text) is only a warning: an app legitimately
  /// shows things a crawler need not see, like a cookie banner.
  final bool compareText;

  /// Off by default: navigation lives in the Flutter shell on most
  /// sites, so the app tree carries links the route body never will.
  final bool compareLinks;

  /// Text to disregard on both sides — a cookie notice, a build stamp.
  final Set<String> ignoreText;
}

/// Compares the server-rendered [ssr] body against the [app] mirror.
///
/// [path] only labels the findings.
List<SeoFinding> compareSeoTrees({
  required String path,
  required List<SeoNode> ssr,
  required List<SeoNode> app,
  SeoParityPolicy policy = const SeoParityPolicy(),
}) {
  final findings = <SeoFinding>[];
  final ssrFacts = SeoBodyFacts.of(ssr);
  final appFacts = SeoBodyFacts.of(app);

  if (policy.compareHeadings) {
    final ssrH1 = _headings(ssrFacts, 1);
    final appH1 = _headings(appFacts, 1);

    // Ask whether the server's headline appears in the app at all, not
    // whether it comes first. Comparing first-to-first failed on two
    // perfectly ordinary shapes: an app shell whose untagged brand text
    // becomes an <h1> through smart defaults, and Flutter keeping an
    // inactive Navigator route mounted after a push, so the previous
    // page's <h1> is still in the tree. Neither means the page content
    // disagrees; an extra heading is already reported separately, as a
    // warning.
    if (ssrH1.isNotEmpty && appH1.isNotEmpty && !appH1.contains(ssrH1.first)) {
      findings.add(SeoFinding(
        check: SeoCheck.parityH1Differs,
        severity: SeoSeverity.error,
        path: path,
        message: 'the server\'s <h1> appears nowhere in the app — crawlers '
            'and visitors are reading different pages',
        detail: 'server "${ssrH1.first}", app has '
            '${appH1.map((h) => '"$h"').join(', ')}',
      ));
    }

    // A heading the app shows but the server does not means the route
    // body has gone stale — the usual way this happens is someone
    // adding a section to the widget and forgetting the table.
    for (final heading in appFacts.headings) {
      if (_ignored(heading.text, policy)) continue;
      final match = ssrFacts.headings
          .any((h) => _same(h.text, heading.text) && h.level == heading.level);
      if (!match) {
        findings.add(SeoFinding(
          check: SeoCheck.parityAppOnlyHeading,
          severity: SeoSeverity.warning,
          path: path,
          message: 'the app shows a heading the server body does not — '
              'the route body has probably gone stale',
          detail: 'h${heading.level} "${heading.text}"',
        ));
      }
    }
  }

  if (policy.compareText) {
    // The cloaking direction, and the serious one: text sent only to
    // crawlers. Compared as whole words so wording that merely moved
    // between nodes does not register.
    final appWords = _words(appFacts.text);
    final missing = <String>[];
    for (final run in _textRuns(ssr)) {
      if (_ignored(run, policy)) continue;
      final words = _words(run);
      if (words.isEmpty) continue;
      if (!words.every(appWords.contains)) missing.add(run);
    }
    if (missing.isNotEmpty) {
      findings.add(SeoFinding(
        check: SeoCheck.paritySsrOnlyText,
        severity: SeoSeverity.error,
        path: path,
        message: '${missing.length} passage(s) go to crawlers but never '
            'appear in the app — this is cloaking, however accidental',
        detail: missing.take(3).map((t) => '"${_clip(t)}"').join(', '),
      ));
    }
  }

  if (policy.compareLinks) {
    final appHrefs = {
      for (final link in appFacts.links) link.attributes['href'] ?? '',
    };
    for (final link in ssrFacts.links) {
      final href = link.attributes['href'] ?? '';
      if (href.isEmpty || appHrefs.contains(href)) continue;
      findings.add(SeoFinding(
        check: SeoCheck.parityLinkMissingInApp,
        severity: SeoSeverity.info,
        path: path,
        message: 'a link exists in the server body but not in the app',
        detail: href,
      ));
    }
  }

  return findings;
}

List<String> _headings(SeoBodyFacts facts, int level) => [
      for (final h in facts.headings)
        if (h.level == level) _normalize(h.text),
    ];

/// Every text run in the tree, so a missing passage can be quoted
/// rather than reported as a diff of two giant strings.
List<String> _textRuns(List<SeoNode> nodes) {
  final runs = <String>[];
  void walk(List<SeoNode> list) {
    for (final node in list) {
      final text = node.text;
      if (text != null && text.trim().isNotEmpty) runs.add(text.trim());
      walk(node.children);
    }
  }

  walk(nodes);
  return runs;
}

Set<String> _words(String text) =>
    _normalize(text).split(' ').where((w) => w.isNotEmpty).toSet();

/// Characters that carry no meaning for this comparison.
///
/// Punctuation is the difference between a copywriter adding an
/// exclamation mark and the page actually saying something else. Curly
/// quotes, soft hyphens and non-breaking spaces belong here too — a
/// designer's typography pass must not fail the build.
final RegExp _punctuation = RegExp('[.,;:!?…"\'“”„‘’'
    '«»()\\[\\]{}­–—−-]');
final RegExp _spacing = RegExp('[\\s  ]+');

/// Whitespace, case and punctuation are not content differences.
String _normalize(String text) => text
    .replaceAll(_punctuation, ' ')
    .replaceAll(_spacing, ' ')
    .trim()
    .toLowerCase();

bool _same(String a, String b) => _normalize(a) == _normalize(b);

bool _ignored(String text, SeoParityPolicy policy) =>
    policy.ignoreText.any((i) => _normalize(text).contains(_normalize(i)));

String _clip(String text) =>
    text.length <= 60 ? text : '${text.substring(0, 57)}…';
