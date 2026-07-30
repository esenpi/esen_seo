/// Shorthand getters for the most common tags — `.h1` instead of
/// `.seo(SeoTextTag.h1)`:
///
/// ```dart
/// Text('Willkommen').h1;                // → <h1>Willkommen</h1>
/// Text('Ein Absatz').p;                 // → <p>Ein Absatz</p>
/// Column(children: [...]).ul;           // → <ul>...</ul>
/// ```
///
/// Every shorthand simply forwards to `.seo(...)` — for all other
/// tags and attributes keep using `.seo()` directly.
library;

import 'package:flutter/widgets.dart';

import '../tags/seo_tags.dart';
import 'column_seo.dart';
import 'row_seo.dart';
import 'text_seo.dart';

/// Tag shorthands on [Text].
extension TextSeoTags on Text {
  /// `<h1>` — die Hauptüberschrift der Seite.
  Widget get h1 => seo(SeoTextTag.h1);

  /// `<h2>`
  Widget get h2 => seo(SeoTextTag.h2);

  /// `<h3>`
  Widget get h3 => seo(SeoTextTag.h3);

  /// `<h4>`
  Widget get h4 => seo(SeoTextTag.h4);

  /// `<h5>`
  Widget get h5 => seo(SeoTextTag.h5);

  /// `<h6>`
  Widget get h6 => seo(SeoTextTag.h6);

  /// `<p>` — ein Absatz.
  Widget get p => seo(SeoTextTag.p);

  /// `<span>` — neutraler Inline-Text.
  Widget get span => seo(SeoTextTag.span);

  /// `<li>` — ein Listeneintrag (Eltern-Column: `.ul` oder `.ol`).
  Widget get li => seo(SeoTextTag.li);

  /// `<blockquote>` — ein Zitat.
  Widget get blockquote => seo(SeoTextTag.blockquote);

  /// `<code>` — Code-Text.
  Widget get code => seo(SeoTextTag.code);
}

/// Tag shorthands on [Column].
extension ColumnSeoTags on Column {
  /// `<section>`
  Widget get section => seo(SeoContainerTag.section);

  /// `<article>`
  Widget get article => seo(SeoContainerTag.article);

  /// `<nav>`
  Widget get nav => seo(SeoContainerTag.nav);

  /// `<aside>`
  Widget get aside => seo(SeoContainerTag.aside);

  /// `<header>`
  Widget get header => seo(SeoContainerTag.header);

  /// `<footer>`
  Widget get footer => seo(SeoContainerTag.footer);

  /// `<main>` — der Hauptinhalt, einmal pro Seite.
  Widget get main => seo(SeoContainerTag.main);

  /// `<ul>` — ungeordnete Liste (Kinder: `.li`).
  Widget get ul => seo(SeoContainerTag.ul);

  /// `<ol>` — geordnete Liste (Kinder: `.li`).
  Widget get ol => seo(SeoContainerTag.ol);

  /// `<figure>`
  Widget get figure => seo(SeoContainerTag.figure);
}

/// Tag shorthands on [Row].
extension RowSeoTags on Row {
  /// `<nav>`
  Widget get nav => seo(SeoContainerTag.nav);

  /// `<header>`
  Widget get header => seo(SeoContainerTag.header);

  /// `<footer>`
  Widget get footer => seo(SeoContainerTag.footer);

  /// `<ul>` — z.B. für eine horizontale Navigationsliste.
  Widget get ul => seo(SeoContainerTag.ul);

  /// `<tr>` — eine Tabellenzeile (Zellen: `.seo(SeoTextTag.td)`).
  Widget get tr => seo(SeoContainerTag.tr);
}
