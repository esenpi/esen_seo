import 'package:esen_seo/esen_seo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

Route<void> _route(String name) => MaterialPageRoute<void>(
      builder: (_) => const SizedBox(),
      settings: RouteSettings(name: name),
    );

void main() {
  testWidgets('a static route applies its meta in the same frame',
      (tester) async {
    // No pump/settle between the push and the assertion: an async body
    // must not push the meta of an ordinary route into a later frame.
    enableSeoForTests();
    final observer = SeoRouteObserver(
      routes: [
        SeoRoute(
          path: '/demo',
          meta: (_) => const SeoMeta(title: 'Demo'),
          body: (_) async => [SeoNode(tag: 'h1', text: 'late')],
        ),
      ],
      canonicalBase: 'https://x.dev',
    );

    observer.didPush(_route('/demo'), null);
    expect(EsenSeo.currentHeadHtml, contains('<title>Demo</title>'));
  });

  testWidgets('a slow resolver never overwrites a newer navigation',
      (tester) async {
    // The bug that cannot exist today: navigate to a slow page, then
    // immediately to a fast one — the fast title must win.
    enableSeoForTests();
    final observer = SeoRouteObserver(
      routes: [
        SeoRoute.dynamic(
          path: '/p/:id',
          resolve: (r) async {
            await Future<void>.delayed(
              Duration(milliseconds: r['id'] == 'slow' ? 50 : 5),
            );
            return SeoDocument(meta: SeoMeta(title: 'P ${r['id']}'));
          },
        ),
      ],
    );

    observer.didPush(_route('/p/slow'), null);
    observer.didPush(_route('/p/fast'), null);

    await tester.pump(const Duration(milliseconds: 10)); // fast lands
    expect(EsenSeo.currentHeadHtml, contains('<title>P fast</title>'));

    await tester.pump(const Duration(milliseconds: 60)); // slow lands, dropped
    expect(EsenSeo.currentHeadHtml, contains('<title>P fast</title>'));
    expect(EsenSeo.currentHeadHtml, isNot(contains('P slow')));
  });

  testWidgets('resolveDynamicRoutes: false leaves dynamic meta untouched',
      (tester) async {
    enableSeoForTests();
    final observer = SeoRouteObserver(
      routes: [
        SeoRoute(path: '/', meta: (_) => const SeoMeta(title: 'Home')),
        SeoRoute.dynamic(
          path: '/p/:id',
          resolve: (r) async => SeoDocument(meta: SeoMeta(title: r['id'])),
        ),
      ],
      resolveDynamicRoutes: false,
    );

    observer.didPush(_route('/'), null);
    observer.didPush(_route('/p/x'), null);
    await tester.pump(const Duration(milliseconds: 20));
    // The dynamic route was skipped; the last applied meta stays Home.
    expect(EsenSeo.currentHeadHtml, contains('<title>Home</title>'));
  });

  testWidgets('a throwing resolver reports and keeps the app alive',
      (tester) async {
    enableSeoForTests();
    Object? reported;
    final observer = SeoRouteObserver(
      routes: [
        SeoRoute.dynamic(
          path: '/boom',
          resolve: (_) async => throw StateError('db down'),
        ),
      ],
      onResolveError: (path, error, _) => reported = error,
    );

    observer.didPush(_route('/boom'), null);
    await tester.pump(const Duration(milliseconds: 10));
    expect(reported, isA<StateError>());
  });
}
