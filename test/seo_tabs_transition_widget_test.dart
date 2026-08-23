import 'dart:ui' show SemanticsAction, SemanticsFlag;

import 'package:esen_seo/esen_seo.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Flutter exposes tab labels as selected buttons', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SeoTabs(
          initialIndex: 1,
          tabs: [
            for (var index = 0; index < 2; index++)
              SeoTab(
                label: 'Tab $index',
                content: Text('Panel $index'),
                nodes: [SeoNode(tag: 'p', text: 'Panel $index')],
              ),
          ],
        ),
      ),
    );

    final first = tester.getSemantics(find.text('Tab 0')).getSemanticsData();
    final second = tester.getSemantics(find.text('Tab 1')).getSemanticsData();

    expect(first.label, 'Tab 0');
    expect(first.hasFlag(SemanticsFlag.isButton), isTrue);
    expect(first.hasFlag(SemanticsFlag.isSelected), isFalse);
    expect(first.hasAction(SemanticsAction.tap), isTrue);
    expect(second.label, 'Tab 1');
    expect(second.hasFlag(SemanticsFlag.isButton), isTrue);
    expect(second.hasFlag(SemanticsFlag.isSelected), isTrue);
    expect(second.hasAction(SemanticsAction.tap), isTrue);

    await tester.tap(find.text('Tab 0'));
    await tester.pump();
    expect(
      tester
          .getSemantics(find.text('Tab 0'))
          .getSemanticsData()
          .hasFlag(SemanticsFlag.isSelected),
      isTrue,
    );
    expect(
      tester
          .getSemantics(find.text('Tab 1'))
          .getSemanticsData()
          .hasFlag(SemanticsFlag.isSelected),
      isFalse,
    );
    semantics.dispose();
  });

  testWidgets('Flutter follows the shared selection transition',
      (tester) async {
    final tabs = [
      for (var index = 0; index < 3; index++)
        SeoTab(
          label: 'Tab $index',
          content: Text('Panel $index'),
          nodes: [SeoNode(tag: 'p', text: 'Panel $index')],
        ),
    ];
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SeoTabs(tabs: tabs, initialIndex: 1),
      ),
    );

    var expected = initialSeoTabsState(count: tabs.length, index: 1);
    expect(find.text('Panel ${expected.index}'), findsOneWidget);

    for (final selected in const [2, 0, 1, 1]) {
      expected = transitionSeoTabs(expected, SeoTabsSelect(selected));
      await tester.tap(find.text('Tab $selected'));
      await tester.pump();

      for (var index = 0; index < tabs.length; index++) {
        expect(
          find.text('Panel $index'),
          index == expected.index ? findsOneWidget : findsNothing,
        );
      }
    }
  });

  testWidgets('Flutter delegates selection to an application transition',
      (tester) async {
    SeoTabsState keepFirst(SeoTabsState state, SeoTabsAction action) =>
        SeoTabsState(index: 0, count: state.count);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SeoTabs(
          transition: keepFirst,
          tabs: [
            for (var index = 0; index < 2; index++)
              SeoTab(
                label: 'Tab $index',
                content: Text('Panel $index'),
                nodes: [SeoNode(tag: 'p', text: 'Panel $index')],
              ),
          ],
        ),
      ),
    );

    await tester.tap(find.text('Tab 1'));
    await tester.pump();

    expect(find.text('Panel 0'), findsOneWidget);
    expect(find.text('Panel 1'), findsNothing);
  });
}
