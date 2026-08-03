import 'seo_finding.dart';

/// The result of one audit run.
class SeoAuditReport {
  SeoAuditReport({
    required List<SeoFinding> findings,
    required this.pagesAudited,
    this.partial = false,
  }) : findings = List.unmodifiable(_sorted(findings));

  /// Every finding, ordered by severity and then by page, so the output
  /// reads worst-first rather than in whatever order the checks ran.
  final List<SeoFinding> findings;

  /// How many concrete URLs were inspected.
  final int pagesAudited;

  /// Whether some pages could not be resolved and are missing from the
  /// run.
  ///
  /// This matters beyond a warning: cross-page checks (duplicate titles,
  /// hreflang reciprocity, broken internal links) reason about the whole
  /// set, so with a page missing they can be confidently wrong. When
  /// this is `true` those checks are skipped rather than guessed at.
  final bool partial;

  int get errorCount =>
      findings.where((f) => f.severity == SeoSeverity.error).length;
  int get warningCount =>
      findings.where((f) => f.severity == SeoSeverity.warning).length;
  int get infoCount =>
      findings.where((f) => f.severity == SeoSeverity.info).length;

  /// Whether the site passes at [threshold] — nothing at that severity
  /// or worse.
  bool passes({SeoSeverity threshold = SeoSeverity.error}) =>
      !findings.any((f) => f.severity.index <= threshold.index);

  Map<String, Object?> toJson() => {
        'pagesAudited': pagesAudited,
        'partial': partial,
        'errors': errorCount,
        'warnings': warningCount,
        'infos': infoCount,
        'findings': [for (final f in findings) f.toJson()],
      };

  /// A human-readable report, grouped by page.
  String describe() {
    final buffer = StringBuffer();
    if (findings.isEmpty) {
      buffer.writeln('esen_seo audit: $pagesAudited pages, no findings.');
      if (partial) {
        buffer.writeln(
          'WARNING: some pages failed to resolve, so cross-page checks '
          'were skipped. This is not a clean bill of health.',
        );
      }
      return buffer.toString();
    }

    buffer.writeln('esen_seo audit: $pagesAudited pages, '
        '$errorCount error(s), $warningCount warning(s), $infoCount info.');
    if (partial) {
      buffer.writeln(
        'WARNING: some pages failed to resolve — cross-page checks '
        '(duplicate titles, hreflang, internal links) were skipped.',
      );
    }
    buffer.writeln();

    // Site-wide findings first, then page by page.
    final siteWide = findings.where((f) => f.path == null).toList();
    if (siteWide.isNotEmpty) {
      buffer.writeln('site:');
      for (final f in siteWide) {
        buffer.writeln('  ${_line(f)}');
      }
      buffer.writeln();
    }

    final byPath = <String, List<SeoFinding>>{};
    for (final f in findings) {
      if (f.path != null) byPath.putIfAbsent(f.path!, () => []).add(f);
    }
    final paths = byPath.keys.toList()..sort();
    for (final path in paths) {
      buffer.writeln('$path:');
      for (final f in byPath[path]!) {
        buffer.writeln('  ${_line(f)}');
      }
      buffer.writeln();
    }
    return buffer.toString();
  }

  static String _line(SeoFinding f) {
    final mark = switch (f.severity) {
      SeoSeverity.error => 'x',
      SeoSeverity.warning => '!',
      SeoSeverity.info => 'i',
    };
    final detail = f.detail == null ? '' : ' (${f.detail})';
    return '$mark ${f.check.id}  ${f.message}$detail';
  }

  static List<SeoFinding> _sorted(List<SeoFinding> input) {
    final list = [...input];
    list.sort((a, b) {
      final bySeverity = a.severity.index.compareTo(b.severity.index);
      if (bySeverity != 0) return bySeverity;
      final byPath = (a.path ?? '').compareTo(b.path ?? '');
      if (byPath != 0) return byPath;
      return a.check.id.compareTo(b.check.id);
    });
    return list;
  }

  @override
  String toString() => describe();
}
