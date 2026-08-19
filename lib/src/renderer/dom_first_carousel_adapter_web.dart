import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../components/seo_carousel_transition.dart';
import '../components/seo_component_format.dart';
import 'seo_container.dart';

/// Largest carousel the progressive adapter will enhance.
const int seoCarouselMaxEnhancedSlides = 200;

/// Enhances every valid carousel in the package-owned DOM-first container.
///
/// The complete control is validated before [_CarouselApplyBoundary] performs
/// the first mutation. Invalid or ambiguous markup remains complete, readable
/// HTML instead of becoming a partially initialized control.
void enhanceSeoDomFirstCarousels({
  SeoCarouselTransition transition = transitionSeoCarousel,
}) {
  for (final apply in _CarouselApplyBoundary.discover(web.document)) {
    _enhanceCarousel(apply, transition);
  }
}

void _enhanceCarousel(
  _CarouselApplyBoundary apply,
  SeoCarouselTransition transition,
) {
  var state = initialSeoCarouselState(
    count: apply.count,
    index: apply.initialIndex,
  );

  void render() {
    apply.state(
      state,
      previousEnabled: canApplySeoCarouselAction(
        transition,
        state,
        const SeoCarouselPrevious(),
      ),
      nextEnabled: canApplySeoCarouselAction(
        transition,
        state,
        const SeoCarouselNext(),
      ),
    );
  }

  void dispatch(SeoCarouselAction action) {
    state = applySeoCarouselTransition(transition, state, action);
    render();
  }

  apply.mount(dispatch);
  render();
}

final class _CarouselEntry {
  const _CarouselEntry({required this.slide, required this.heading});

  final web.HTMLElement slide;
  final web.HTMLElement heading;
}

final class _CarouselPlan {
  const _CarouselPlan({
    required this.root,
    required this.id,
    required this.label,
    required this.previousLabel,
    required this.nextLabel,
    required this.initialIndex,
    required this.entries,
    required this.rtl,
  });

  final web.Element root;
  final String id;
  final String label;
  final String previousLabel;
  final String nextLabel;
  final int initialIndex;
  final List<_CarouselEntry> entries;
  final bool rtl;
}

final class _CarouselApplyBoundary {
  _CarouselApplyBoundary(this.document, this.plan);

  final web.Document document;
  final _CarouselPlan plan;
  late final web.HTMLElement _previous;
  late final web.HTMLElement _next;
  late final web.HTMLElement _status;

  int get count => plan.entries.length;
  int get initialIndex => plan.initialIndex;

  static List<_CarouselApplyBoundary> discover(web.Document document) {
    final container = document.getElementById(seoContainerId);
    if (container == null ||
        container.getAttribute(seoDomFirstAttribute) != 'true' ||
        _idCount(document, seoContainerId) != 1) {
      return const [];
    }

    final boundaries = <_CarouselApplyBoundary>[];
    final roots =
        container.querySelectorAll('[data-esen-component="carousel"]');
    for (var index = 0; index < roots.length; index++) {
      final node = roots.item(index);
      if (node == null) continue;
      final plan = _validate(document, container, node as web.Element);
      if (plan != null) {
        boundaries.add(_CarouselApplyBoundary(document, plan));
      }
    }
    return boundaries;
  }

  static _CarouselPlan? _validate(
    web.Document document,
    web.Element container,
    web.Element root,
  ) {
    if (root.getAttribute('data-esen-enhanced') == 'true') return null;
    if (_hiddenByAncestor(root, container)) return null;
    if (root.tagName != 'DIV' ||
        !root.classList.contains('esen-seo-carousel')) {
      return null;
    }
    final id = root.id;
    if (!isValidSeoInteractionId(id) || _idCount(document, id) != 1) {
      return null;
    }

    final label = root.getAttribute('data-esen-label') ?? '';
    final previousLabel = root.getAttribute('data-esen-previous-label') ?? '';
    final nextLabel = root.getAttribute('data-esen-next-label') ?? '';
    if (label.trim().isEmpty ||
        previousLabel.trim().isEmpty ||
        nextLabel.trim().isEmpty) {
      return null;
    }

    final initial = root.getAttribute('data-esen-initial-index');
    if (initial == null || !_decimalIndex.hasMatch(initial)) return null;
    final initialIndex = int.tryParse(initial);

    final entries = <_CarouselEntry>[];
    final ids = <String>{};
    final slides = root.children;
    if (slides.length < 2 || slides.length > seoCarouselMaxEnhancedSlides) {
      return null;
    }
    for (var index = 0; index < slides.length; index++) {
      final slide = slides.item(index);
      final heading = slide?.firstElementChild;
      final expectedSlideId = '$id-slide-$index';
      if (slide == null ||
          slide.tagName != 'SECTION' ||
          !slide.hasAttribute('data-esen-carousel-slide') ||
          slide.id != expectedSlideId ||
          !ids.add(slide.id) ||
          _idCount(document, slide.id) != 1 ||
          heading == null ||
          !_headingTag.hasMatch(heading.tagName) ||
          (heading.textContent ?? '').trim().isEmpty) {
        return null;
      }
      entries.add(_CarouselEntry(
        slide: slide as web.HTMLElement,
        heading: heading as web.HTMLElement,
      ));
    }
    if (initialIndex == null ||
        initialIndex < 0 ||
        initialIndex >= entries.length) {
      return null;
    }

    for (final suffix in const ['previous', 'next', 'status']) {
      if (_idCount(document, '$id-$suffix') != 0) return null;
    }

    return _CarouselPlan(
      root: root,
      id: id,
      label: label,
      previousLabel: previousLabel,
      nextLabel: nextLabel,
      initialIndex: initialIndex,
      entries: entries,
      rtl: web.window.getComputedStyle(root).direction == 'rtl',
    );
  }

  static bool _hiddenByAncestor(
    web.Element root,
    web.Element container,
  ) {
    web.Element? current = root;
    while (current != null) {
      final ariaHidden = current.getAttribute('aria-hidden');
      if (current.hasAttribute('inert') ||
          (ariaHidden != null && ariaHidden.trim().toLowerCase() == 'true')) {
        return true;
      }
      if (current == container) return false;
      current = current.parentElement;
    }
    return true;
  }

  static int _idCount(web.Document document, String id) {
    if (id.isEmpty) return 0;
    final elements = document.querySelectorAll('[id]');
    var count = 0;
    for (var index = 0; index < elements.length; index++) {
      final element = elements.item(index);
      if (element != null && (element as web.Element).id == id) count++;
    }
    return count;
  }

  void mount(void Function(SeoCarouselAction action) dispatch) {
    final controls = document.createElement('div') as web.HTMLElement;
    controls.className = 'esen-seo-carousel-controls';
    controls.setAttribute('data-esen-carousel-controls', '');

    _previous = _control(
      id: '${plan.id}-previous',
      label: plan.previousLabel,
      symbol: plan.rtl ? '\u203a' : '\u2039',
      action: const SeoCarouselPrevious(),
      dispatch: dispatch,
    );
    _next = _control(
      id: '${plan.id}-next',
      label: plan.nextLabel,
      symbol: plan.rtl ? '\u2039' : '\u203a',
      action: const SeoCarouselNext(),
      dispatch: dispatch,
    );
    _status = document.createElement('span') as web.HTMLElement;
    _status.id = '${plan.id}-status';
    _status.className = 'esen-seo-carousel-status';
    _status.setAttribute('data-esen-carousel-status', '');
    _status.setAttribute('aria-live', 'polite');
    _status.setAttribute('aria-atomic', 'true');
    controls.appendChild(_previous);
    controls.appendChild(_status);
    controls.appendChild(_next);

    plan.root.insertBefore(controls, plan.root.firstChild);
    plan.root.setAttribute('role', 'region');
    plan.root.setAttribute('aria-label', plan.label);
    plan.root.setAttribute('data-esen-enhanced', 'true');
  }

  web.HTMLElement _control({
    required String id,
    required String label,
    required String symbol,
    required SeoCarouselAction action,
    required void Function(SeoCarouselAction action) dispatch,
  }) {
    final button = document.createElement('button') as web.HTMLElement;
    button.setAttribute('type', 'button');
    button.id = id;
    button.setAttribute('data-esen-carousel-control', '');
    button.setAttribute('aria-label', label);
    final icon = document.createElement('span') as web.HTMLElement;
    icon.setAttribute('aria-hidden', 'true');
    icon.textContent = symbol;
    button.appendChild(icon);
    button.addEventListener(
      'click',
      ((web.Event _) {
        if (!button.hasAttribute('disabled')) dispatch(action);
      }).toJS,
    );
    button.addEventListener(
      'keydown',
      ((web.Event rawEvent) {
        final event = rawEvent as web.KeyboardEvent;
        if (event.repeat) return;
        final keyboardAction = switch (event.key) {
          'ArrowRight' =>
            plan.rtl ? const SeoCarouselPrevious() : const SeoCarouselNext(),
          'ArrowLeft' =>
            plan.rtl ? const SeoCarouselNext() : const SeoCarouselPrevious(),
          'Home' => const SeoCarouselFirst(),
          'End' => const SeoCarouselLast(),
          _ => null,
        };
        if (keyboardAction == null) return;
        event.preventDefault();
        event.stopPropagation();
        dispatch(keyboardAction);
      }).toJS,
    );
    return button;
  }

  void state(
    SeoCarouselState state, {
    required bool previousEnabled,
    required bool nextEnabled,
  }) {
    for (var index = 0; index < plan.entries.length; index++) {
      plan.entries[index].slide.toggleAttribute('hidden', index != state.index);
    }
    _setEnabled(_previous, previousEnabled);
    _setEnabled(_next, nextEnabled);
    _status.textContent = '${state.index + 1} / ${state.count}';
  }

  void _setEnabled(web.HTMLElement button, bool enabled) {
    button.setAttribute('aria-disabled', enabled ? 'false' : 'true');
    button.toggleAttribute('disabled', !enabled);
  }
}

final RegExp _headingTag = RegExp(r'^H[1-6]$');
final RegExp _decimalIndex = RegExp(r'^(0|[1-9][0-9]{0,8})$');
