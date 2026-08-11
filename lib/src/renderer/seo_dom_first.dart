/// Assets and wrappers for permanent semantic DOM delivery.
library;

import '../routing/seo_route_delivery.dart';
import 'html_renderer.dart';
import 'seo_container.dart';
import 'seo_dom_first_collection_runtime.g.dart';
import 'seo_dom_first_tabs_runtime.g.dart';
import 'seo_motion_stylesheet.dart';
import 'seo_stylesheet.dart';

/// Marks the package-owned DOM-first runtime in a generated document.
const String seoDomFirstScriptAttribute = 'data-esen-seo-dom-first-runtime';

/// Structural styles for the compiled DOM-first tabs control.
const String seoDomFirstTabsStylesheet = '''
#$seoContainerId [data-esen-component="tabs"][data-esen-enhanced="true"]>.esen-seo-tab-list{display:flex;flex-wrap:wrap;gap:.5rem;border-bottom:1px solid currentColor;margin-bottom:1rem}
#$seoContainerId [data-esen-component="tabs"]>.esen-seo-tab-list>.esen-seo-tab{font:inherit;color:inherit;background:transparent;border:0;border-bottom:2px solid transparent;padding:.5rem .75rem;cursor:pointer}
#$seoContainerId [data-esen-component="tabs"]>.esen-seo-tab-list>.esen-seo-tab[aria-selected="true"]{border-bottom-color:currentColor;font-weight:600}
#$seoContainerId [data-esen-component="tabs"]>.esen-seo-tab-list>.esen-seo-tab:focus-visible{outline:2px solid currentColor;outline-offset:2px}
#$seoContainerId [data-esen-component="tabs"][data-esen-enhanced="true"]>section[data-esen-tab-panel][hidden]{display:none}
''';

/// Structural styles for the compiled DOM-first collection control.
const String seoDomFirstCollectionStylesheet = '''
#$seoContainerId [data-esen-component="collection"]>.esen-seo-collection-toolbar{display:grid;gap:.75rem;margin-bottom:1rem}
#$seoContainerId [data-esen-component="collection"]>.esen-seo-collection-toolbar label{display:grid;gap:.375rem}
#$seoContainerId [data-esen-component="collection"]>.esen-seo-collection-toolbar input{min-height:2.75rem;font:inherit;color:inherit;background:transparent;border:1px solid currentColor;border-radius:6px;padding:.5rem .75rem}
#$seoContainerId [data-esen-component="collection"] .esen-seo-collection-categories,#$seoContainerId [data-esen-component="collection"] .esen-seo-collection-sort{display:grid;gap:.375rem}
#$seoContainerId [data-esen-component="collection"] .esen-seo-collection-category-options,#$seoContainerId [data-esen-component="collection"] .esen-seo-collection-sort-options{display:flex;flex-wrap:wrap;gap:.5rem}
#$seoContainerId [data-esen-component="collection"] [data-esen-collection-category],#$seoContainerId [data-esen-component="collection"] [data-esen-collection-sort],#$seoContainerId [data-esen-component="collection"] .esen-seo-collection-pagination>button{min-width:2.75rem;min-height:2.75rem;font:inherit;color:inherit;background:transparent;border:1px solid currentColor;border-radius:6px;padding:.5rem .75rem;cursor:pointer}
#$seoContainerId [data-esen-component="collection"] [aria-pressed="true"]{font-weight:700;border-width:2px}
#$seoContainerId [data-esen-component="collection"] .esen-seo-collection-results{margin:0 0 .75rem}
#$seoContainerId [data-esen-component="collection"] .esen-seo-collection-empty{margin:1rem 0}
#$seoContainerId [data-esen-component="collection"] .esen-seo-collection-pagination{display:flex;align-items:center;justify-content:space-between;gap:.75rem;margin-top:1rem}
#$seoContainerId [data-esen-component="collection"] .esen-seo-collection-pagination>button[disabled]{opacity:.4;cursor:default}
#$seoContainerId [data-esen-component="collection"] input:focus-visible,#$seoContainerId [data-esen-component="collection"] button:focus-visible{outline:2px solid currentColor;outline-offset:2px}
#$seoContainerId [data-esen-component="collection"] [hidden]{display:none}
''';

/// Returns the style tag needed by the selected DOM-first [features].
String seoDomFirstFeatureStyleHtml(
  Set<SeoDomFirstFeature> features, {
  String? nonce,
}) {
  final css = StringBuffer();
  if (features.contains(SeoDomFirstFeature.tabs)) {
    css.write(seoDomFirstTabsStylesheet);
  }
  if (features.contains(SeoDomFirstFeature.collection)) {
    css.write(seoDomFirstCollectionStylesheet);
  }
  if (features.contains(SeoDomFirstFeature.motion)) {
    css.write(seoMotionStylesheet);
  }
  return css.isEmpty ? '' : seoStyleTagHtml(css.toString(), nonce: nonce);
}

/// Returns the compiled runtime needed by the selected DOM-first [features].
String seoDomFirstFeatureScriptHtml(
  Set<SeoDomFirstFeature> features, {
  String? nonce,
}) {
  final nonceAttribute = _nonceAttribute(nonce);
  final scripts = StringBuffer();
  if (features.contains(SeoDomFirstFeature.tabs)) {
    scripts.write('<script $seoDomFirstScriptAttribute$nonceAttribute>'
        '$seoDomFirstTabsRuntime</script>');
  }
  if (features.contains(SeoDomFirstFeature.collection)) {
    scripts.write('<script $seoDomFirstScriptAttribute$nonceAttribute>'
        '$seoDomFirstCollectionRuntime</script>');
  }
  return scripts.toString();
}

String _nonceAttribute(String? nonce) {
  final value = nonce?.trim();
  if (value == null || value.isEmpty) return '';
  return ' nonce="${HtmlRenderer.escapeAttribute(value)}"';
}
