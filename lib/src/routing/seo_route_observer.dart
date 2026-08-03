import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../controller/seo_controller.dart';
import 'browser_route_location.dart';
import 'seo_resolution.dart';
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
    this.resolveDynamicRoutes = true,
    this.onResolveError,
  });

  /// The shared SEO route table.
  final List<SeoRoute> routes;

  /// Site base URL for automatic canonical URLs, e.g.
  /// `https://esen.software`.
  final String? canonicalBase;

  /// Whether a [SeoRoute.dynamic] resolver runs in the app at all.
  ///
  /// With `false` the resolver is never *called* for a dynamic route —
  /// no read is started and no metadata is applied, not even by a
  /// resolver that happens to answer synchronously. Static routes are
  /// unaffected either way; their meta is applied in the same frame as
  /// before.
  ///
  /// Reach for it when a resolver only makes sense on the server, and
  /// set the page's meta from the widget that already holds the record.
  /// Note the limit: this is a **runtime** switch. If the resolver's
  /// database client cannot compile for the web at all, the table will
  /// not build for the web either — that needs a conditional import or
  /// a resolver injected separately per platform, not this flag.
  final bool resolveDynamicRoutes;

  /// Called when a dynamic resolver throws. The app keeps running
  /// (`SeoMode.safe`); this is the hook to log the failure.
  final void Function(String path, Object error, StackTrace stack)?
      onResolveError;

  // Guards against out-of-order resolution: a slow /products/a must not
  // overwrite the meta of /products/b the user has already reached.
  int _navigationToken = 0;

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
    // Every navigation invalidates a pending resolution, including one
    // to a path this table does not know: the user has moved on, so a
    // slow read that lands afterwards must not set a title on whatever
    // page they are looking at now.
    final token = ++_navigationToken;

    // Direkter Treffer über den Routennamen (Navigator.pushNamed & Co.).
    final name = route?.settings.name;
    if (name != null && _applyLocation(name, token)) return;

    // Router-Packages (go_router & Co.) lassen den Namen meist leer —
    // nach dem Frame steht die aktualisierte URL im Browser.
    if (!SeoController.enabled) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final location = locationProvider?.call() ?? _browserLocation();
      if (location != null) _applyLocation(location, token);
    });
  }

  bool _applyLocation(String location, int token) {
    final match = matchSeoRoute(routes, _routeLocation(location));
    if (match == null) return false;

    // Ask BEFORE resolving, not after: starting the read and then
    // discarding it would still hit the database, would still apply a
    // synchronous dynamic resolver's meta, and would leave an
    // unobserved Future to throw into the void.
    if (match.route.isDynamic && !resolveDynamicRoutes) return true;

    // A convenience route resolves head-only synchronously, so its meta
    // lands in the same frame, exactly as before the resolver existed.
    //
    // The call itself is guarded too: SeoResolver is a FutureOr, so a
    // resolver may answer — and therefore throw — synchronously, and an
    // exception escaping here would leave the NavigatorObserver, which
    // no app expects from a metadata layer.
    final FutureOr<SeoResolution> resolution;
    try {
      resolution = match.resolve(
        detail: SeoDetail.head,
        canonicalBase: canonicalBase,
      );
    } catch (error, stack) {
      onResolveError?.call(location, error, stack);
      return true;
    }
    if (resolution is SeoResolution) {
      _applyResolution(resolution);
      return true;
    }

    // Only a dynamic route reaches here. The app's own router owns
    // navigation; we just catch up the meta when the read completes.
    () async {
      try {
        final resolved = await resolution;
        // A newer navigation has since happened — drop this stale result.
        if (token != _navigationToken) return;
        _applyResolution(resolved);
      } catch (error, stack) {
        onResolveError?.call(location, error, stack);
      }
    }();
    return true;
  }

  void _applyResolution(SeoResolution resolution) {
    // A redirect is the router's business, not the meta layer's; a
    // document (including a 404 with its noindex) sets the head.
    if (resolution is SeoDocument) {
      SeoController.instance.setMeta(resolution.meta);
    }
  }

  String? _browserLocation() {
    if (!kIsWeb) return null;
    return browserRouteLocation(Uri.base);
  }

  String _routeLocation(String location) {
    var routeLocation = location.trim();
    if (routeLocation.startsWith('#')) {
      routeLocation = routeLocation.substring(1);
    }
    final parsed = Uri.tryParse(routeLocation);
    if (parsed != null && parsed.hasScheme) {
      routeLocation = parsed.path;
    } else {
      final query = routeLocation.indexOf('?');
      final fragment = routeLocation.indexOf('#');
      final end = [
        if (query >= 0) query,
        if (fragment >= 0) fragment,
      ].fold(routeLocation.length, (a, b) => a < b ? a : b);
      routeLocation = routeLocation.substring(0, end);
    }
    final path = normalizeSeoPath(routeLocation);
    final base = canonicalBase == null ? null : Uri.tryParse(canonicalBase!);
    if (base == null) return path;
    final prefix = normalizeSeoPath(base.path);
    if (prefix == '/') return path;
    if (path == prefix) return '/';
    if (path.startsWith('$prefix/')) {
      return normalizeSeoPath(path.substring(prefix.length));
    }
    return path;
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
