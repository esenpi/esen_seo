import 'package:flutter/widgets.dart';

import '../controller/seo_controller.dart';
import 'seo_route.dart';

/// Applies the matching [SeoRoute]'s metadata automatically on every
/// navigation — no `EsenSeo.setMeta()` boilerplate per page.
///
/// ```dart
/// MaterialApp(
///   navigatorObservers: [
///     SeoRouteObserver(routes: seoRoutes, canonicalBase: 'https://esen.software'),
///   ],
///   routes: {...},
/// );
/// ```
///
/// The observer matches on the route name ([RouteSettings.name]), so it
/// works with named routes (`Navigator.pushNamed('/demo')`) and any
/// router that populates route names with URL paths. With
/// [canonicalBase] set, canonical URLs are derived automatically for
/// routes that define none themselves.
class SeoRouteObserver extends NavigatorObserver {
  SeoRouteObserver({required this.routes, this.canonicalBase});

  /// The shared SEO route table.
  final List<SeoRoute> routes;

  /// Site base URL for automatic canonical URLs, e.g.
  /// `https://esen.software`.
  final String? canonicalBase;

  void _apply(Route<dynamic>? route) {
    final name = route?.settings.name;
    if (name == null) return;
    final match = matchSeoRoute(routes, name);
    if (match == null) return;
    SeoController.instance.setMeta(
      match.buildMeta(canonicalBase: canonicalBase),
    );
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
}
