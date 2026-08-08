import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../controller/seo_controller.dart';
import 'browser_route_location.dart';
import 'seo_resolution.dart';
import 'seo_route.dart';

/// Applies the matching [SeoRoute]'s metadata automatically on every
/// navigation — no `EsenSeo.setMeta()` boilerplate per page — and
/// refreshes the semantic body mirror once the route transition has
/// settled. The second half is load-bearing: a page built purely from
/// smart defaults has no `.seo()` markers and therefore no other
/// navigation hook — without this observer its mirror keeps serving
/// the previous page after a `Navigator.push`.
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

  /// Refreshes the body mirror once [route]'s transition has settled.
  ///
  /// The meta half of navigation is [_apply]; this is the body half.
  /// SeoWidget carries its own route-animation listener, but an app
  /// running purely on smart defaults has no markers and therefore no
  /// listener — after a push its mirror kept serving the previous
  /// page. The observer is the route-level hook such an app already
  /// registers, so it triggers the refresh for everyone.
  ///
  /// One frame late on purpose: the Navigator applies the visibility
  /// flip to the outgoing route in the Overlay rebuild AFTER the
  /// animation completes — a refresh in the settling frame still sees
  /// both routes onstage.
  void _refreshMirrorAfterTransition(Route<dynamic>? route) {
    if (!SeoController.enabled) return;
    // Refresh right away — the best-effort state during the transition
    // — AND once the transition settles. The status at the did* moment
    // says nothing about being settled: at didPush the animation still
    // reads `dismissed` because it has not STARTED yet, and treating
    // that as "already done" refreshed exactly once, mid-transition
    // with both routes onstage, and then never again — the stale
    // mirror this hook exists to prevent.
    SeoController.instance.refreshAfterNavigation();
    // Only TransitionRoute carries an animation — a bare Route (custom
    // navigation without transitions) is fully covered by the call
    // above.
    final animation =
        route is TransitionRoute<dynamic> ? route.animation : null;
    if (animation == null) return;
    // NOT self-removing on the first settle. ModalRoute.animation is a
    // proxy, and the Navigator swaps its parent to an always-complete
    // animation during the offstage warm-up of a fresh route — which
    // fires a spurious `completed` in the very first frame. A listener
    // that removes itself on that consumed the one event it existed
    // for and went deaf before the real transition ended. Re-arming
    // the refresh window is idempotent, so every settle notification —
    // spurious or real — simply extends it; the listener dies with the
    // route's animation.
    animation.addStatusListener((status) {
      if (status == AnimationStatus.completed ||
          status == AnimationStatus.dismissed) {
        SeoController.instance.refreshAfterNavigation();
      }
    });
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _refreshMirrorAfterTransition(route);
    _apply(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    // The POPPED route is the one animating (out) — its dismissal is
    // the moment the previous page is alone on stage again.
    _refreshMirrorAfterTransition(route);
    _apply(previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _refreshMirrorAfterTransition(newRoute);
    _apply(newRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _refreshMirrorAfterTransition(previousRoute);
    _apply(previousRoute);
  }
}
