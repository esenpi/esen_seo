import 'package:esen_seo/esen_seo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers.dart';

List<SeoRoute> _seoRoutes() => [
      SeoRoute(
        path: '/',
        meta: (_) => const SeoMeta(title: 'Home'),
      ),
      SeoRoute(
        path: '/demo',
        meta: (_) => const SeoMeta(title: 'Demo'),
      ),
      SeoRoute(
        path: '/blog/:slug',
        meta: (params) => SeoMeta(title: 'Blog — ${params['slug']}'),
      ),
    ];

void main() {
  testWidgets('SeoRouteObserver follows go_router navigation', (tester) async {
    enableSeoForTests();

    // In Widget-Tests gibt es keine Browser-URL — der locationProvider
    // liest die Location direkt aus dem Router. Im echten Web-Betrieb
    // übernimmt das automatisch Uri.base.
    late final GoRouter router;
    router = GoRouter(
      observers: [
        SeoRouteObserver(
          routes: _seoRoutes(),
          canonicalBase: 'https://x.dev',
          locationProvider: () =>
              router.routerDelegate.currentConfiguration.uri.path,
        ),
      ],
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(body: Text('home')),
        ),
        GoRoute(
          path: '/demo',
          builder: (_, __) => const Scaffold(body: Text('demo')),
        ),
        GoRoute(
          path: '/blog/:slug',
          builder: (_, __) => const Scaffold(body: Text('blog')),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(EsenSeo.currentHeadHtml, contains('<title>Home</title>'));

    router.go('/demo');
    await tester.pumpAndSettle();
    expect(EsenSeo.currentHeadHtml, contains('<title>Demo</title>'));
    expect(
      EsenSeo.currentHeadHtml,
      contains('<link rel="canonical" href="https://x.dev/demo"/>'),
    );

    router.go('/blog/hallo');
    await tester.pumpAndSettle();
    expect(EsenSeo.currentHeadHtml, contains('<title>Blog — hallo</title>'));

    router.go('/');
    await tester.pumpAndSettle();
    expect(EsenSeo.currentHeadHtml, contains('<title>Home</title>'));
  });

  testWidgets('named-route matching still works unchanged', (tester) async {
    enableSeoForTests();
    await tester.pumpWidget(MaterialApp(
      navigatorObservers: [
        SeoRouteObserver(routes: _seoRoutes(), canonicalBase: 'https://x.dev'),
      ],
      initialRoute: '/',
      routes: {
        '/': (_) => const Scaffold(body: Text('home')),
        '/demo': (_) => const Scaffold(body: Text('demo')),
      },
    ));
    expect(EsenSeo.currentHeadHtml, contains('<title>Home</title>'));

    Navigator.pushNamed(tester.element(find.text('home')), '/demo');
    await tester.pumpAndSettle();
    expect(EsenSeo.currentHeadHtml, contains('<title>Demo</title>'));
  });
}
