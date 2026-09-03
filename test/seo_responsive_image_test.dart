import 'package:esen_seo/esen_seo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  const renderer = HtmlRenderer();

  setUp(enableSeoForTests);

  test('pure builder emits canonical picture sources and fallback srcset', () {
    final html = renderer.render(buildSeoResponsiveImageNodes(
      src: '/hero-1280.jpg',
      alt: 'City skyline at dusk',
      width: 1280,
      height: 720,
      candidates: const [
        SeoResponsiveImageCandidate(src: '/hero-640.jpg', width: 640),
        SeoResponsiveImageCandidate(src: '/hero-320.jpg', width: 320),
      ],
      sources: const [
        SeoResponsiveImageSource(
          format: SeoResponsiveImageFormat.webp,
          candidates: [
            SeoResponsiveImageCandidate(src: '/hero-640.webp', width: 640),
            SeoResponsiveImageCandidate(src: '/hero-320.webp', width: 320),
          ],
        ),
        SeoResponsiveImageSource(
          format: SeoResponsiveImageFormat.avif,
          candidates: [
            SeoResponsiveImageCandidate(src: '/hero-640.avif', width: 640),
            SeoResponsiveImageCandidate(src: '/hero-320.avif', width: 320),
          ],
        ),
      ],
      sizes: '(max-width: 40rem) 100vw, 40rem',
      loading: SeoResponsiveImageLoading.lazy,
      fetchPriority: SeoResponsiveImageFetchPriority.low,
    ));

    expect(
      html,
      '<picture class="esen-seo-responsive-image">'
      '<source type="image/avif" '
      'srcset="/hero-320.avif 320w, /hero-640.avif 640w" '
      'sizes="(max-width: 40rem) 100vw, 40rem"/>'
      '<source type="image/webp" '
      'srcset="/hero-320.webp 320w, /hero-640.webp 640w" '
      'sizes="(max-width: 40rem) 100vw, 40rem"/>'
      '<img src="/hero-1280.jpg" '
      'srcset="/hero-320.jpg 320w, /hero-640.jpg 640w, '
      '/hero-1280.jpg 1280w" '
      'sizes="(max-width: 40rem) 100vw, 40rem" '
      'alt="City skyline at dusk" width="1280" height="720" '
      'loading="lazy" fetchpriority="low"/>'
      '</picture>',
    );
  });

  test('default and themed stylesheets carry responsive geometry', () {
    const pictureRule =
        '#esen-seo-content .esen-seo-responsive-image{display:block}';
    const imageRule = '#esen-seo-content .esen-seo-responsive-image>img'
        '{display:block;width:100%;height:auto}';

    expect(seoDefaultStylesheet, contains(pictureRule));
    expect(seoDefaultStylesheet, contains(imageRule));
    final themed = seoStylesheetFromTheme(ThemeData());
    expect(themed, contains(pictureRule));
    expect(themed, contains(imageRule));
  });

  test('invalid candidates are omitted without poisoning valid variants', () {
    final html = renderer.render(buildSeoResponsiveImageNodes(
      src: '/fallback.jpg',
      alt: 'Fallback',
      width: 1200,
      height: 800,
      candidates: const [
        SeoResponsiveImageCandidate(src: '/first-640.jpg', width: 640),
        SeoResponsiveImageCandidate(src: '/second-640.jpg', width: 640),
        SeoResponsiveImageCandidate(src: 'javascript:alert(1)', width: 800),
        SeoResponsiveImageCandidate(src: '/space image.jpg', width: 900),
        SeoResponsiveImageCandidate(src: '/comma,image.jpg', width: 1000),
        SeoResponsiveImageCandidate(src: '/quote"image.jpg', width: 1050),
        SeoResponsiveImageCandidate(src: 'ftp://x.dev/image.jpg', width: 1100),
        SeoResponsiveImageCandidate(
          src: '/encoded%2Ccomma.jpg',
          width: 1150,
        ),
        SeoResponsiveImageCandidate(src: '/zero.jpg', width: 0),
        SeoResponsiveImageCandidate(src: '/huge.jpg', width: 100001),
      ],
    ));

    expect(
      html,
      contains('srcset="/first-640.jpg 640w, '
          '/encoded%2Ccomma.jpg 1150w, /fallback.jpg 1200w"'),
    );
    expect(html, isNot(contains('second-640')));
    expect(html, isNot(contains('javascript')));
    expect(html, isNot(contains('space image')));
    expect(html, isNot(contains('comma,image')));
    expect(html, isNot(contains('quote')));
    expect(html, isNot(contains('ftp://')));
    expect(html, contains('/encoded%2Ccomma.jpg 1150w'));
    expect(html, isNot(contains('zero.jpg')));
    expect(html, isNot(contains('huge.jpg')));
  });

  test('candidate input is bounded before later entries are inspected', () {
    final candidates = [
      for (var index = 1; index <= seoResponsiveImageMaxCandidates; index++)
        SeoResponsiveImageCandidate(
          src: '/candidate-$index.jpg',
          width: index * 100,
        ),
      const SeoResponsiveImageCandidate(src: '/too-late.jpg', width: 1700),
    ];
    final html = renderer.render(buildSeoResponsiveImageNodes(
      src: '/fallback.jpg',
      alt: 'Bounded',
      width: 2000,
      height: 1000,
      candidates: candidates,
    ));

    expect(html, isNot(contains('too-late.jpg')));
    expect(html, contains('/fallback.jpg 2000w'));
  });

  test('invalid sizes fall back to 100vw when a srcset is emitted', () {
    final html = renderer.render(buildSeoResponsiveImageNodes(
      src: '/only.jpg',
      alt: '',
      width: 800,
      height: 600,
      candidates: const [
        SeoResponsiveImageCandidate(src: '/small.jpg', width: 400),
      ],
      sizes: '100vw\u202e',
      loading: SeoResponsiveImageLoading.eager,
      fetchPriority: SeoResponsiveImageFetchPriority.high,
    ));

    expect(html, contains('alt="" width="800" height="600"'));
    expect(html, contains('sizes="100vw"'));
    expect(html, contains('loading="eager" fetchpriority="high"'));
    expect(html, isNot(contains('\u202e')));
  });

  test('one fallback does not emit redundant srcset or sizes', () {
    final html = renderer.render(buildSeoResponsiveImageNodes(
      src: '/only.jpg',
      alt: 'Only image',
      width: 800,
      height: 600,
    ));

    expect(html, contains('<img src="/only.jpg" alt="Only image"'));
    expect(html, isNot(contains('srcset=')));
    expect(html, isNot(contains('sizes=')));
  });

  test('invalid fallback URL and dimensions do not create a request URL', () {
    final html = renderer.render(buildSeoResponsiveImageNodes(
      src: 'javascript:alert(1)',
      alt: 'Unavailable',
      width: -1,
      height: 0,
    ));

    expect(
        html,
        '<picture class="esen-seo-responsive-image">'
        '<img alt="Unavailable"/></picture>');
  });

  test('non-HTTP schemes are not admitted as image fallbacks', () {
    final html = renderer.render(buildSeoResponsiveImageNodes(
      src: 'mailto:image@example.com',
      alt: 'Unavailable',
      width: 800,
      height: 600,
    ));

    expect(html, isNot(contains('src=')));
    expect(html, contains('alt="Unavailable"'));
  });

  test('uppercase HTTPS fallback URLs remain valid', () {
    final html = renderer.render(buildSeoResponsiveImageNodes(
      src: 'HTTPS://example.test/image.jpg',
      alt: 'Image',
      width: 800,
      height: 600,
    ));

    expect(html, contains('src="HTTPS://example.test/image.jpg"'));
  });

  testWidgets('widget mirrors the same responsive definition', (tester) async {
    await pumpSeo(
      tester,
      const SeoResponsiveImage(
        src: '/hero-1200.jpg',
        alt: 'Product photo',
        width: 1200,
        height: 800,
        candidates: [
          SeoResponsiveImageCandidate(src: '/hero-480.jpg', width: 480),
          SeoResponsiveImageCandidate(src: '/hero-800.jpg', width: 800),
        ],
        sources: [
          SeoResponsiveImageSource(
            format: SeoResponsiveImageFormat.webp,
            candidates: [
              SeoResponsiveImageCandidate(
                src: '/hero-480.webp',
                width: 480,
              ),
            ],
          ),
        ],
        loading: SeoResponsiveImageLoading.lazy,
      ),
    );

    final html = EsenSeo.currentHtml;
    expect(html, startsWith('<picture class="esen-seo-responsive-image">'));
    expect(html, contains('<source type="image/webp"'));
    expect(
      html,
      contains('/hero-480.jpg 480w, /hero-800.jpg 800w, '
          '/hero-1200.jpg 1200w'),
    );
    expect(html, contains('alt="Product photo" width="1200" height="800"'));
  });

  testWidgets('Flutter selects by measured width and device-pixel ratio',
      (tester) async {
    await pumpSeo(
      tester,
      const MediaQuery(
        data: MediaQueryData(
          size: Size(400, 800),
          devicePixelRatio: 2,
        ),
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 300,
            child: SeoResponsiveImage(
              src: '/hero-1200.jpg',
              alt: 'Hero',
              width: 1200,
              height: 800,
              candidates: [
                SeoResponsiveImageCandidate(
                  src: '/hero-320.jpg',
                  width: 320,
                ),
                SeoResponsiveImageCandidate(
                  src: '/hero-640.jpg',
                  width: 640,
                ),
                SeoResponsiveImageCandidate(
                  src: '/hero-960.jpg',
                  width: 960,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as NetworkImage).url, '/hero-640.jpg');
    final box = tester.getSize(find.byType(AspectRatio));
    expect(box.width / box.height, closeTo(1.5, 0.01));
  });

  testWidgets('Flutter ignores invalid variants and caps at the largest',
      (tester) async {
    await pumpSeo(
      tester,
      const MediaQuery(
        data: MediaQueryData(
          size: Size(2000, 1000),
          devicePixelRatio: 2,
        ),
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 1000,
            child: SeoResponsiveImage(
              src: '/fallback-1200.jpg',
              alt: 'Wide',
              width: 1200,
              height: 600,
              candidates: [
                SeoResponsiveImageCandidate(
                  src: 'javascript:alert(1)',
                  width: 4000,
                ),
                SeoResponsiveImageCandidate(
                  src: '/valid-800.jpg',
                  width: 800,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as NetworkImage).url, '/fallback-1200.jpg');
  });

  testWidgets('unbounded Flutter layout uses intrinsic dimensions',
      (tester) async {
    await pumpSeo(
      tester,
      const UnconstrainedBox(
        child: SeoResponsiveImage(
          src: '/fallback-600.jpg',
          alt: 'Intrinsic',
          width: 600,
          height: 300,
          candidates: [
            SeoResponsiveImageCandidate(src: '/small-300.jpg', width: 300),
          ],
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(SizedBox).last), const Size(600, 300));
    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as NetworkImage).url, '/fallback-600.jpg');
  });

  testWidgets('invalid fallback stays inert on Flutter and HTML',
      (tester) async {
    await pumpSeo(
      tester,
      const SeoResponsiveImage(
        src: 'javascript:alert(1)',
        alt: 'Unavailable',
        width: 100,
        height: 100,
      ),
    );

    expect(find.byType(Image), findsNothing);
    expect(EsenSeo.currentHtml, isNot(contains('javascript')));
    expect(EsenSeo.currentHtml, contains('alt="Unavailable"'));
  });
}
