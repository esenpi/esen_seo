import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../controller/seo_controller.dart';
import 'seo_route.dart';

/// Applies the matching [SeoRoute]'s metadata automatically on every
/// navigation — no `EsenSeo.setMeta()` boilerplate per page.
///
/// Works with the classic Navigator **and** with router packages like
/// go_router, beamer or auto_route:
///
/// ```dart
/// // Classic Navigator / named routes:
/// MaterialApp(
///   navigatorObservers: [
///     SeoRouteObserver(routes: seoRoutes, canonicalBase: 'https://esen.software'),
///   ],
///   routes: {...},
/// );
///
/// // go_router:
/// GoRouter(
///   observers: [
///     SeoRouteObserver(routes: seoRoutes, canonicalBase: 'https://esen.software'),
///   ],
///   routes: [...],
/// );
/// ```
///
/// Matching strategy: when a route carries a URL-like name
/// ([RouteSettings.name], as with `Navigator.pushNamed`), it is matched
/// directly. Router packages usually leave the name empty — then the
/// observer reads the **browser URL** after the frame (when the router
/// has updated it) and matches that instead. Both path URLs (`/demo`)
/// and hash URLs (`/#/demo`) are understood.
///
/// Note for go_router `ShellRoute`s: shells use their own navigators,
/// so pass the observer to the shell's `observers` as well.
class SeoRouteObserver extends NavigatorObserver {
  SeoRouteObserver({
    required this.routes,
    this.canonicalBase,
    this.locationProvider,
  });

  /// The shared SEO route table.
  final List<SeoRoute> routes;

  /// Site base URL for automatic canonical URLs, e.g.
  /// `https://esen.software`.
  final String? canonicalBase;

  /// Overrides where the current location is read from when a route
  /// has no URL-like name. Defaults to the browser URL ([Uri.base]).
  /// Useful in tests or for custom router setups:
  ///
  /// ```dart
  /// SeoRouteObserver(
  ///   routes: seoRoutes,
  ///   locationProvider: () =>
  ///       router.routerDelegate.currentConfiguration.uri.path,
  /// );
  /// ```
  final String Function()? locationProvider;

  void _apply(Route<dynamic>? route) {
    // Direkter Treffer über den Routennamen (Navigator.pushNamed & Co.).
    final name = route?.settings.name;
    if (name != null && _applyLocation(name)) return;

    // Router-Packages (go_router & Co.) lassen den Namen meist leer —
    // nach dem Frame steht die aktualisierte URL im Browser.
    if (!SeoController.enabled) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final location = locationProvider?.call() ?? _browserLocation();
      if (location != null) _applyLocation(location);
    });
  }

  bool _applyLocation(String location) {
    final match = matchSeoRoute(routes, location);
    if (match == null) return false;
    SeoController.instance.setMeta(
      match.buildMeta(canonicalBase: canonicalBase),
    );
    return true;
  }

  String? _browserLocation() {
    if (!kIsWeb) return null;
    final base = Uri.base;
    // Path-URL-Strategie (empfohlen, EsenSeo.init(cleanUrls: true)):
    if (base.path.isNotEmpty && base.path != '/') return base.path;
    // Hash-Strategie: /#/demo → Fragment enthält den Pfad.
    if (base.fragment.isNotEmpty) return base.fragment;
    return base.path.isEmpty ? '/' : base.path;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _apply(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _apply(previousRoute);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _apply(newRoute);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _apply(previousRoute);
}
