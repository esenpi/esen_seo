import 'seo_finding.dart';

/// What the audit considers a problem.
///
/// The defaults are deliberately opinionated but not aggressive: every
/// [SeoSeverity.error] is something measurably wrong, so a team can put
/// `expectSeoHealthy(routes)` in CI on day one without a wall of
/// bikeshedding. The soft numbers — title and description length — are
/// only ever [SeoSeverity.info], because "too long" depends on the
/// language and the brand suffix.
class SeoAuditPolicy {
  const SeoAuditPolicy({
    this.ignore = const {},
    this.minTitleLength = 15,
    this.maxTitleLength = 60,
    this.minDescriptionLength = 70,
    this.maxDescriptionLength = 160,
  });

  /// Checks to skip entirely, by id.
  ///
  /// ```dart
  /// SeoAuditPolicy(ignore: {SeoCheck.titleLength})
  /// ```
  ///
  /// Prefer this over lowering a severity: a check you have decided
  /// does not apply should disappear, not become noise you learn to
  /// scroll past.
  final Set<SeoCheck> ignore;

  /// Title length that shows in full in a search result, in characters.
  /// Google truncates by pixel width, so this is a guide, not a rule —
  /// which is why it only ever produces [SeoSeverity.info].
  final int minTitleLength;
  final int maxTitleLength;

  /// The usual snippet window for a meta description.
  final int minDescriptionLength;
  final int maxDescriptionLength;

  bool isEnabled(SeoCheck check) => !ignore.contains(check);

  SeoAuditPolicy copyWith({
    Set<SeoCheck>? ignore,
    int? minTitleLength,
    int? maxTitleLength,
    int? minDescriptionLength,
    int? maxDescriptionLength,
  }) =>
      SeoAuditPolicy(
        ignore: ignore ?? this.ignore,
        minTitleLength: minTitleLength ?? this.minTitleLength,
        maxTitleLength: maxTitleLength ?? this.maxTitleLength,
        minDescriptionLength: minDescriptionLength ?? this.minDescriptionLength,
        maxDescriptionLength: maxDescriptionLength ?? this.maxDescriptionLength,
      );
}
