@TestOn('browser')
library;

import 'package:esen_seo/src/components/seo_carousel_transition.dart';
import 'package:esen_seo/src/renderer/dom_first_carousel_adapter_web.dart';
import 'package:esen_seo/src/renderer/seo_dom_first_carousel_runtime.g.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;

void main() {
  late web.HTMLElement fixture;

  setUp(() {
    fixture = web.document.createElement('div') as web.HTMLElement;
    fixture.id = 'dom-first-carousel-fixture';
    web.document.body?.appendChild(fixture);
  });

  tearDown(() => fixture.remove());

  test('compiled carousel uses the shared transition for every control', () {
    final container = _container(fixture);
    final root = _carousel(container, 'compiled-carousel', initialIndex: 1);

    expect(root.textContent, contains('Overview content'));
    expect(root.textContent, contains('Reviews content'));
    expect(root.querySelectorAll('button').length, 0);
    _runCompiledCandidate();

    final slides = root.querySelectorAll('[data-esen-carousel-slide]');
    final controls = root.querySelectorAll('[data-esen-carousel-control]');
    final previous = controls.item(0)! as web.HTMLElement;
    final next = controls.item(1)! as web.HTMLElement;
    final status = root.querySelector('[data-esen-carousel-status]')!;

    expect(root.getAttribute('role'), 'region');
    expect(root.getAttribute('aria-label'), 'Rendering carousel');
    expect(controls.length, 2);
    expect((slides.item(0)! as web.Element).hasAttribute('hidden'), isTrue);
    expect((slides.item(1)! as web.Element).hasAttribute('hidden'), isFalse);
    expect((slides.item(2)! as web.Element).hasAttribute('hidden'), isTrue);
    expect(status.textContent, '2 / 3');
    expect(status.getAttribute('aria-live'), 'polite');

    next.dispatchEvent(
      web.MouseEvent('click', web.MouseEventInit(bubbles: true)),
    );
    expect(status.textContent, '3 / 3');
    expect(next.getAttribute('aria-disabled'), 'true');
    expect(next.hasAttribute('disabled'), isTrue);
    next.dispatchEvent(
      web.MouseEvent('click', web.MouseEventInit(bubbles: true)),
    );
    expect(status.textContent, '3 / 3');

    previous.dispatchEvent(
      web.MouseEvent('click', web.MouseEventInit(bubbles: true)),
    );
    expect(status.textContent, '2 / 3');
    _keydown(next, 'Home');
    expect(status.textContent, '1 / 3');
    _keydown(next, 'ArrowRight');
    expect(status.textContent, '2 / 3');
    _keydown(next, 'End');
    expect(status.textContent, '3 / 3');
    _keydown(previous, 'ArrowLeft', repeat: true);
    expect(status.textContent, '3 / 3');

    _runCompiledCandidate();
    expect(root.querySelectorAll('[data-esen-carousel-controls]').length, 1);
    expect(root.querySelectorAll('[data-esen-carousel-control]').length, 2);
  });

  test('invalid or ambiguous carousels remain entirely unmodified', () {
    final container = _container(fixture);
    final duplicateA = _carousel(container, 'duplicate-carousel');
    final duplicateB = _carousel(container, 'duplicate-carousel');
    final collision = _carousel(container, 'collision-carousel');
    container.appendChild(
      web.document.createElement('div')..id = 'collision-carousel-previous',
    );
    final wrongId = _carousel(container, 'wrong-id-carousel');
    wrongId.querySelector('section')?.id = 'borrowed-slide';
    final malformed = _carousel(container, 'malformed-carousel');
    malformed.appendChild(web.document.createElement('div'));
    final wrongRoot = _carousel(
      container,
      'wrong-root-carousel',
      rootTag: 'section',
    );
    final missingClass = _carousel(container, 'missing-class-carousel')
      ..className = '';
    final emptyHeading = _carousel(container, 'empty-heading-carousel');
    emptyHeading.querySelector('h3')?.textContent = '   ';
    final emptyLabel = _carousel(container, 'empty-label-carousel');
    emptyLabel.setAttribute('data-esen-next-label', '   ');
    final badIndex = _carousel(container, 'bad-index-carousel');
    badIndex.setAttribute('data-esen-initial-index', '01');
    final hugeIndex = _carousel(container, 'huge-index-carousel');
    hugeIndex.setAttribute(
      'data-esen-initial-index',
      List.filled(10000, '9').join(),
    );
    final single = _carousel(container, 'single-carousel', count: 1);
    final oversized = _carousel(
      container,
      'oversized-carousel',
      count: seoCarouselMaxEnhancedSlides + 1,
    );
    final inertParent = web.document.createElement('div')
      ..setAttribute('inert', '');
    container.appendChild(inertParent);
    final inert = _carousel(inertParent, 'inert-carousel');
    final ariaHiddenParent = web.document.createElement('div')
      ..setAttribute('aria-hidden', ' TRUE ');
    container.appendChild(ariaHiddenParent);
    final ariaHidden = _carousel(ariaHiddenParent, 'aria-hidden-carousel');
    final hiddenParent = web.document.createElement('div')
      ..setAttribute('hidden', '');
    container.appendChild(hiddenParent);
    final hidden = _carousel(hiddenParent, 'hidden-carousel');
    final outside = _carousel(fixture, 'outside-carousel');

    _runCompiledCandidate();

    for (final root in [
      duplicateA,
      duplicateB,
      collision,
      wrongId,
      malformed,
      wrongRoot,
      missingClass,
      emptyHeading,
      emptyLabel,
      badIndex,
      hugeIndex,
      single,
      oversized,
      inert,
      ariaHidden,
      outside,
    ]) {
      expect(root.querySelectorAll('button').length, 0);
      expect(root.querySelectorAll('[hidden]').length, 0);
      expect(root.querySelectorAll('[role]').length, 0);
      expect(root.hasAttribute('data-esen-enhanced'), isFalse);
      expect(root.textContent, contains('Overview content'));
    }
    expect(hiddenParent.hasAttribute('hidden'), isTrue);
    expect(hidden.hasAttribute('data-esen-enhanced'), isTrue);
    expect(hidden.querySelectorAll('[data-esen-carousel-control]').length, 2);
  });

  test('requires one unambiguous package-owned DOM-first container', () {
    final first = _container(fixture);
    final root = _carousel(first, 'container-carousel');
    final second = web.document.createElement('div')
      ..id = 'esen-seo-content'
      ..setAttribute('data-esen-seo-dom-first', 'true');
    fixture.appendChild(second);

    _runCompiledCandidate();

    expect(root.querySelectorAll('button').length, 0);
    expect(root.querySelectorAll('[hidden]').length, 0);
  });

  test('nested carousels enhance independently after complete validation', () {
    final container = _container(fixture);
    final outer = _carousel(container, 'outer-carousel');
    final secondSlide =
        outer.querySelectorAll('section').item(1)! as web.Element;
    final inner = _carousel(secondSlide, 'inner-carousel');

    _runCompiledCandidate();

    expect(outer.hasAttribute('data-esen-enhanced'), isTrue);
    expect(inner.hasAttribute('data-esen-enhanced'), isTrue);
    expect(outer.querySelectorAll('[data-esen-carousel-controls]').length, 2);
    expect(inner.querySelectorAll('[data-esen-carousel-controls]').length, 1);
  });

  test('hostile-looking labels remain inert attribute and text values', () {
    final container = _container(fixture);
    final root = _carousel(container, 'text-carousel')
      ..setAttribute('data-esen-label', '<img src=x onerror=alert(1)>');
    root.querySelector('h3')?.textContent = '<svg onload=alert(1)>';

    _runCompiledCandidate();

    expect(root.getAttribute('aria-label'), '<img src=x onerror=alert(1)>');
    expect(root.querySelector('h3')?.textContent, '<svg onload=alert(1)>');
    expect(root.querySelectorAll('img').length, 0);
    expect(root.querySelectorAll('svg').length, 0);
    expect(root.querySelectorAll('[onerror],[onload]').length, 0);
  });

  test('adapter executes an application transition instead of the default', () {
    final container = _container(fixture);
    final root = _carousel(container, 'application-carousel', initialIndex: 0);

    SeoCarouselState skipMiddle(
      SeoCarouselState state,
      SeoCarouselAction action,
    ) {
      if (action is SeoCarouselNext && state.index == 0) {
        return SeoCarouselState(index: 2, count: state.count);
      }
      return transitionSeoCarousel(state, action);
    }

    enhanceSeoDomFirstCarousels(transition: skipMiddle);
    final next = root.querySelectorAll('[data-esen-carousel-control]').item(1)!
        as web.HTMLElement;
    next.dispatchEvent(
      web.MouseEvent('click', web.MouseEventInit(bubbles: true)),
    );

    expect(
      root.querySelector('[data-esen-carousel-status]')?.textContent,
      '3 / 3',
    );
    expect(
      (root.querySelectorAll('[data-esen-carousel-slide]').item(2)!
              as web.Element)
          .hasAttribute('hidden'),
      isFalse,
    );
  });

  test('application transition owns boundary control availability', () {
    final container = _container(fixture);
    final root = _carousel(container, 'wrapping-carousel', initialIndex: 0);

    SeoCarouselState wrap(
      SeoCarouselState state,
      SeoCarouselAction action,
    ) {
      if (action is SeoCarouselPrevious && state.index == 0) {
        return SeoCarouselState(index: state.count - 1, count: state.count);
      }
      return transitionSeoCarousel(state, action);
    }

    enhanceSeoDomFirstCarousels(transition: wrap);
    final previous = root
        .querySelectorAll('[data-esen-carousel-control]')
        .item(0)! as web.HTMLElement;
    expect(previous.getAttribute('aria-disabled'), 'false');
    expect(previous.hasAttribute('disabled'), isFalse);

    previous.dispatchEvent(
      web.MouseEvent('click', web.MouseEventInit(bubbles: true)),
    );

    expect(
      root.querySelector('[data-esen-carousel-status]')?.textContent,
      '3 / 3',
    );
  });

  test('RTL horizontal arrows follow visual direction', () {
    final container = _container(fixture);
    final root = _carousel(container, 'rtl-carousel', initialIndex: 1)
      ..setAttribute('dir', 'rtl');

    enhanceSeoDomFirstCarousels();
    final next = root.querySelectorAll('[data-esen-carousel-control]').item(1)!
        as web.HTMLElement;
    _keydown(next, 'ArrowRight');

    expect(
      root.querySelector('[data-esen-carousel-status]')?.textContent,
      '1 / 3',
    );
  });
}

web.HTMLElement _container(web.HTMLElement fixture) {
  final container = web.document.createElement('div') as web.HTMLElement
    ..id = 'esen-seo-content'
    ..setAttribute('data-esen-seo-dom-first', 'true');
  fixture.appendChild(container);
  return container;
}

web.HTMLElement _carousel(
  web.Element parent,
  String id, {
  int count = 3,
  int initialIndex = 1,
  String rootTag = 'div',
}) {
  final root = web.document.createElement(rootTag) as web.HTMLElement
    ..id = id
    ..className = 'esen-seo-carousel'
    ..setAttribute('data-esen-component', 'carousel')
    ..setAttribute('data-esen-label', 'Rendering carousel')
    ..setAttribute('data-esen-previous-label', 'Previous slide')
    ..setAttribute('data-esen-next-label', 'Next slide')
    ..setAttribute('data-esen-initial-index', '$initialIndex');
  const labels = ['Overview', 'Details', 'Reviews'];
  for (var index = 0; index < count; index++) {
    final label = index < labels.length ? labels[index] : 'Slide $index';
    final slide = web.document.createElement('section')
      ..id = '$id-slide-$index'
      ..setAttribute('data-esen-carousel-slide', '');
    slide.appendChild(
      web.document.createElement('h3')..textContent = label,
    );
    slide.appendChild(
      web.document.createElement('p')..textContent = '$label content',
    );
    root.appendChild(slide);
  }
  parent.appendChild(root);
  return root;
}

void _runCompiledCandidate() {
  final script = web.document.createElement('script')
    ..textContent = seoDomFirstCarouselRuntime;
  web.document.body?.appendChild(script);
  script.remove();
}

void _keydown(web.Element element, String key, {bool repeat = false}) {
  element.dispatchEvent(
    web.KeyboardEvent(
      'keydown',
      web.KeyboardEventInit(key: key, repeat: repeat, bubbles: true),
    ),
  );
}
