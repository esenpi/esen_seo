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
  /// Enhance validated `SeoTabs` markup through the shared tabs transition.
  tabs,

  /// Enhance validated SeoStepper markup through its shared transition.
  stepper,

  /// Enhance a validated complete collection with search and pagination.
  collection,

  /// Apply and persist a validated light/dark presentation preference.
  themeToggle,

  /// Apply package-owned CSS motion to components carrying fixed markers.
  ///
  /// This feature adds no JavaScript and leaves reduced-motion users in the
  /// final static state.
  motion,
}
