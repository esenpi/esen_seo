/// Which HTML tags the `.seo()` extensions accept.
///
/// Every standard HTML tag (and custom elements like `my-widget`) is
/// allowed. Blocked are only tags that would execute code, load active
/// content or break the document when injected (`script`, `iframe`, …) —
/// head-only tags like `title` and `meta` are managed through `SeoMeta`.
library;

/// Tags that must never enter the SEO tree.
const Set<String> blockedSeoTags = {
  // Executes code or loads active content when inserted into the DOM.
  'script', 'style', 'iframe', 'object', 'embed', 'applet',
  // Document structure that exists exactly once per page.
  'html', 'head', 'body',
  // Head-only tags, managed through SeoMeta / EsenSeo.setMeta.
  'title', 'meta', 'link', 'base',
  // No visible content model.
  'noscript', 'template', 'slot', 'frame', 'frameset',
};

final RegExp _validTagName = RegExp(r'^[a-z][a-z0-9-]*$');

/// Returns the normalized (lower-cased, trimmed) tag, or `null` when the
/// tag is blocked or not a valid element name.
///
/// Invalid names matter: `document.createElement` throws on them, and the
/// page must keep rendering no matter what (SeoMode.safe philosophy) — the
/// caller falls back to a neutral tag instead.
String? normalizeSeoTag(String tag) {
  final normalized = tag.trim().toLowerCase();
  if (!_validTagName.hasMatch(normalized)) return null;
  if (blockedSeoTags.contains(normalized)) return null;
  return normalized;
}

final RegExp _validAttributeName = RegExp(r'^[a-z][a-z0-9-]*$');

/// C0 controls and DEL — stripped or ignored by URL parsers, so they
/// can hide an executable scheme from a plain prefix comparison.
final RegExp _urlControlCharacters = RegExp(r'[\x00-\x1F\x7F]');

/// The schemes a URL attribute may carry.
///
/// Deliberately an allow list. A block list has to name every dangerous
/// scheme and loses the moment one is missed or disguised — which is
/// exactly how a tab hidden inside `javascript:` once slipped through.
/// Anything not named here is refused, so a new trick is powerless by
/// construction rather than by us having thought of it.
const Set<String> _allowedUrlSchemes = {
  'http',
  'https',
  'mailto',
  'tel',
  'sms',
  'ftp',
};

/// Matches a leading `scheme:` per RFC 3986 — letter, then letters,
/// digits, `+`, `-`, `.`.
final RegExp _urlScheme = RegExp(r'^([a-z][a-z0-9+\-.]*):');

/// Attributes whose values are URLs — those must not smuggle in
/// executable schemes.
const Set<String> _urlAttributes = {
  'href',
  'src',
  'srcset',
  'cite',
  'action',
  'formaction',
  'poster',
  'data',
};

/// Whether the (already lower-cased) attribute [name]/[value] pair may
/// enter the SEO tree.
///
/// Blocked are event handlers (`onclick`, `onerror`, … — they would
/// execute JavaScript when injected into the DOM) and invalid attribute
/// names. Everything else — `id`, `lang`, `datetime`, `cite`, `class`,
/// `data-*`, `aria-*`, … — is allowed.
///
/// URL attributes are held to a stricter rule, because their value is
/// something the browser acts on: relative URLs pass, absolute ones
/// only with a scheme from [_allowedUrlSchemes], and any value carrying
/// control characters is refused outright. Browsers strip tab, newline
/// and carriage return while parsing a URL, so those characters can
/// hide a scheme from a naive comparison — and an unknown scheme is
/// refused anyway.
bool isAllowedSeoAttribute(String name, String value) {
  if (!_validAttributeName.hasMatch(name)) return false;
  if (name.startsWith('on')) return false;
  if (_urlAttributes.contains(name)) return _isAllowedUrl(value);
  return true;
}

/// Whether [value] is a URL the browser may safely act on.
bool _isAllowedUrl(String value) {
  if (_urlControlCharacters.hasMatch(value)) return false;
  final url = value.trim().toLowerCase();
  final scheme = _urlScheme.firstMatch(url)?.group(1);
  // Kein Schema heißt relativ (`/blog`, `bild.png`, `#anker`,
  // `//cdn.example.com`) — das kann nichts ausführen.
  if (scheme == null) return true;
  return _allowedUrlSchemes.contains(scheme);
}
