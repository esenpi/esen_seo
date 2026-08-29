/// Delivery choices for one route in the shared SEO route table.
library;

/// Which web presentation owns a route.
enum SeoRouteDelivery {
  /// The existing Flutter web application owns the human presentation.
  flutter,

  /// The semantic HTML document is the permanent human and crawler page.
  domFirst,
}

/// Package-owned behaviour a DOM-first route explicitly opts into.
///
/// The closed set keeps executable browser capabilities out of route data.
enum SeoDomFirstFeature {
  /// Navigate between compatible registered content routes without a reload.
  ///
  /// The pilot is intentionally compatible only with [themeToggle], [motion]
  /// and the package-owned [tabs] runtime. Other stateful component and every
  /// application runtime keep native page navigation until they define an
  /// explicit reinitialization contract.
  navigation,

  /// Enhance validated `SeoTabs` markup through the shared tabs transition.
  tabs,

  /// Enhance validated SeoCarousel markup through its shared transition.
  carousel,

  /// Enhance validated SeoStepper markup through its shared transition.
  stepper,

  /// Enhance a validated complete collection with search and pagination.
  collection,

  /// Style a validated configurator enhanced by a route-scoped application.
  configurator,

  /// Style a guarded editorial workflow enhanced by a scoped application.
  editorialWorkflow,

  /// Style a guarded approval checklist enhanced by a scoped application.
  approvalChecklist,

  /// Enhance one validated package-owned POST form without owning its state.
  actionForm,

  /// Enhance a validated linear, multi-step package-owned POST form.
  actionFlow,

  /// Apply and persist a validated light/dark presentation preference.
  themeToggle,

  /// Apply package-owned CSS motion to components carrying fixed markers.
  ///
  /// This feature adds no JavaScript and leaves reduced-motion users in the
  /// final static state.
  motion,
}

/// Features whose browser state survives the client-navigation pilot.
const Set<SeoDomFirstFeature> seoDomFirstNavigationCompatibleFeatures = {
  SeoDomFirstFeature.navigation,
  SeoDomFirstFeature.tabs,
  SeoDomFirstFeature.themeToggle,
  SeoDomFirstFeature.motion,
};
