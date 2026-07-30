/// Detects crawlers and preview bots by their User-Agent header.
///
/// ```dart
/// const detector = BotDetector();
/// detector.isBot('Googlebot/2.1 (+http://www.google.com/bot.html)'); // true
/// detector.isBot('Mozilla/5.0 ... Chrome/126.0 Safari/537.36');      // false
/// ```
class BotDetector {
  /// Uses [defaultPatterns], optionally extended with [extraPatterns].
  const BotDetector({List<String> extraPatterns = const []})
      : _extra = extraPatterns,
        _override = null;

  /// Uses only [patterns] and ignores [defaultPatterns] completely.
  const BotDetector.only(List<String> patterns)
      : _extra = const [],
        _override = patterns;

  final List<String> _extra;
  final List<String>? _override;

  /// Lower-case User-Agent fragments of the crawlers that matter for SEO:
  /// search engines, social-media link previews and AI crawlers, plus a
  /// few generic markers.
  static const List<String> defaultPatterns = [
    // Suchmaschinen
    'googlebot', 'googleother', 'bingbot', 'duckduckbot', 'applebot',
    'yandex', 'baiduspider', 'petalbot', 'seznambot',
    // Social-Media Link-Vorschauen
    'facebookexternalhit', 'facebookcatalog', 'twitterbot', 'linkedinbot',
    'pinterestbot', 'whatsapp', 'telegrambot', 'slackbot', 'discordbot',
    'redditbot',
    // AI-Crawler
    'gptbot', 'oai-searchbot', 'chatgpt-user', 'claudebot', 'claude-web',
    'perplexitybot', 'google-extended', 'ccbot', 'bytespider',
    // SEO-Tools und generische Marker
    'lighthouse', 'ahrefsbot', 'semrushbot', 'screaming frog',
    'crawler', 'spider', 'slurp', 'bot/', 'bot;', 'bot)',
  ];

  /// Alle [defaultPatterns] als eine vorkompilierte Alternation —
  /// ein Regex-Scan pro Request statt ~40 `contains`-Durchläufen.
  static final RegExp _defaultMatcher =
      RegExp(defaultPatterns.map(RegExp.escape).join('|'));

  /// Whether [userAgent] belongs to a known crawler.
  ///
  /// `null` or empty User-Agents count as regular users, so real visitors
  /// never accidentally get the bot response.
  bool isBot(String? userAgent) {
    if (userAgent == null || userAgent.isEmpty) return false;
    final ua = userAgent.toLowerCase();
    final override = _override;
    if (override != null) return override.any(ua.contains);
    return _defaultMatcher.hasMatch(ua) ||
        _extra.any((pattern) => ua.contains(pattern.toLowerCase()));
  }
}
