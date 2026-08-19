import 'package:esen_seo/esen_seo.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  List<SeoCarouselSlide> slides() => [
        for (var index = 0; index < 3; index++)
          SeoCarouselSlide(
            label: 'Slide $index',
            content: Text('Body $index'),
            nodes: [SeoNode(tag: 'p', text: 'Body $index')],
          ),
      ];

  testWidgets('Flutter follows the shared carousel transition sequence',
      (tester) async {
    final values = slides();
    final changed = <int>[];
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SeoCarousel(
          slides: values,
          initialIndex: 1,
          onPageChanged: changed.add,
        ),
      ),
    );

    var expected = initialSeoCarouselState(count: values.length, index: 1);
    expect(find.text('${expected.index + 1} / 3'), findsOneWidget);

    for (final action in const <SeoCarouselAction>[
      SeoCarouselNext(),
      SeoCarouselPrevious(),
      SeoCarouselPrevious(),
    ]) {
      expected = transitionSeoCarousel(expected, action);
      final label = action is SeoCarouselNext ? '\u203a' : '\u2039';
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();

      expect(find.text('${expected.index + 1} / 3'), findsOneWidget);
    }
    expect(changed, [2, 1, 0]);
  });

  testWidgets('Flutter delegates selection to an application transition',
      (tester) async {
    SeoCarouselState skipMiddle(
      SeoCarouselState state,
      SeoCarouselAction action,
    ) {
      if (action is SeoCarouselNext && state.index == 0) {
        return SeoCarouselState(index: 2, count: state.count);
      }
      return transitionSeoCarousel(state, action);
    }

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SeoCarousel(
          transition: skipMiddle,
          slides: slides(),
        ),
      ),
    );

    expect(find.text('1 / 3'), findsOneWidget);
    expect(find.text('\u203a'), findsOneWidget);
    await tester.tap(find.text('\u203a'));
    await tester.pumpAndSettle();

    expect(find.text('3 / 3'), findsOneWidget);
    final pageView = tester.widget<PageView>(find.byType(PageView));
    expect(pageView.controller?.page, 2);
  });

  testWidgets('Flutter restores a swipe rejected by the transition',
      (tester) async {
    SeoCarouselState keepFirst(
      SeoCarouselState state,
      SeoCarouselAction action,
    ) =>
        SeoCarouselState(index: 0, count: state.count);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SeoCarousel(
          transition: keepFirst,
          slides: slides(),
        ),
      ),
    );

    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();

    final pageView = tester.widget<PageView>(find.byType(PageView));
    expect(pageView.controller?.page, 0);
    expect(find.text('1 / 3'), findsOneWidget);
  });

  testWidgets('Flutter control availability follows application transition',
      (tester) async {
    SeoCarouselState wrap(
      SeoCarouselState state,
      SeoCarouselAction action,
    ) {
      if (action is SeoCarouselPrevious && state.index == 0) {
        return SeoCarouselState(index: state.count - 1, count: state.count);
      }
      return transitionSeoCarousel(state, action);
    }

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SeoCarousel(
          transition: wrap,
          slides: slides(),
        ),
      ),
    );

    await tester.tap(find.text('\u2039'));
    await tester.pumpAndSettle();

    expect(find.text('3 / 3'), findsOneWidget);
  });
}
