/// Assets and wrappers for permanent semantic DOM delivery.
library;

import '../components/seo_components.dart';
import '../components/seo_theme_transition.dart';
import '../routing/seo_route_delivery.dart';
import '../routing/seo_application_runtime.dart';
import 'html_renderer.dart';
import 'seo_container.dart';
import 'seo_dom_first_carousel_runtime.g.dart';
import 'seo_dom_first_action_form_runtime.g.dart';
import 'seo_dom_first_action_flow_runtime.g.dart';
import 'seo_dom_first_collection_runtime.g.dart';
import 'seo_dom_first_navigation_application_handoff_runtime.g.dart';
import 'seo_dom_first_navigation_application_profile_runtime.g.dart';
import 'seo_dom_first_navigation_prefetch_runtime.g.dart';
import 'seo_dom_first_navigation_runtime.g.dart';
import 'seo_dom_first_navigation_handoff_runtime.g.dart';
import 'seo_dom_first_runtime_handoff.dart';
import 'seo_dom_first_stepper_runtime.g.dart';
import 'seo_dom_first_tabs_carousel_runtime.g.dart';
import 'seo_dom_first_tabs_runtime.g.dart';
import 'seo_dom_first_theme_toggle_runtime.g.dart';
import 'seo_motion_stylesheet.dart';
import 'seo_stylesheet.dart';

/// Marks the package-owned DOM-first runtime in a generated document.
const String seoDomFirstScriptAttribute = 'data-esen-seo-dom-first-runtime';

/// Structural styles for the compiled DOM-first tabs control.
const String seoDomFirstTabsStylesheet = '''
#$seoContainerId [data-esen-component="tabs"][data-esen-enhanced="true"]>.esen-seo-tab-list{display:flex;flex-wrap:wrap;gap:.5rem;border-bottom:1px solid currentColor;margin-bottom:1rem}
#$seoContainerId [data-esen-component="tabs"]>.esen-seo-tab-list>.esen-seo-tab{display:inline-flex;box-sizing:border-box;align-items:center;font:inherit;color:inherit;background:transparent;border:0;border-bottom:2px solid transparent;padding:.5rem .75rem;cursor:pointer}
#$seoContainerId [data-esen-component="tabs"]>.esen-seo-tab-list>.esen-seo-tab[aria-selected="true"],#$seoContainerId [data-esen-component="tabs"]>.esen-seo-tab-list>.esen-seo-tab[data-esen-placeholder-selected="true"]{border-bottom-color:currentColor;font-weight:600}
#$seoContainerId [data-esen-component="tabs"]>.esen-seo-tab-list>.esen-seo-tab:focus-visible{outline:2px solid currentColor;outline-offset:2px}
#$seoContainerId [data-esen-component="tabs"][data-esen-enhanced="true"]>section[data-esen-tab-panel][hidden]{display:none}
#$seoContainerId [data-esen-component="tabs"]>[data-esen-prepaint-placeholder="tabs"][hidden]{display:none!important}
html[data-esen-interaction-pending] #$seoContainerId [data-esen-component="tabs"][data-esen-layout-stable="true"]:not([data-esen-enhanced="true"])>[data-esen-prepaint-placeholder="tabs"][hidden]{display:flex!important;flex-wrap:wrap;gap:.5rem;border-bottom:1px solid currentColor;margin-bottom:1rem}
html[data-esen-interaction-pending] #$seoContainerId [data-esen-component="tabs"][data-esen-layout-stable="true"]:not([data-esen-enhanced="true"])>section[data-esen-tab-panel]:not([data-esen-initial-active="true"]){display:none}
html[data-esen-interaction-pending] #$seoContainerId [data-esen-component="tabs"][data-esen-layout-stable="true"]:not([data-esen-enhanced="true"])>section[data-esen-tab-panel][data-esen-initial-active="true"]>:first-child{display:none}
''';

/// Structural styles for the compiled DOM-first carousel control.
const String seoDomFirstCarouselStylesheet = '''
#$seoContainerId [data-esen-component="carousel"]>.esen-seo-carousel-controls{display:flex;align-items:center;justify-content:center;gap:.5rem;margin-block:.75rem}
#$seoContainerId [data-esen-component="carousel"] [data-esen-carousel-control],#$seoContainerId [data-esen-component="carousel"] .esen-seo-carousel-control-placeholder{display:inline-flex;box-sizing:border-box;align-items:center;justify-content:center;font:inherit;color:inherit;background:transparent;border:1px solid currentColor;border-radius:4px;width:2.5rem;min-width:2.5rem;height:2.5rem;min-height:2.5rem;padding:0}
#$seoContainerId [data-esen-component="carousel"] [data-esen-carousel-control]{cursor:pointer}
#$seoContainerId [data-esen-component="carousel"] [data-esen-carousel-control][disabled]{opacity:.4;cursor:default}
#$seoContainerId [data-esen-component="carousel"] [data-esen-carousel-control]:focus-visible{outline:2px solid currentColor;outline-offset:2px}
#$seoContainerId [data-esen-component="carousel"] .esen-seo-carousel-status{display:inline-block;min-width:4rem;text-align:center}
#$seoContainerId [data-esen-component="carousel"][data-esen-enhanced="true"]>section[data-esen-carousel-slide][hidden]{display:none}
#$seoContainerId [data-esen-component="carousel"] .esen-seo-carousel-control-placeholder[data-esen-placeholder-disabled="true"]{opacity:.4}
#$seoContainerId [data-esen-component="carousel"]>[data-esen-prepaint-placeholder="carousel"][hidden]{display:none!important}
html[data-esen-interaction-pending] #$seoContainerId [data-esen-component="carousel"][data-esen-layout-stable="true"]:not([data-esen-enhanced="true"])>[data-esen-prepaint-placeholder="carousel"][hidden]{display:flex!important}
html[data-esen-interaction-pending] #$seoContainerId [data-esen-component="carousel"][data-esen-layout-stable="true"]:not([data-esen-enhanced="true"])>section[data-esen-carousel-slide]:not([data-esen-initial-active="true"]){display:none}
''';

/// Structural styles for the compiled DOM-first stepper control.
const String seoDomFirstStepperStylesheet = '''
#$seoContainerId [data-esen-component="stepper"]>[data-esen-step-list]{list-style:none;padding:0}
#$seoContainerId [data-esen-component="stepper"] .esen-seo-step-button{display:block;box-sizing:border-box;font:inherit;color:inherit;background:transparent;border:0;padding:.5rem 0;cursor:pointer;text-align:start;width:100%;overflow-wrap:anywhere}
#$seoContainerId [data-esen-component="stepper"] [data-esen-step-button][aria-current="step"]{font-weight:600}
#$seoContainerId [data-esen-component="stepper"] [data-esen-step-button]:focus-visible{outline:2px solid currentColor;outline-offset:2px}
#$seoContainerId [data-esen-component="stepper"] .esen-seo-stepper-controls{display:flex;align-items:center;justify-content:space-between;gap:.5rem;margin-block:.75rem}
#$seoContainerId [data-esen-component="stepper"] [data-esen-stepper-control],#$seoContainerId [data-esen-component="stepper"] .esen-seo-stepper-control-placeholder{display:inline-flex;box-sizing:border-box;align-items:center;justify-content:center;font:inherit;color:inherit;background:transparent;border:1px solid currentColor;border-radius:4px;min-height:2.5rem;padding:.5rem .75rem;flex:1;min-width:0;overflow-wrap:anywhere}
#$seoContainerId [data-esen-component="stepper"] [data-esen-stepper-control]{cursor:pointer}
#$seoContainerId [data-esen-component="stepper"] [data-esen-stepper-control][aria-disabled="true"]{opacity:.4;cursor:default}
#$seoContainerId [data-esen-component="stepper"] [data-esen-stepper-control]:focus-visible{outline:2px solid currentColor;outline-offset:2px}
#$seoContainerId [data-esen-component="stepper"] .esen-seo-stepper-status{display:inline-block;min-width:6rem;text-align:center}
#$seoContainerId [data-esen-component="stepper"][data-esen-enhanced="true"] [data-esen-step-panel][hidden]{display:none}
#$seoContainerId [data-esen-component="stepper"] .esen-seo-stepper-control-placeholder[data-esen-placeholder-disabled="true"]{opacity:.4}
#$seoContainerId [data-esen-component="stepper"]>[data-esen-prepaint-placeholder="stepper"][hidden],#$seoContainerId [data-esen-component="stepper"] [data-esen-prepaint-placeholder="stepper-button"][hidden]{display:none!important}
html[data-esen-interaction-pending] #$seoContainerId [data-esen-component="stepper"][data-esen-layout-stable="true"]:not([data-esen-enhanced="true"])>[data-esen-prepaint-placeholder="stepper"][hidden]{display:flex!important}
html[data-esen-interaction-pending] #$seoContainerId [data-esen-component="stepper"][data-esen-layout-stable="true"]:not([data-esen-enhanced="true"])>[data-esen-step-list]>[data-esen-step]>[data-esen-prepaint-placeholder="stepper-button"][hidden]{display:block!important}
html[data-esen-interaction-pending] #$seoContainerId [data-esen-component="stepper"][data-esen-layout-stable="true"]:not([data-esen-enhanced="true"])>[data-esen-step-list]>[data-esen-step]>[data-esen-step-heading]{display:none}
html[data-esen-interaction-pending] #$seoContainerId [data-esen-component="stepper"][data-esen-layout-stable="true"]:not([data-esen-enhanced="true"])>[data-esen-step-list]>[data-esen-step]>[data-esen-step-panel]:not([data-esen-initial-active="true"]){display:none}
''';

/// Structural styles for the compiled DOM-first collection control.
const String seoDomFirstCollectionStylesheet = '''
#$seoContainerId [data-esen-component="collection"]>.esen-seo-collection-placeholder{display:none}
html[data-esen-collection-pending] #$seoContainerId [data-esen-component="collection"]>.esen-seo-collection-placeholder[hidden]{display:block!important}
#$seoContainerId [data-esen-component="collection"]>.esen-seo-collection-toolbar{display:grid;gap:.75rem;margin-bottom:1rem}
#$seoContainerId [data-esen-component="collection"]>.esen-seo-collection-toolbar label,#$seoContainerId [data-esen-component="collection"] .esen-seo-collection-search{display:grid;gap:.375rem}
#$seoContainerId [data-esen-component="collection"]>.esen-seo-collection-toolbar input,#$seoContainerId [data-esen-component="collection"] .esen-seo-collection-input-placeholder{display:block;box-sizing:border-box;min-height:2.75rem;font:inherit;color:inherit;background:transparent;border:1px solid currentColor;border-radius:6px;padding:.5rem .75rem}
#$seoContainerId [data-esen-component="collection"] .esen-seo-collection-categories,#$seoContainerId [data-esen-component="collection"] .esen-seo-collection-sort{display:grid;gap:.375rem}
#$seoContainerId [data-esen-component="collection"] .esen-seo-collection-category-options,#$seoContainerId [data-esen-component="collection"] .esen-seo-collection-sort-options{display:flex;flex-wrap:wrap;gap:.5rem}
#$seoContainerId [data-esen-component="collection"] [data-esen-collection-category],#$seoContainerId [data-esen-component="collection"] [data-esen-collection-sort],#$seoContainerId [data-esen-component="collection"] .esen-seo-collection-pagination>button,#$seoContainerId [data-esen-component="collection"] .esen-seo-collection-control-placeholder{display:inline-flex;box-sizing:border-box;align-items:center;justify-content:center;min-width:2.75rem;min-height:2.75rem;font:inherit;color:inherit;background:transparent;border:1px solid currentColor;border-radius:6px;padding:.5rem .75rem;cursor:pointer}
#$seoContainerId [data-esen-component="collection"] .esen-seo-collection-control-placeholder{cursor:default}
#$seoContainerId [data-esen-component="collection"] [aria-pressed="true"],#$seoContainerId [data-esen-component="collection"] [data-esen-placeholder-selected="true"]{font-weight:700;border-width:2px}
#$seoContainerId [data-esen-component="collection"] .esen-seo-collection-results{margin:0 0 .75rem}
#$seoContainerId [data-esen-component="collection"] .esen-seo-collection-empty{margin:1rem 0}
#$seoContainerId [data-esen-component="collection"] .esen-seo-collection-pagination{display:flex;align-items:center;justify-content:space-between;gap:.75rem;margin-top:1rem}
#$seoContainerId [data-esen-component="collection"] .esen-seo-collection-pagination>button[disabled]{opacity:.4;cursor:default}
#$seoContainerId [data-esen-component="collection"] input:focus-visible,#$seoContainerId [data-esen-component="collection"] button:focus-visible{outline:2px solid currentColor;outline-offset:2px}
#$seoContainerId [data-esen-component="collection"] [hidden]{display:none}
''';

/// Structural styling for the closed DOM-first configurator controls.
const String seoDomFirstConfiguratorStylesheet = '''
#$seoContainerId [data-esen-component="configurator"]>.esen-seo-configurator-controls{display:grid;gap:1rem;margin-block:1.25rem;padding:1rem;border:1px solid var(--esen-color-outline-variant,#bec9c6);border-radius:8px;background:var(--esen-color-surface-container-low,#eff5f2)}
#$seoContainerId [data-esen-component="configurator"] .esen-seo-configurator-choices{display:grid;grid-template-columns:repeat(auto-fit,minmax(min(9rem,100%),1fr));gap:.5rem}
#$seoContainerId [data-esen-component="configurator"] [data-esen-configurator-choice-control],#$seoContainerId [data-esen-component="configurator"] [data-esen-configurator-option-control],#$seoContainerId [data-esen-component="configurator"] [data-esen-configurator-decrement],#$seoContainerId [data-esen-component="configurator"] [data-esen-configurator-increment],#$seoContainerId [data-esen-component="configurator"] .esen-seo-configurator-control-placeholder{display:inline-flex;box-sizing:border-box;align-items:center;justify-content:center;min-height:2.75rem;padding:.5rem .75rem;border:1px solid var(--esen-color-outline-variant,#bec9c6);border-radius:6px;background:var(--esen-color-surface,#f5fbf8);color:var(--esen-color-on-surface,#171d1b);font:inherit;font-weight:600;text-align:center;overflow-wrap:anywhere}
#$seoContainerId [data-esen-component="configurator"] button{cursor:pointer}
#$seoContainerId [data-esen-component="configurator"] [role="radio"][aria-checked="true"],#$seoContainerId [data-esen-component="configurator"] [data-esen-configurator-option-control][aria-pressed="true"],#$seoContainerId [data-esen-component="configurator"] [data-esen-placeholder-selected="true"]{border-color:var(--esen-color-primary,#006b5f);background:var(--esen-color-primary-container,#9ef2df);color:var(--esen-color-on-primary-container,#00201b)}
#$seoContainerId [data-esen-component="configurator"] .esen-seo-configurator-quantity{display:grid;grid-template-columns:minmax(2.75rem,auto) minmax(4rem,1fr) minmax(2.75rem,auto);align-items:stretch;gap:.5rem}
#$seoContainerId [data-esen-component="configurator"] .esen-seo-configurator-quantity-value{display:flex;align-items:center;justify-content:center;min-height:2.75rem;font-weight:700;font-variant-numeric:tabular-nums}
#$seoContainerId [data-esen-component="configurator"] button[disabled],#$seoContainerId [data-esen-component="configurator"] [data-esen-placeholder-disabled="true"]{opacity:.45;cursor:default}
#$seoContainerId [data-esen-component="configurator"] button:focus-visible{outline:2px solid var(--esen-color-primary,#006b5f);outline-offset:2px}
#$seoContainerId [data-esen-component="configurator"]>.esen-seo-configurator-price{font-size:1.375rem}
#$seoContainerId [data-esen-component="configurator"]>.esen-seo-configurator-status{position:absolute;width:1px;height:1px;padding:0;margin:-1px;overflow:hidden;clip:rect(0,0,0,0);white-space:nowrap;border:0}
#$seoContainerId [data-esen-component="configurator"]>[data-esen-prepaint-placeholder="configurator"][hidden]{display:none!important}
html[data-esen-interaction-pending] #$seoContainerId [data-esen-component="configurator"][data-esen-layout-stable="true"]:not([data-esen-enhanced="true"])>[data-esen-prepaint-placeholder="configurator"][hidden]{display:grid!important}
html[data-esen-interaction-pending] #$seoContainerId [data-esen-component="configurator"][data-esen-layout-stable="true"]:not([data-esen-enhanced="true"])>section[data-esen-configurator-choice-region]:not([data-esen-initial-active="true"]){display:none}
html[data-esen-interaction-pending] #$seoContainerId [data-esen-component="configurator"][data-esen-layout-stable="true"]:not([data-esen-enhanced="true"])>section[data-esen-configurator-option-region]:not([data-esen-initial-visible="true"]){display:none}
#$seoContainerId [data-esen-component="configurator"][data-esen-enhanced="true"]:not([data-esen-configurator-changed="true"])>section[data-esen-configurator-choice-region]:not([data-esen-initial-active="true"]){display:none}
#$seoContainerId [data-esen-component="configurator"][data-esen-enhanced="true"]:not([data-esen-configurator-changed="true"])>section[data-esen-configurator-option-region]:not([data-esen-initial-visible="true"]){display:none}
#$seoContainerId [data-esen-component="configurator"][data-esen-configurator-changed="true"]>section[hidden]{display:none}
''';

/// Structural styling for the closed editorial workflow controls.
const String seoDomFirstEditorialWorkflowStylesheet = '''
#$seoContainerId [data-esen-component="editorial-workflow"]>.esen-seo-editorial-workflow-controls{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:.5rem;margin-block:1.25rem;padding:1rem;border:1px solid var(--esen-color-outline-variant,#bec9c6);border-radius:8px;background:var(--esen-color-surface-container-low,#eff5f2)}
#$seoContainerId [data-esen-component="editorial-workflow"] .esen-seo-editorial-workflow-controls>button,#$seoContainerId [data-esen-component="editorial-workflow"] .esen-seo-editorial-workflow-control-placeholder{display:inline-flex;box-sizing:border-box;align-items:center;justify-content:center;min-height:2.75rem;padding:.5rem .75rem;border:1px solid var(--esen-color-outline-variant,#bec9c6);border-radius:6px;background:var(--esen-color-surface,#f5fbf8);color:var(--esen-color-on-surface,#171d1b);font:inherit;font-weight:600;text-align:center;overflow-wrap:anywhere}
#$seoContainerId [data-esen-component="editorial-workflow"] .esen-seo-editorial-workflow-controls>button{cursor:pointer}
#$seoContainerId [data-esen-component="editorial-workflow"] .esen-seo-editorial-workflow-controls>button[disabled],#$seoContainerId [data-esen-component="editorial-workflow"] [data-esen-placeholder-disabled="true"]{opacity:.45;cursor:default}
#$seoContainerId [data-esen-component="editorial-workflow"] button:focus-visible,#$seoContainerId [data-esen-component="editorial-workflow"]:focus-visible{outline:2px solid var(--esen-color-primary,#006b5f);outline-offset:2px}
#$seoContainerId [data-esen-component="editorial-workflow"]>.esen-seo-editorial-workflow-status{font-size:1.375rem}
#$seoContainerId [data-esen-component="editorial-workflow"]>.esen-seo-editorial-workflow-progress{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:.5rem;padding:0;list-style:none}
#$seoContainerId [data-esen-component="editorial-workflow"]>.esen-seo-editorial-workflow-progress>li{padding:.5rem;border-bottom:2px solid var(--esen-color-outline-variant,#bec9c6);text-align:center;overflow-wrap:anywhere}
#$seoContainerId [data-esen-component="editorial-workflow"]>.esen-seo-editorial-workflow-progress>[aria-current="step"]{border-color:var(--esen-color-primary,#006b5f);color:var(--esen-color-primary,#006b5f);font-weight:700}
#$seoContainerId [data-esen-component="editorial-workflow"]>.esen-seo-editorial-workflow-history{padding-inline-start:1.5rem}
#$seoContainerId [data-esen-component="editorial-workflow"]>.esen-seo-editorial-workflow-announcement{position:absolute;width:1px;height:1px;padding:0;margin:-1px;overflow:hidden;clip:rect(0,0,0,0);white-space:nowrap;border:0}
#$seoContainerId [data-esen-component="editorial-workflow"]>[data-esen-prepaint-placeholder="editorial-workflow"][hidden]{display:none!important}
html[data-esen-interaction-pending] #$seoContainerId [data-esen-component="editorial-workflow"][data-esen-layout-stable="true"]:not([data-esen-enhanced="true"])>[data-esen-prepaint-placeholder="editorial-workflow"][hidden]{display:grid!important}
html[data-esen-interaction-pending] #$seoContainerId [data-esen-component="editorial-workflow"][data-esen-layout-stable="true"]:not([data-esen-enhanced="true"])>section[data-esen-workflow-stage-region]:not([data-esen-initial-active="true"]){display:none}
#$seoContainerId [data-esen-component="editorial-workflow"][data-esen-enhanced="true"]:not([data-esen-workflow-changed="true"])>section[data-esen-workflow-stage-region]:not([data-esen-initial-active="true"]){display:none}
#$seoContainerId [data-esen-component="editorial-workflow"][data-esen-workflow-changed="true"]>section[hidden]{display:none}
@media (max-width:600px){#$seoContainerId [data-esen-component="editorial-workflow"]>.esen-seo-editorial-workflow-progress{grid-template-columns:repeat(2,minmax(0,1fr))}}
''';

/// Structural styling for the closed approval checklist controls.
const String seoDomFirstApprovalChecklistStylesheet = '''
#$seoContainerId [data-esen-component="approval-checklist"]>.esen-seo-approval-checklist-controls{display:grid;grid-template-columns:repeat(auto-fit,minmax(min(12rem,100%),1fr));gap:.5rem;margin-block:1.25rem}
#$seoContainerId [data-esen-component="approval-checklist"] .esen-seo-approval-checklist-controls>button,#$seoContainerId [data-esen-component="approval-checklist"] .esen-seo-approval-checklist-control-placeholder{display:inline-flex;box-sizing:border-box;align-items:center;justify-content:flex-start;min-height:2.75rem;padding:.5rem .75rem;border:1px solid var(--esen-color-outline-variant,#bec9c6);border-radius:6px;background:var(--esen-color-surface,#f5fbf8);color:var(--esen-color-on-surface,#171d1b);font:inherit;font-weight:600;text-align:left;overflow-wrap:anywhere}
#$seoContainerId [data-esen-component="approval-checklist"] .esen-seo-approval-checklist-controls>button{cursor:pointer}
#$seoContainerId [data-esen-component="approval-checklist"] [role="checkbox"]::before,#$seoContainerId [data-esen-component="approval-checklist"] [data-esen-placeholder-checked]::before{content:"";box-sizing:border-box;width:1rem;height:1rem;flex:0 0 1rem;margin-inline-end:.625rem;border:2px solid currentColor;border-radius:3px}
#$seoContainerId [data-esen-component="approval-checklist"] [role="checkbox"][aria-checked="true"]::before,#$seoContainerId [data-esen-component="approval-checklist"] [data-esen-placeholder-checked="true"]::before{background:var(--esen-color-primary,#006b5f);box-shadow:inset 0 0 0 2px var(--esen-color-surface,#f5fbf8)}
#$seoContainerId [data-esen-component="approval-checklist"] button:focus-visible{outline:2px solid var(--esen-color-primary,#006b5f);outline-offset:2px}
#$seoContainerId [data-esen-component="approval-checklist"]>.esen-seo-approval-checklist-progress{display:flex;align-items:center;justify-content:center;box-sizing:border-box;min-height:2.75rem;margin-block:.75rem;padding:.5rem .75rem;border:1px solid var(--esen-color-outline-variant,#bec9c6);border-radius:6px;font-weight:700;font-variant-numeric:tabular-nums}
#$seoContainerId [data-esen-component="approval-checklist"]>.esen-seo-approval-checklist-items{display:grid;gap:.75rem;padding:0;list-style:none}
#$seoContainerId [data-esen-component="approval-checklist"]>.esen-seo-approval-checklist-items>li{padding:1rem;border:1px solid var(--esen-color-outline-variant,#bec9c6);border-radius:8px}
#$seoContainerId [data-esen-component="approval-checklist"]>.esen-seo-approval-checklist-announcement{position:absolute;width:1px;height:1px;padding:0;margin:-1px;overflow:hidden;clip:rect(0,0,0,0);white-space:nowrap;border:0}
#$seoContainerId [data-esen-component="approval-checklist"]>[data-esen-prepaint-placeholder="approval-checklist"][hidden]{display:none!important}
html[data-esen-interaction-pending] #$seoContainerId [data-esen-component="approval-checklist"][data-esen-layout-stable="true"]:not([data-esen-enhanced="true"])>[data-esen-prepaint-placeholder="approval-checklist"][hidden]{display:grid!important}
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

/// Structural styling for the curated DOM-first action form.
const String seoDomFirstActionFormStylesheet = '''
#$seoContainerId [data-esen-component="action-form"]>form{display:grid;gap:1rem;margin-top:1.25rem}
#$seoContainerId [data-esen-component="action-form"] .esen-seo-action-form-field{display:grid;gap:.375rem}
#$seoContainerId [data-esen-component="action-form"] label{font-weight:600}
#$seoContainerId [data-esen-component="action-form"] input:not([type="checkbox"]),#$seoContainerId [data-esen-component="action-form"] textarea,#$seoContainerId [data-esen-component="action-form"] select{box-sizing:border-box;width:100%;min-height:2.75rem;padding:.625rem .75rem;border:1px solid var(--esen-color-outline-variant,#bec9c6);border-radius:6px;background:var(--esen-color-surface,#f5fbf8);color:var(--esen-color-on-surface,#171d1b);font:inherit}
#$seoContainerId [data-esen-component="action-form"] textarea{min-height:8rem;resize:vertical}
#$seoContainerId [data-esen-component="action-form"] input[type="checkbox"]{width:1.25rem;height:1.25rem;margin:0}
#$seoContainerId [data-esen-component="action-form"] [data-esen-action-form-kind="consent"]{grid-template-columns:1.25rem minmax(0,1fr);align-items:start}
#$seoContainerId [data-esen-component="action-form"] [data-esen-action-form-kind="consent"]>label{grid-column:2;grid-row:1}
#$seoContainerId [data-esen-component="action-form"] [data-esen-action-form-kind="consent"]>input{grid-column:1;grid-row:1}
#$seoContainerId [data-esen-component="action-form"] [data-esen-action-form-kind="consent"]>.esen-seo-action-form-hint,#$seoContainerId [data-esen-component="action-form"] [data-esen-action-form-kind="consent"]>.esen-seo-action-form-error{grid-column:2}
#$seoContainerId [data-esen-component="action-form"] button[type="submit"]{display:inline-flex;align-items:center;justify-content:center;min-height:2.75rem;padding:.625rem 1rem;border:1px solid var(--esen-color-primary,#006b5f);border-radius:6px;background:var(--esen-color-primary,#006b5f);color:var(--esen-color-on-primary,#fff);font:inherit;font-weight:700;cursor:pointer}
#$seoContainerId [data-esen-component="action-form"] button[disabled]{opacity:.55;cursor:wait}
#$seoContainerId [data-esen-component="action-form"] input:focus-visible,#$seoContainerId [data-esen-component="action-form"] textarea:focus-visible,#$seoContainerId [data-esen-component="action-form"] select:focus-visible,#$seoContainerId [data-esen-component="action-form"] button:focus-visible{outline:2px solid var(--esen-color-primary,#006b5f);outline-offset:2px}
#$seoContainerId [data-esen-component="action-form"] .esen-seo-action-form-description,#$seoContainerId [data-esen-component="action-form"] .esen-seo-action-form-hint{margin:.25rem 0;color:var(--esen-color-on-surface-variant,#3f4946)}
#$seoContainerId [data-esen-component="action-form"] .esen-seo-action-form-error{color:var(--esen-color-error,#ba1a1a);font-weight:600}
#$seoContainerId [data-esen-component="action-form"] .esen-seo-action-form-error[hidden]{display:none}
#$seoContainerId [data-esen-component="action-form"] .esen-seo-action-form-status:empty{display:none}
''';

/// Structural styling for the curated DOM-first action flow.
const String seoDomFirstActionFlowStylesheet = '''
#$seoContainerId [data-esen-component="action-flow"]>form{display:grid;gap:1rem;margin-top:1.25rem}
#$seoContainerId [data-esen-component="action-flow"] .esen-seo-action-flow-progress{display:grid;grid-template-columns:repeat(auto-fit,minmax(min(8rem,100%),1fr));gap:.5rem;padding:0;list-style:none}
#$seoContainerId [data-esen-component="action-flow"] .esen-seo-action-flow-progress>li{padding:.5rem;border-bottom:2px solid var(--esen-color-outline-variant,#bec9c6);text-align:center;overflow-wrap:anywhere}
#$seoContainerId [data-esen-component="action-flow"] .esen-seo-action-flow-progress>[aria-current="step"]{border-color:var(--esen-color-primary,#006b5f);color:var(--esen-color-primary,#006b5f);font-weight:700}
#$seoContainerId [data-esen-component="action-flow"] .esen-seo-action-flow-step{display:grid;gap:1rem}
#$seoContainerId [data-esen-component="action-flow"] .esen-seo-action-flow-review{display:grid;gap:1rem}
#$seoContainerId [data-esen-component="action-flow"] .esen-seo-action-flow-review dl{display:grid;gap:.75rem;margin:0}
#$seoContainerId [data-esen-component="action-flow"] .esen-seo-action-flow-review dl>div{display:grid;grid-template-columns:minmax(7rem,1fr) minmax(0,2fr);gap:.75rem;padding:.75rem 0;border-bottom:1px solid var(--esen-color-outline-variant,#bec9c6)}
#$seoContainerId [data-esen-component="action-flow"] .esen-seo-action-flow-review dl>div[hidden]{display:none}
#$seoContainerId [data-esen-component="action-flow"] .esen-seo-action-flow-review dt{font-weight:700}
#$seoContainerId [data-esen-component="action-flow"] .esen-seo-action-flow-review dd{margin:0;white-space:pre-wrap;overflow-wrap:anywhere}
#$seoContainerId [data-esen-component="action-flow"] .esen-seo-action-form-field{display:grid;gap:.375rem}
#$seoContainerId [data-esen-component="action-flow"] label{font-weight:600}
#$seoContainerId [data-esen-component="action-flow"] input:not([type="checkbox"]),#$seoContainerId [data-esen-component="action-flow"] textarea,#$seoContainerId [data-esen-component="action-flow"] select{box-sizing:border-box;width:100%;min-height:2.75rem;padding:.625rem .75rem;border:1px solid var(--esen-color-outline-variant,#bec9c6);border-radius:6px;background:var(--esen-color-surface,#f5fbf8);color:var(--esen-color-on-surface,#171d1b);font:inherit}
#$seoContainerId [data-esen-component="action-flow"] textarea{min-height:8rem;resize:vertical}
#$seoContainerId [data-esen-component="action-flow"] input[type="checkbox"]{width:1.25rem;height:1.25rem;margin:0}
#$seoContainerId [data-esen-component="action-flow"] [data-esen-action-form-kind="consent"]{grid-template-columns:1.25rem minmax(0,1fr);align-items:start}
#$seoContainerId [data-esen-component="action-flow"] [data-esen-action-form-kind="consent"]>label{grid-column:2;grid-row:1}
#$seoContainerId [data-esen-component="action-flow"] [data-esen-action-form-kind="consent"]>input{grid-column:1;grid-row:1}
#$seoContainerId [data-esen-component="action-flow"] [data-esen-action-form-kind="consent"]>.esen-seo-action-form-hint,#$seoContainerId [data-esen-component="action-flow"] [data-esen-action-form-kind="consent"]>.esen-seo-action-form-error{grid-column:2}
#$seoContainerId [data-esen-component="action-flow"] .esen-seo-action-flow-navigation{display:flex;justify-content:space-between;gap:.75rem}
#$seoContainerId [data-esen-component="action-flow"] button{display:inline-flex;align-items:center;justify-content:center;min-height:2.75rem;padding:.625rem 1rem;border:1px solid var(--esen-color-primary,#006b5f);border-radius:6px;background:var(--esen-color-primary,#006b5f);color:var(--esen-color-on-primary,#fff);font:inherit;font-weight:700;cursor:pointer}
#$seoContainerId [data-esen-component="action-flow"] [data-esen-action-flow-previous]{background:transparent;color:var(--esen-color-primary,#006b5f)}
#$seoContainerId [data-esen-component="action-flow"] button[disabled]{opacity:.55;cursor:wait}
#$seoContainerId [data-esen-component="action-flow"] [hidden]{display:none}
#$seoContainerId [data-esen-component="action-flow"] input:focus-visible,#$seoContainerId [data-esen-component="action-flow"] textarea:focus-visible,#$seoContainerId [data-esen-component="action-flow"] select:focus-visible,#$seoContainerId [data-esen-component="action-flow"] button:focus-visible,#$seoContainerId [data-esen-component="action-flow"] [tabindex="-1"]:focus-visible{outline:2px solid var(--esen-color-primary,#006b5f);outline-offset:2px}
#$seoContainerId [data-esen-component="action-flow"] .esen-seo-action-form-description,#$seoContainerId [data-esen-component="action-flow"] .esen-seo-action-form-hint{margin:.25rem 0;color:var(--esen-color-on-surface-variant,#3f4946)}
#$seoContainerId [data-esen-component="action-flow"] .esen-seo-action-form-error{color:var(--esen-color-error,#ba1a1a);font-weight:600}
#$seoContainerId [data-esen-component="action-flow"] .esen-seo-action-form-status:empty{display:none}
html[data-esen-interaction-pending] #$seoContainerId [data-esen-component="action-flow"][data-esen-layout-stable="true"]:not([data-esen-enhanced="true"])>form>.esen-seo-action-flow-step:not([data-esen-action-flow-step="0"]){display:none}
html[data-esen-interaction-pending] #$seoContainerId [data-esen-component="action-flow"][data-esen-layout-stable="true"]:not([data-esen-enhanced="true"])>form>[data-esen-action-flow-navigation][hidden]{display:flex!important;visibility:hidden}
html[data-esen-interaction-pending] #$seoContainerId [data-esen-component="action-flow"][data-esen-layout-stable="true"]:not([data-esen-enhanced="true"])>form>[data-esen-action-form-submit]{display:none}
@media(max-width:36rem){#$seoContainerId [data-esen-component="action-flow"] .esen-seo-action-flow-review dl>div{grid-template-columns:1fr;gap:.25rem}}
''';

/// Marks the pre-paint theme restoration script in a generated document.
const String seoDomFirstBootstrapScriptAttribute =
    'data-esen-seo-dom-first-bootstrap';

/// Returns the package-owned pre-paint bootstrap for selected features.
String seoDomFirstFeatureBootstrapScriptHtml(
  Set<SeoDomFirstFeature> features, {
  String? nonce,
}) {
  final theme = features.contains(SeoDomFirstFeature.themeToggle);
  final collection = features.contains(SeoDomFirstFeature.collection);
  final interaction = features.contains(SeoDomFirstFeature.tabs) ||
      features.contains(SeoDomFirstFeature.carousel) ||
      features.contains(SeoDomFirstFeature.stepper) ||
      features.contains(SeoDomFirstFeature.configurator) ||
      features.contains(SeoDomFirstFeature.editorialWorkflow) ||
      features.contains(SeoDomFirstFeature.approvalChecklist) ||
      features.contains(SeoDomFirstFeature.actionFlow);
  if (!theme && !collection && !interaction) return '';
  final nonceAttribute = _nonceAttribute(nonce);
  final javascript = StringBuffer();
  if (theme) {
    javascript.write(
      '(()=>{try{let v=localStorage.getItem('
      '"$seoThemePreferenceStorageKey");if(v==="light"||v==="dark")'
      'document.documentElement.dataset.esenTheme=v}catch(_){}})()',
    );
  }
  if (collection) {
    if (javascript.isNotEmpty) javascript.write(';');
    javascript.write(
      'document.documentElement.dataset.esenCollectionPending=1;'
      'addEventListener("DOMContentLoaded",'
      '()=>delete document.documentElement.dataset.esenCollectionPending)',
    );
  }
  if (interaction) {
    if (javascript.isNotEmpty) javascript.write(';');
    javascript.write(
      'document.documentElement.dataset.esenInteractionPending=1;'
      'addEventListener("DOMContentLoaded",()=>setTimeout('
      '()=>delete document.documentElement.dataset.esenInteractionPending))',
    );
  }
  return '<script $seoDomFirstBootstrapScriptAttribute$nonceAttribute>'
      '$javascript</script>';
}

/// Returns the style tag needed by the selected DOM-first [features].
String seoDomFirstFeatureStyleHtml(
  Set<SeoDomFirstFeature> features, {
  String? nonce,
  SeoDomFirstApplicationRuntimeKind? applicationRuntimeHandoffKind,
}) {
  final css = StringBuffer();
  if (features.contains(SeoDomFirstFeature.tabs) ||
      applicationRuntimeHandoffKind == SeoDomFirstApplicationRuntimeKind.tabs) {
    css.write(seoDomFirstTabsStylesheet);
  }
  if (features.contains(SeoDomFirstFeature.carousel) ||
      applicationRuntimeHandoffKind ==
          SeoDomFirstApplicationRuntimeKind.carousel) {
    css.write(seoDomFirstCarouselStylesheet);
  }
  if (features.contains(SeoDomFirstFeature.stepper)) {
    css.write(seoDomFirstStepperStylesheet);
  }
  if (features.contains(SeoDomFirstFeature.collection)) {
    css.write(seoDomFirstCollectionStylesheet);
  } else if (features.contains(SeoDomFirstFeature.runtimeHandoff) ||
      (features.contains(SeoDomFirstFeature.applicationRuntimeHandoff) &&
          (applicationRuntimeHandoffKind == null ||
              applicationRuntimeHandoffKind ==
                  SeoDomFirstApplicationRuntimeKind.collection))) {
    // Handoff routes keep this stylesheet stable while the Collection runtime
    // itself remains route-local and loadable.
    css.write(seoDomFirstCollectionStylesheet);
  }
  if (features.contains(SeoDomFirstFeature.configurator) ||
      applicationRuntimeHandoffKind ==
          SeoDomFirstApplicationRuntimeKind.configurator) {
    css.write(seoDomFirstConfiguratorStylesheet);
  }
  if (features.contains(SeoDomFirstFeature.editorialWorkflow) ||
      applicationRuntimeHandoffKind ==
          SeoDomFirstApplicationRuntimeKind.editorialWorkflow) {
    css.write(seoDomFirstEditorialWorkflowStylesheet);
  }
  if (features.contains(SeoDomFirstFeature.approvalChecklist) ||
      applicationRuntimeHandoffKind ==
          SeoDomFirstApplicationRuntimeKind.approvalChecklist) {
    css.write(seoDomFirstApprovalChecklistStylesheet);
  }
  if (features.contains(SeoDomFirstFeature.actionForm)) {
    css.write(seoDomFirstActionFormStylesheet);
  }
  if (features.contains(SeoDomFirstFeature.actionFlow)) {
    css.write(seoDomFirstActionFlowStylesheet);
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
  int? applicationRuntimeHandoffSchema,
}) {
  if (features.contains(SeoDomFirstFeature.prefetch) &&
      !features.contains(SeoDomFirstFeature.navigation)) {
    throw ArgumentError.value(
      features,
      'features',
      'prefetch requires navigation',
    );
  }
  if (features.contains(SeoDomFirstFeature.runtimeHandoff) &&
      !features.contains(SeoDomFirstFeature.navigation)) {
    throw ArgumentError.value(
      features,
      'features',
      'runtimeHandoff requires navigation',
    );
  }
  if (features.contains(SeoDomFirstFeature.applicationRuntimeHandoff) &&
      !features.contains(SeoDomFirstFeature.navigation)) {
    throw ArgumentError.value(
      features,
      'features',
      'applicationRuntimeHandoff requires navigation',
    );
  }
  if (features.contains(SeoDomFirstFeature.navigation) &&
      !isSeoDomFirstNavigationFeatureProfile(features)) {
    throw ArgumentError.value(
      features,
      'features',
      'invalid DOM-first navigation feature profile',
    );
  }
  if (features.contains(SeoDomFirstFeature.applicationRuntimeHandoff) &&
      applicationRuntimeHandoffSchema != null &&
      applicationRuntimeHandoffSchema != 3 &&
      applicationRuntimeHandoffSchema != 4) {
    throw ArgumentError.value(
      applicationRuntimeHandoffSchema,
      'applicationRuntimeHandoffSchema',
      'must be manifest schema 3 or 4',
    );
  }
  final nonceAttribute = _nonceAttribute(nonce);
  final runtime = StringBuffer();

  void addRuntime(String javascript) {
    if (runtime.isNotEmpty) runtime.write(';');
    runtime.write(javascript);
  }

  if (features.contains(SeoDomFirstFeature.navigation)) {
    addRuntime(
      features.contains(SeoDomFirstFeature.applicationRuntimeHandoff)
          ? applicationRuntimeHandoffSchema == 4
              ? seoDomFirstNavigationApplicationProfileRuntime
              : seoDomFirstNavigationApplicationHandoffRuntime
          : features.contains(SeoDomFirstFeature.runtimeHandoff)
              ? seoDomFirstNavigationHandoffRuntime
              : features.contains(SeoDomFirstFeature.prefetch)
                  ? seoDomFirstNavigationPrefetchRuntime
                  : seoDomFirstNavigationRuntime,
    );
  }

  final tabs = features.contains(SeoDomFirstFeature.tabs);
  final carousel = features.contains(SeoDomFirstFeature.carousel);
  if (tabs && carousel) {
    addRuntime(seoDomFirstTabsCarouselRuntime);
  } else {
    if (tabs) addRuntime(seoDomFirstTabsRuntime);
    if (carousel) addRuntime(seoDomFirstCarouselRuntime);
  }
  if (features.contains(SeoDomFirstFeature.stepper)) {
    addRuntime(seoDomFirstStepperRuntime);
  }
  if (features.contains(SeoDomFirstFeature.collection) &&
      !features.contains(SeoDomFirstFeature.runtimeHandoff)) {
    addRuntime(seoDomFirstCollectionRuntime);
  }
  if (features.contains(SeoDomFirstFeature.actionForm)) {
    addRuntime(seoDomFirstActionFormRuntime);
  }
  if (features.contains(SeoDomFirstFeature.actionFlow)) {
    addRuntime(seoDomFirstActionFlowRuntime);
  }
  if (features.contains(SeoDomFirstFeature.themeToggle)) {
    addRuntime(seoDomFirstThemeToggleRuntime);
  }
  if (runtime.isEmpty) return '';
  if (features.contains(SeoDomFirstFeature.collection) &&
      !features.contains(SeoDomFirstFeature.runtimeHandoff)) {
    runtime.write(
      ';delete document.documentElement.dataset.esenCollectionPending',
    );
  }
  if (tabs ||
      carousel ||
      features.contains(SeoDomFirstFeature.stepper) ||
      features.contains(SeoDomFirstFeature.configurator) ||
      features.contains(SeoDomFirstFeature.editorialWorkflow) ||
      features.contains(SeoDomFirstFeature.actionFlow)) {
    runtime.write(
      ';delete document.documentElement.dataset.esenInteractionPending',
    );
  }
  final persistent = '<script $seoDomFirstScriptAttribute$nonceAttribute>'
      '$runtime</script>';
  if (!features.contains(SeoDomFirstFeature.runtimeHandoff) ||
      !features.contains(SeoDomFirstFeature.collection)) {
    return persistent;
  }
  return _collectionHandoffScriptHtml(nonce: nonce) + persistent;
}

String _collectionHandoffScriptHtml({String? nonce}) =>
    '<script $seoDomFirstLoadableRuntimeAttribute="'
    '$seoDomFirstCollectionRuntimeKind" $seoDomFirstRuntimeSha256Attribute="'
    '$seoDomFirstCollectionHandoffRuntimeSha256"${_nonceAttribute(nonce)}>'
    '$seoDomFirstCollectionHandoffRuntime</script>';

String _nonceAttribute(String? nonce) {
  final value = nonce?.trim();
  if (value == null || value.isEmpty) return '';
  return ' nonce="${HtmlRenderer.escapeAttribute(value)}"';
}
