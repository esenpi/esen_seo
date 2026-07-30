/// Typed HTML tags for the `.seo()` extensions.
///
/// The IDE suggests the matching constants per widget type — `SeoTextTag`
/// on [Text], `SeoContainerTag` on [Column]/[Row] — so tags are
/// autocompleted and typos become compile errors instead of silent
/// fallbacks:
///
/// ```dart
/// Text('Willkommen').seo(SeoTextTag.h1);
/// Column(children: [...]).seo(SeoContainerTag.section);
/// ```
///
/// Exotic or custom-element tags stay possible through the constructor:
/// `SeoTextTag('bdo')`, `SeoContainerTag('my-widget')`. Those go through
/// the same runtime tag policy as before (blocked tags fall back safely).
///
/// Both types are extension types over [String] — zero runtime cost.
library;

/// An HTML tag for text content, e.g. on `Text('...').seo(...)`.
extension type const SeoTextTag(String name) {
  // Überschriften
  static const h1 = SeoTextTag('h1');
  static const h2 = SeoTextTag('h2');
  static const h3 = SeoTextTag('h3');
  static const h4 = SeoTextTag('h4');
  static const h5 = SeoTextTag('h5');
  static const h6 = SeoTextTag('h6');

  // Fließtext
  static const p = SeoTextTag('p');
  static const span = SeoTextTag('span');
  static const blockquote = SeoTextTag('blockquote');
  static const q = SeoTextTag('q');
  static const cite = SeoTextTag('cite');
  static const figcaption = SeoTextTag('figcaption');
  static const caption = SeoTextTag('caption');
  static const label = SeoTextTag('label');
  static const legend = SeoTextTag('legend');
  static const summary = SeoTextTag('summary');
  static const time = SeoTextTag('time');
  static const address = SeoTextTag('address');

  // Listen und Tabellen
  static const li = SeoTextTag('li');
  static const dt = SeoTextTag('dt');
  static const dd = SeoTextTag('dd');
  static const td = SeoTextTag('td');
  static const th = SeoTextTag('th');

  // Hervorhebungen
  static const strong = SeoTextTag('strong');
  static const em = SeoTextTag('em');
  static const mark = SeoTextTag('mark');
  static const small = SeoTextTag('small');
  static const del = SeoTextTag('del');
  static const ins = SeoTextTag('ins');
  static const sub = SeoTextTag('sub');
  static const sup = SeoTextTag('sup');
  static const abbr = SeoTextTag('abbr');

  // Code
  static const code = SeoTextTag('code');
  static const pre = SeoTextTag('pre');
  static const kbd = SeoTextTag('kbd');
  static const samp = SeoTextTag('samp');
}

/// An HTML tag for container elements, e.g. on
/// `Column(children: [...]).seo(...)`.
extension type const SeoContainerTag(String name) {
  // Generisch
  static const div = SeoContainerTag('div');

  // Semantische Landmarken
  static const main = SeoContainerTag('main');
  static const header = SeoContainerTag('header');
  static const footer = SeoContainerTag('footer');
  static const nav = SeoContainerTag('nav');
  static const section = SeoContainerTag('section');
  static const article = SeoContainerTag('article');
  static const aside = SeoContainerTag('aside');
  static const search = SeoContainerTag('search');
  static const hgroup = SeoContainerTag('hgroup');

  // Listen
  static const ul = SeoContainerTag('ul');
  static const ol = SeoContainerTag('ol');
  static const dl = SeoContainerTag('dl');
  static const menu = SeoContainerTag('menu');

  // Tabellen
  static const table = SeoContainerTag('table');
  static const thead = SeoContainerTag('thead');
  static const tbody = SeoContainerTag('tbody');
  static const tfoot = SeoContainerTag('tfoot');
  static const tr = SeoContainerTag('tr');

  // Sonstige Gruppierung
  static const figure = SeoContainerTag('figure');
  static const details = SeoContainerTag('details');
  static const fieldset = SeoContainerTag('fieldset');
  static const blockquote = SeoContainerTag('blockquote');
}
