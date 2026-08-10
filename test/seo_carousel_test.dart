import 'package:esen_seo/esen_seo.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

class _BuildProbe extends StatelessWidget {
  const _BuildProbe(this.index, this.onBuild);

  final int index;
  final ValueChanged<int> onBuild;

  @override
  Widget build(BuildContext context) {
    onBuild(index);
    return Text('Flutter slide $index');
  }
}

void main() {
  setUp(enableSeoForTests);

  final slides = [
    SeoCarouselSlide(
      label: 'Overview',
      content: Text('Flutter overview'),
      nodes: [SeoNode(tag: 'p', text: 'Flutter overview')],
    ),
    SeoCarouselSlide(
      label: 'Details',
      content: Text('Flutter details'),
      nodes: [SeoNode(tag: 'p', text: 'Flutter details')],
    ),
    SeoCarouselSlide(
      label: 'Reviews',
      content: Text('Flutter reviews'),
      nodes: [SeoNode(tag: 'p', text: 'Flutter reviews')],
    ),
  ];

  testWidgets('mirrors every slide independently of the Flutter page',
      (tester) async {
    final changes = <int>[];
    await pumpSeo(
      tester,
      SeoCarousel(
        slides: slides,
        height: 180,
        interactionId: 'product-carousel',
        onPageChanged: changes.add,
      ),
    );
    final initialHtml = EsenSeo.currentHtml;

    expect(find.text('Overview'), findsOneWidget);
    expect(initialHtml, contains('<h3>Overview</h3>'));
    expect(initialHtml, contains('<h3>Details</h3>'));
    expect(initialHtml, contains('<h3>Reviews</h3>'));
    expect(initialHtml, contains('<p>Flutter reviews</p>'));
    expect(initialHtml, isNot(contains('<button')));

    await tester.tap(find.text('\u203a'));
    await tester.pumpAndSettle();
    EsenSeo.refresh();

    expect(find.text('Details'), findsOneWidget);
    expect(changes, [1]);
    expect(EsenSeo.currentHtml, initialHtml);
  });

  testWidgets('keeps distant Flutter pages lazy but mirrors them immediately',
      (tester) async {
    final built = <int>{};
    final manySlides = [
      for (var index = 0; index < 20; index++)
        SeoCarouselSlide(
          label: 'Slide $index',
          content: _BuildProbe(index, built.add),
          nodes: [SeoNode(tag: 'p', text: 'Semantic slide $index')],
        ),
    ];

    await pumpSeo(
      tester,
      SeoCarousel(slides: manySlides, height: 180),
    );

    expect(built, contains(0));
    expect(built, isNot(contains(19)));
    expect(EsenSeo.currentHtml, contains('<h3>Slide 19</h3>'));
    expect(EsenSeo.currentHtml, contains('<p>Semantic slide 19</p>'));
  });

  testWidgets('initial index and invalid height are normalized',
      (tester) async {
    await pumpSeo(
      tester,
      SeoCarousel(slides: slides, initialIndex: 99, height: double.nan),
    );

    expect(find.text('Reviews'), findsOneWidget);
    expect(tester.getSize(find.byType(PageView)).height, 320);
  });

  testWidgets('replaced slide data resets to the requested page',
      (tester) async {
    const key = ValueKey('carousel');
    await pumpSeo(
      tester,
      SeoCarousel(key: key, slides: slides, initialIndex: 2),
    );
    expect(find.text('Reviews'), findsOneWidget);

    final replacements = [
      SeoCarouselSlide(
        label: 'New first',
        content: Text('New first content'),
        nodes: [SeoNode(tag: 'p', text: 'New first content')],
      ),
      SeoCarouselSlide(
        label: 'New second',
        content: Text('New second content'),
        nodes: [SeoNode(tag: 'p', text: 'New second content')],
      ),
    ];
    await pumpSeo(
      tester,
      SeoCarousel(key: key, slides: replacements, initialIndex: 0),
    );
    await tester.pump();

    expect(find.text('New first'), findsOneWidget);
    expect(EsenSeo.currentHtml, contains('<h3>New second</h3>'));
  });

  testWidgets('empty input renders and mirrors nothing', (tester) async {
    await pumpSeo(tester, const SeoCarousel(slides: []));

    expect(find.byType(PageView), findsNothing);
    expect(EsenSeo.currentHtml, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
