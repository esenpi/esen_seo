import 'package:esen_seo/core.dart';
import 'package:esen_seo/src/components/seo_motion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const renderer = HtmlRenderer();
  const data = [(label: 'A', value: 2.0), (label: 'B', value: 4.0)];

  test('no motion preserves the previous bar chart bytes', () {
    final html = renderer.render(buildSeoBarChartNodes(data: data));

    expect(
      html,
      '<figure class="esen-seo-bar-chart">'
      '<div aria-hidden="true" style="display:flex;align-items:flex-end;'
      'gap:8px;height:220px">'
      '<div title="A: 2" style="flex:1;border-radius:3px 3px 0 0;'
      'background:#2563eb;height:50%"></div>'
      '<div title="B: 4" style="flex:1;border-radius:3px 3px 0 0;'
      'background:#2563eb;height:100%"></div>'
      '</div><table><tbody><tr><th>A</th><td>2</td></tr>'
      '<tr><th>B</th><td>4</td></tr></tbody></table></figure>',
    );
  });

  test('gentle motion adds only fixed package markers', () {
    final html = renderer.render(buildSeoBarChartNodes(
      data: data,
      motion: SeoMotionPreset.gentle,
    ));

    expect(
      html,
      startsWith('<figure class="esen-seo-bar-chart" '
          'data-esen-motion="gentle">'),
    );
    expect('data-esen-motion-item=""'.allMatches(html), hasLength(2));
    expect(html, isNot(contains('animation:')));
    expect(html, isNot(contains('transform:')));
    expect(html, contains('<table><tbody><tr><th>A</th><td>2</td></tr>'));
  });

  test('CSS derives from the pure timing model and honors reduced motion', () {
    final timing = seoMotionTiming(SeoMotionPreset.gentle);

    expect(
      seoMotionStylesheet,
      contains('animation-duration:${timing.entrance.inMilliseconds}ms'),
    );
    expect(
      seoMotionStylesheet,
      contains('transition:transform ${timing.emphasis.inMilliseconds}ms'),
    );
    expect(
      seoMotionStylesheet,
      contains('nth-child(2){animation-delay:'
          '${timing.stagger.inMilliseconds}ms}'),
    );
    expect(seoMotionStylesheet, contains('@media (hover:hover)'));
    expect(
      seoMotionStylesheet,
      contains('@media (prefers-reduced-motion:reduce)'),
    );
    expect(seoMotionStylesheet, isNot(contains('</style')));
  });

  test('DOM-first motion emits style without an executable runtime', () {
    const features = {SeoDomFirstFeature.motion};
    final style = seoDomFirstFeatureStyleHtml(features, nonce: 'safe');

    expect(style, contains('data-esen-seo-style'));
    expect(style, contains('nonce="safe"'));
    expect(style, contains('esen-seo-bar-grow-gentle'));
    expect(seoDomFirstFeatureScriptHtml(features), isEmpty);
  });

  test('stagger duration is capped for large data sets', () {
    final timing = seoMotionTiming(SeoMotionPreset.gentle);

    expect(timing.delayFor(-1), Duration.zero);
    expect(
      timing.delayFor(1000),
      timing.stagger * (seoMotionMaxStaggeredItems - 1),
    );
    expect(
      timing.totalEntranceFor(1000),
      timing.entrance + timing.delayFor(1000),
    );
  });
}
