@TestOn('browser')
library;

import 'package:esen_seo/core.dart';
import 'package:esen_seo/src/renderer/dom_injector_web.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;

void main() {
  tearDown(() {
    web.document.getElementById('esen-seo-content')?.remove();
  });

  test('injector preserves the checked picture hierarchy and attributes', () {
    injectSeoNodes(buildSeoResponsiveImageNodes(
      src: '/photo-1200.jpg',
      alt: 'Accessible photo',
      width: 1200,
      height: 800,
      candidates: const [
        SeoResponsiveImageCandidate(src: '/photo-600.jpg', width: 600),
        SeoResponsiveImageCandidate(
          src: 'javascript:alert(1)',
          width: 900,
        ),
      ],
      sources: const [
        SeoResponsiveImageSource(
          format: SeoResponsiveImageFormat.avif,
          candidates: [
            SeoResponsiveImageCandidate(src: '/photo-600.avif', width: 600),
            SeoResponsiveImageCandidate(
              src: '/photo-1200.avif',
              width: 1200,
            ),
          ],
        ),
      ],
      sizes: '(max-width: 600px) 100vw, 600px',
    ));

    final container = web.document.getElementById('esen-seo-content');
    final picture = container?.querySelector('picture');
    final source = picture?.querySelector('source');
    final image = picture?.querySelector('img');

    expect(picture?.classList.contains('esen-seo-responsive-image'), isTrue);
    expect(source?.getAttribute('type'), 'image/avif');
    expect(
      source?.getAttribute('srcset'),
      '/photo-600.avif 600w, /photo-1200.avif 1200w',
    );
    expect(image?.getAttribute('src'), '/photo-1200.jpg');
    expect(
      image?.getAttribute('srcset'),
      '/photo-600.jpg 600w, /photo-1200.jpg 1200w',
    );
    expect(image?.getAttribute('alt'), 'Accessible photo');
    expect(container?.innerHTML, isNot(contains('javascript')));
  });
}
