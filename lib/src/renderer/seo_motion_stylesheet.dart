/// Package-owned CSS for opt-in decorative motion.
library;

import '../components/seo_component_format.dart';
import '../components/seo_motion.dart';
import '../routing/seo_route_delivery.dart';
import 'seo_container.dart';

/// Motion rules for components carrying a supported fixed package marker.
///
/// The string is generated from the same pure timing model Flutter reads.
/// Include it directly, or select [SeoDomFirstFeature.motion] on a DOM-first
/// route. Without a matching marker these rules affect nothing.
final String seoMotionStylesheet = _buildMotionStylesheet();

String _buildMotionStylesheet() {
  final timing = seoMotionTiming(SeoMotionPreset.gentle);
  final curve = 'cubic-bezier('
      '${cssNumber(timing.x1)},${cssNumber(timing.y1)},'
      '${cssNumber(timing.x2)},${cssNumber(timing.y2)})';
  final entrance = '${timing.entrance.inMilliseconds}ms';
  final emphasis = '${timing.emphasis.inMilliseconds}ms';
  const animation = 'esen-seo-bar-grow-gentle';
  const selector = '#$seoContainerId '
      '.esen-seo-bar-chart[data-esen-motion="gentle"]'
      '>[aria-hidden="true"]>[data-esen-motion-item]';
  final css = StringBuffer()
    ..write('@keyframes $animation{from{transform:scaleY(0);opacity:.72}'
        'to{transform:scaleY(1);opacity:1}}\n')
    ..write('$selector{transform-origin:center bottom;'
        'animation-name:$animation;animation-duration:$entrance;'
        'animation-timing-function:$curve;animation-fill-mode:backwards;'
        'transition:transform $emphasis $curve,opacity $emphasis $curve}\n');

  for (var index = 1; index < seoMotionMaxStaggeredItems; index++) {
    final delay = timing.delayFor(index).inMilliseconds;
    css.write(
        '$selector:nth-child(${index + 1}){animation-delay:${delay}ms}\n');
  }
  final cappedDelay =
      timing.delayFor(seoMotionMaxStaggeredItems - 1).inMilliseconds;
  css
    ..write('$selector:nth-child(n+${seoMotionMaxStaggeredItems + 1})'
        '{animation-delay:${cappedDelay}ms}\n')
    ..write('@media (hover:hover) and (pointer:fine){$selector:hover{'
        'transform:translateY(-4px) scale(1.025);opacity:.92}}\n')
    ..write('$selector:active{transform:translateY(-4px) scale(1.025);'
        'opacity:.92}\n')
    ..write('@media (prefers-reduced-motion:reduce){$selector,'
        '$selector:hover,$selector:active{animation:none;transition:none;'
        'transform:none;opacity:1}}\n');
  return css.toString();
}
