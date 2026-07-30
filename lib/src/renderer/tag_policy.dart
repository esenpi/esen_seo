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
/// execute JavaScript when injected into the DOM), invalid attribute
/// names and executable URL schemes (`javascript:`, `data:text/html`)
/// in URL attributes. Everything else — `id`, `lang`, `datetime`,
/// `cite`, `class`, `data-*`, `aria-*`, … — is allowed.
bool isAllowedSeoAttribute(String name, String value) {
  if (!_validAttributeName.hasMatch(name)) return false;
  if (name.startsWith('on')) return false;
  if (_urlAttributes.contains(name)) {
    final v = value.trim().toLowerCase();
    if (v.startsWith('javascript:') ||
        v.startsWith('vbscript:') ||
        v.startsWith('data:text/html')) {
      return false;
    }
  }
  return true;
}
