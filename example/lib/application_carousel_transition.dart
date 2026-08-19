import 'package:esen_seo/core.dart';

/// Example-owned carousel logic: previous and next wrap at either end.
SeoCarouselState transitionExampleCarousel(
  SeoCarouselState state,
  SeoCarouselAction action,
) {
  final normalized = initialSeoCarouselState(
    count: state.count,
    index: state.index,
  );
  if (normalized.count == 0) return normalized;
  final last = normalized.count - 1;
  final next = switch (action) {
    SeoCarouselSelect(:final index) when index >= 0 && index <= last => index,
    SeoCarouselSelect() => normalized.index,
    SeoCarouselNext() => normalized.index == last ? 0 : normalized.index + 1,
    SeoCarouselPrevious() =>
      normalized.index == 0 ? last : normalized.index - 1,
    SeoCarouselFirst() => 0,
    SeoCarouselLast() => last,
  };
  return SeoCarouselState(index: next, count: normalized.count);
}
