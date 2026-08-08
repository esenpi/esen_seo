// What "kept in the tree but not shown" actually means — pinned per
// widget, because the review history here is a graveyard of wrong
// heuristics: TickerMode(enabled: false) was treated as invisible
// although Flutter defines it as "pause tickers" (visible content
// inside it vanished from the mirror), while IndexedStack's inactive
// children and Visibility(maintainSize: true) leaked INTO it.
import 'package:esen_seo/esen_seo.dart';
import 'package:esen_seo/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(enableSeoForParity);

  Future<String> mirror(WidgetTester tester, Widget body) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: body)),
    );
    await tester.pumpAndSettle();
    EsenSeo.refresh();
    return EsenSeo.currentHtml;
  }

  testWidgets(
      'TickerMode(enabled: false) pauses animations — its VISIBLE '
      'content stays in the mirror', (tester) async {
    final html = await mirror(
      tester,
      TickerMode(
        enabled: false,
        child: Text('Sichtbar trotz pausierter Ticker').h1,
      ),
    );
    expect(html, contains('Sichtbar trotz pausierter Ticker'));
  });

  testWidgets('IndexedStack mirrors only the active child', (tester) async {
    final html = await mirror(
      tester,
      IndexedStack(
        index: 1,
        children: [
          Text('Seite Null Inhalt').h1,
          Text('Seite Eins Inhalt').h1,
        ],
      ),
    );
    expect(html, contains('Seite Eins Inhalt'));
    expect(html, isNot(contains('Seite Null Inhalt')));
  });

  testWidgets(
      'Visibility(visible: false, maintainSize: true) is hidden — '
      'Opacity 0 keeps the box, not the content', (tester) async {
    final html = await mirror(
      tester,
      Column(children: [
        Text('Der sichtbare Teil').h1,
        Visibility(
          visible: false,
          maintainState: true,
          maintainAnimation: true,
          maintainSize: true,
          child: Text('Versteckt hinter Opacity null').p,
        ),
      ]),
    );
    expect(html, contains('Der sichtbare Teil'));
    expect(html, isNot(contains('Versteckt hinter Opacity null')));
  });

  testWidgets(
      'SliverVisibility(visible: false, maintainSize: true) is hidden — '
      'the box widget alone was not the class', (tester) async {
    final html = await mirror(
      tester,
      CustomScrollView(slivers: [
        SliverToBoxAdapter(child: Text('Sichtbares Sliver').h1),
        SliverVisibility(
          visible: false,
          maintainState: true,
          maintainAnimation: true,
          maintainSize: true,
          sliver: SliverToBoxAdapter(
            child: Text('Verstecktes gepflegtes Sliver').p,
          ),
        ),
      ]),
    );
    expect(html, contains('Sichtbares Sliver'));
    expect(html, isNot(contains('Verstecktes gepflegtes Sliver')));
  });

  testWidgets('Offstage stays hidden', (tester) async {
    final html = await mirror(
      tester,
      Column(children: [
        Text('Auf der Buehne').h1,
        Offstage(child: Text('Hinter der Buehne').p),
      ]),
    );
    expect(html, contains('Auf der Buehne'));
    expect(html, isNot(contains('Hinter der Buehne')));
  });

  testWidgets(
      'scrolled-away list content stays in the mirror — the '
      'viewport filter must NOT apply', (tester) async {
    // Items inside the cache extent are built but not painted. They are
    // page content a crawler must see; an onstage traversal that
    // filtered by visual visibility would silently drop them.
    final html = await mirror(
      tester,
      SizedBox(
        height: 200,
        child: ListView.builder(
          itemExtent: 100,
          itemCount: 10,
          itemBuilder: (_, i) => Text('Listeneintrag Nummer $i').p,
        ),
      ),
    );
    expect(html, contains('Listeneintrag Nummer 0'));
    // Built (default cache extent 250px reaches item 4), not visible:
    expect(html, contains('Listeneintrag Nummer 3'));
  });
}
