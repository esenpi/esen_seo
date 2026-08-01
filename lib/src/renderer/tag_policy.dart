/// Which HTML tags and attributes may enter the rendered output.
///
/// The tags a mirrored document may contain are an allow list
/// ([allowedSeoTags]): the structural, text, list, table and media
/// elements a semantic mirror is made of. Anything else — including
/// valid HTML like `<form>` or `<plaintext>`, and custom elements —
/// degrades to a neutral container. Head-only tags such as `title` and
/// `meta` are managed through `SeoMeta` and rendered by
/// `HtmlRenderer.head()`.
library;

/// The elements a mirrored document body may contain.
///
/// Deliberately an allow list. A block list has to name every dangerous
/// element and loses the moment one is missed: `<plaintext>` swallows
/// the rest of the document, `<xmp>` and `<noembed>` do the same,
/// `<form>` invites credential harvesting, and SVG's `<animate>` can
/// rewrite a link into a script URL. None of those are exotic — they
/// are simply not on this list, and that is enough.
///
/// The list covers what a semantic mirror is *for*: structure,
/// headings, text, lists, tables and media.
const Set<String> allowedSeoTags = {
  // Sectioning and grouping
  'div', 'span', 'section', 'article', 'aside', 'nav', 'header', 'footer',
  'main', 'figure', 'figcaption', 'hgroup', 'address', 'details', 'summary',
  // Headings
  'h1', 'h2', 'h3', 'h4', 'h5', 'h6',
  // Text level
  'p', 'a', 'strong', 'em', 'b', 'i', 'u', 's', 'small', 'mark', 'abbr',
  'cite', 'q', 'blockquote', 'code', 'pre', 'kbd', 'samp', 'var', 'sub',
  'sup', 'time', 'data', 'br', 'wbr', 'hr', 'ins', 'del', 'bdi', 'bdo',
  'ruby', 'rt', 'rp',
  // Lists
  'ul', 'ol', 'li', 'dl', 'dt', 'dd',
  // Tables
  'table', 'caption', 'thead', 'tbody', 'tfoot', 'tr', 'th', 'td',
  'col', 'colgroup',
  // Media and measures
  'img', 'picture', 'source', 'audio', 'video', 'track', 'progress', 'meter',
};

/// Kept for compatibility and documentation: elements that are refused
/// even though they are valid HTML. The allow list is what decides.
const Set<String> blockedSeoTags = {
  'script', 'style', 'iframe', 'object', 'embed', 'applet',
  'html', 'head', 'body',
  'title', 'meta', 'link', 'base',
  'noscript', 'template', 'slot', 'frame', 'frameset',
  // Swallow everything that follows them:
  'plaintext', 'xmp', 'noembed', 'noframes', 'listing',
  // Interactive: no SEO value, but a place to phish from.
  'form', 'input', 'button', 'select', 'option', 'textarea', 'label',
  'fieldset', 'legend', 'dialog',
  // Foreign content the mirror cannot render safely (SVG animation can
  // rewrite an href into a script URL, and the DOM injector cannot even
  // create real SVG elements).
  'svg', 'math', 'canvas', 'marquee', 'portal',
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
  return allowedSeoTags.contains(normalized) ? normalized : null;
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
  'imagesrcset',
  'cite',
  'action',
  'formaction',
  'poster',
  'data',
  // Fire a request or navigate on their own:
  'ping',
  'background',
  'longdesc',
  'manifest',
  'lowsrc',
  'dynsrc',
  'codebase',
  'archive',
  'profile',
  'usemap',
  'srcdoc',
  // `content` looks URL-ish but is prose on every meta tag that
  // matters — a description reading "Achtung: wichtig" would be read
  // as an unknown scheme and silently dropped. Its one URL use,
  // `http-equiv="refresh"`, is refused in the head renderer instead.
};

/// `srcset` holds a comma-separated candidate list, so checking the
/// whole value as one URL would let every candidate after the first
/// through unexamined.
const Set<String> _urlListAttributes = {'srcset', 'imagesrcset', 'ping'};

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
  if (_urlListAttributes.contains(name)) {
    return value
        .split(RegExp(r'[,\s]+'))
        .where((candidate) => candidate.isNotEmpty)
        // Descriptors like `2x` or `640w` are not URLs.
        .where((candidate) => !RegExp(r'^[0-9.]+[xw]$').hasMatch(candidate))
        .every(_isAllowedUrl);
  }
  if (_urlAttributes.contains(name)) return _isAllowedUrl(value);
  if (name == 'referrerpolicy') {
    return _safeReferrerPolicies.contains(value.trim().toLowerCase());
  }
  // Medien sollen nicht von selbst losspielen, wenn der Inhalt fremd ist.
  if (_mediaBehaviourAttributes.contains(name)) return false;
  if (name == 'style') return _isAllowedStyle(value);
  return true;
}

/// Referrer policies that do not hand the full URL — path and query
/// included — to a third-party host.
const Set<String> _safeReferrerPolicies = {
  'no-referrer',
  'same-origin',
  'origin',
  'strict-origin',
  'no-referrer-when-downgrade',
  'origin-when-cross-origin',
  'strict-origin-when-cross-origin',
};

/// Media attributes that start playback or prefetch on their own.
const Set<String> _mediaBehaviourAttributes = {
  'autoplay',
  'loop',
  'preload',
  'autobuffer',
};

/// CSS constructs that execute outright (legacy IE) or load a script
/// through a URL function.
final RegExp _dangerousStyle = RegExp(
  r'expression\s*\(|behavior\s*:|'
  r'url\s*\(\s*["\x27]?\s*(javascript|vbscript|data)\s*:',
  caseSensitive: false,
);

/// The CSS properties an inline style may set.
///
/// The fifth allow list in this file, and for the same reason as the
/// others: `position` alone was patched four times — `fixed`, then
/// `sticky`, then `-webkit-sticky` and `var()`, then `absolute`, then
/// `inherit` — and something got through each time. Positioning,
/// stacking and transforms are simply not on this list, so an element
/// in the mirror cannot be lifted out of the flow to cover the page.
///
/// What remains is what a document needs: type, colour, spacing,
/// borders, backgrounds and the flex/grid boxes the widget library
/// draws its charts with.
const Set<String> _allowedStyleProperties = {
  // Text
  'color', 'font', 'font-family', 'font-size', 'font-style', 'font-weight',
  'font-variant', 'letter-spacing', 'line-height', 'text-align',
  'text-decoration', 'text-transform', 'text-overflow', 'white-space',
  'word-break', 'overflow-wrap', 'hyphens', 'vertical-align', 'direction',
  'quotes', 'tab-size',
  // Box model
  'margin', 'margin-top', 'margin-right', 'margin-bottom', 'margin-left',
  'margin-inline', 'margin-block',
  'padding', 'padding-top', 'padding-right', 'padding-bottom',
  'padding-left', 'padding-inline', 'padding-block',
  'width', 'min-width', 'max-width',
  'height', 'min-height', 'max-height',
  'box-sizing', 'aspect-ratio',
  // Borders and surface
  'border', 'border-top', 'border-right', 'border-bottom', 'border-left',
  'border-color', 'border-style', 'border-width', 'border-radius',
  'background', 'background-color', 'background-image', 'background-size',
  'background-position', 'background-repeat', 'background-clip',
  'box-shadow', 'outline', 'opacity',
  // Layout boxes
  'display', 'flex', 'flex-basis', 'flex-direction', 'flex-grow',
  'flex-shrink', 'flex-wrap', 'gap', 'row-gap', 'column-gap',
  'align-items', 'align-content', 'align-self', 'justify-items',
  'justify-content', 'justify-self', 'order',
  'grid-template-columns', 'grid-template-rows', 'grid-column', 'grid-row',
  'grid-auto-flow', 'list-style', 'list-style-type', 'list-style-position',
  'table-layout', 'border-collapse', 'border-spacing', 'caption-side',
};

final RegExp _cssComment = RegExp(r'/\*.*?\*/', dotAll: true);
final RegExp _cssEscape = RegExp(r'\\');

bool _isAllowedStyle(String value) {
  // Der CSS-Parser wirft Kommentare weg, bevor er Eigenschaften liest —
  // `back/**/ground` wäre für ihn `background`. Erst entfernen.
  final normalized = value.replaceAll(_cssComment, '');
  // Backslash-Escapes aufzulösen wäre ein eigener Parser; in
  // Inline-Styles kommen sie praktisch nie vor: unbekannt heißt
  // abgelehnt.
  if (_cssEscape.hasMatch(normalized)) return false;
  if (_dangerousStyle.hasMatch(normalized)) return false;
  for (final declaration in normalized.split(';')) {
    if (declaration.trim().isEmpty) continue;
    final colon = declaration.indexOf(':');
    if (colon < 0) return false;
    final property = declaration.substring(0, colon).trim().toLowerCase();
    if (!_allowedStyleProperties.contains(property)) return false;
  }
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
