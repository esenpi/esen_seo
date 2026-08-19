/// Assets and wrappers for permanent semantic DOM delivery.
library;

import '../components/seo_components.dart';
import '../components/seo_theme_transition.dart';
import '../routing/seo_route_delivery.dart';
import 'html_renderer.dart';
import 'seo_container.dart';
import 'seo_dom_first_carousel_runtime.g.dart';
import 'seo_dom_first_collection_runtime.g.dart';
import 'seo_dom_first_stepper_runtime.g.dart';
import 'seo_dom_first_tabs_runtime.g.dart';
import 'seo_dom_first_theme_toggle_runtime.g.dart';
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

/// Structural styles for the compiled DOM-first carousel control.
const String seoDomFirstCarouselStylesheet = '''
#$seoContainerId [data-esen-component="carousel"]>.esen-seo-carousel-controls{display:flex;align-items:center;justify-content:center;gap:.5rem;margin-block:.75rem}
#$seoContainerId [data-esen-component="carousel"] [data-esen-carousel-control]{font:inherit;color:inherit;background:transparent;border:1px solid currentColor;border-radius:4px;width:2.5rem;height:2.5rem;padding:0;cursor:pointer}
#$seoContainerId [data-esen-component="carousel"] [data-esen-carousel-control][disabled]{opacity:.4;cursor:default}
#$seoContainerId [data-esen-component="carousel"] [data-esen-carousel-control]:focus-visible{outline:2px solid currentColor;outline-offset:2px}
#$seoContainerId [data-esen-component="carousel"] .esen-seo-carousel-status{display:inline-block;min-width:4rem;text-align:center}
#$seoContainerId [data-esen-component="carousel"][data-esen-enhanced="true"]>section[data-esen-carousel-slide][hidden]{display:none}
''';

/// Structural styles for the compiled DOM-first stepper control.
const String seoDomFirstStepperStylesheet = '''
#$seoContainerId [data-esen-component="stepper"]>[data-esen-step-list]{list-style:none;padding:0}
#$seoContainerId [data-esen-component="stepper"] [data-esen-step-button]{font:inherit;color:inherit;background:transparent;border:0;padding:.5rem 0;cursor:pointer;text-align:start;width:100%;overflow-wrap:anywhere}
#$seoContainerId [data-esen-component="stepper"] [data-esen-step-button][aria-current="step"]{font-weight:600}
#$seoContainerId [data-esen-component="stepper"] [data-esen-step-button]:focus-visible{outline:2px solid currentColor;outline-offset:2px}
#$seoContainerId [data-esen-component="stepper"] .esen-seo-stepper-controls{display:flex;align-items:center;justify-content:space-between;gap:.5rem;margin-block:.75rem}
#$seoContainerId [data-esen-component="stepper"] [data-esen-stepper-control]{font:inherit;color:inherit;background:transparent;border:1px solid currentColor;border-radius:4px;padding:.5rem .75rem;cursor:pointer;flex:1;min-width:0;overflow-wrap:anywhere}
#$seoContainerId [data-esen-component="stepper"] [data-esen-stepper-control][aria-disabled="true"]{opacity:.4;cursor:default}
#$seoContainerId [data-esen-component="stepper"] [data-esen-stepper-control]:focus-visible{outline:2px solid currentColor;outline-offset:2px}
#$seoContainerId [data-esen-component="stepper"] .esen-seo-stepper-status{display:inline-block;min-width:6rem;text-align:center}
#$seoContainerId [data-esen-component="stepper"][data-esen-enhanced="true"] [data-esen-step-panel][hidden]{display:none}
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

/// Self-contained styling for the package-owned theme toggle control.
const String seoDomFirstThemeToggleStylesheet = '''
html{color-scheme:light}
html[data-esen-theme="light"]{color-scheme:light}
html[data-esen-theme="dark"]{color-scheme:dark}
@media (prefers-color-scheme:dark){html:not([data-esen-theme="light"]):not([data-esen-theme="dark"]){color-scheme:dark}}
#$seoContainerId [data-esen-component="theme-toggle"][data-esen-enhanced="true"]{display:inline-flex}
#$seoContainerId .esen-seo-theme-toggle-button{display:inline-flex;align-items:center;justify-content:center;gap:.375rem;min-width:5.75rem;min-height:2.5rem;padding:.4375rem .75rem;border:1px solid var(--esen-color-outline-variant,#bec9c6);border-radius:6px;background:var(--esen-color-surface-container-low,#eff5f2);color:var(--esen-color-on-surface,#171d1b);font:inherit;font-size:var(--esen-type-label-large-size,.875rem);font-weight:600;line-height:1;cursor:pointer}
#$seoContainerId .esen-seo-theme-toggle-button::before{content:"\\263e"}
#$seoContainerId .esen-seo-theme-toggle-button[data-esen-dark="true"]::before{content:"\\2600"}
#$seoContainerId .esen-seo-theme-toggle-button:hover{background:var(--esen-color-surface-container,#e9efed)}
#$seoContainerId .esen-seo-theme-toggle-button:focus-visible{outline:2px solid var(--esen-color-primary,#006b5f);outline-offset:2px}
@media (max-width:${seoThemeToggleCompactBreakpoint}px){#$seoContainerId [data-esen-component="theme-toggle"][data-esen-compact="true"] .esen-seo-theme-toggle-button{min-width:3rem;width:3rem;min-height:3rem;padding:.4375rem;gap:0;font-size:0}#$seoContainerId [data-esen-component="theme-toggle"][data-esen-compact="true"] .esen-seo-theme-toggle-button::before{font-size:var(--esen-type-label-large-size,.875rem)}}
''';

/// Marks the pre-paint theme restoration script in a generated document.
const String seoDomFirstBootstrapScriptAttribute =
    'data-esen-seo-dom-first-bootstrap';

/// Returns the package-owned pre-paint bootstrap for selected features.
String seoDomFirstFeatureBootstrapScriptHtml(
  Set<SeoDomFirstFeature> features, {
  String? nonce,
}) {
  if (!features.contains(SeoDomFirstFeature.themeToggle)) return '';
  final nonceAttribute = _nonceAttribute(nonce);
  return '<script $seoDomFirstBootstrapScriptAttribute$nonceAttribute>'
      '(()=>{try{let v=localStorage.getItem('
      '"$seoThemePreferenceStorageKey");if(v==="light"||v==="dark")'
      'document.documentElement.dataset.esenTheme=v}catch(_){}})()</script>';
}

/// Returns the style tag needed by the selected DOM-first [features].
String seoDomFirstFeatureStyleHtml(
  Set<SeoDomFirstFeature> features, {
  String? nonce,
}) {
  final css = StringBuffer();
  if (features.contains(SeoDomFirstFeature.tabs)) {
    css.write(seoDomFirstTabsStylesheet);
  }
  if (features.contains(SeoDomFirstFeature.carousel)) {
    css.write(seoDomFirstCarouselStylesheet);
  }
  if (features.contains(SeoDomFirstFeature.stepper)) {
    css.write(seoDomFirstStepperStylesheet);
  }
  if (features.contains(SeoDomFirstFeature.collection)) {
    css.write(seoDomFirstCollectionStylesheet);
  }
  if (features.contains(SeoDomFirstFeature.themeToggle)) {
    css.write(seoDomFirstThemeToggleStylesheet);
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
  final runtime = StringBuffer();

  void addRuntime(String javascript) {
    if (runtime.isNotEmpty) runtime.write(';');
    runtime.write(javascript);
  }

  if (features.contains(SeoDomFirstFeature.tabs)) {
    addRuntime(seoDomFirstTabsRuntime);
  }
  if (features.contains(SeoDomFirstFeature.carousel)) {
    addRuntime(seoDomFirstCarouselRuntime);
  }
  if (features.contains(SeoDomFirstFeature.stepper)) {
    addRuntime(seoDomFirstStepperRuntime);
  }
  if (features.contains(SeoDomFirstFeature.collection)) {
    addRuntime(seoDomFirstCollectionRuntime);
  }
  if (features.contains(SeoDomFirstFeature.themeToggle)) {
    addRuntime(seoDomFirstThemeToggleRuntime);
  }
  if (runtime.isEmpty) return '';
  return '<script $seoDomFirstScriptAttribute$nonceAttribute>'
      '$runtime</script>';
}

String _nonceAttribute(String? nonce) {
  final value = nonce?.trim();
  if (value == null || value.isEmpty) return '';
  return ' nonce="${HtmlRenderer.escapeAttribute(value)}"';
}
