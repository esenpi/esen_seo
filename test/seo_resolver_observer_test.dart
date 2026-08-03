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

  testWidgets('siteBase prefix and encoded Unicode map into route space',
      (tester) async {
    enableSeoForTests();
    final observer = SeoRouteObserver(
      routes: [
        SeoRoute(
          path: '/über',
          meta: (_) => const SeoMeta(title: 'Über uns'),
        ),
      ],
      canonicalBase: 'https://x.dev/repo',
    );

    observer.didPush(_route('/repo/%C3%BCber'), null);
    expect(EsenSeo.currentHeadHtml, contains('<title>Über uns</title>'));
    expect(
      EsenSeo.currentHeadHtml,
      contains('href="https://x.dev/repo/%C3%BCber"'),
    );
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

  testWidgets('resolveDynamicRoutes: false never calls the resolver at all',
      (tester) async {
    // Not just "the title stays": the read must not START. Checking the
    // title alone passed even while the database was being hit.
    enableSeoForTests();
    var calls = 0;
    final observer = SeoRouteObserver(
      routes: [
        SeoRoute(path: '/', meta: (_) => const SeoMeta(title: 'Home')),
        SeoRoute.dynamic(
          path: '/p/:id',
          resolve: (r) async {
            calls++;
            return SeoDocument(meta: SeoMeta(title: r['id']));
          },
        ),
      ],
      resolveDynamicRoutes: false,
    );

    observer.didPush(_route('/'), null);
    observer.didPush(_route('/p/x'), null);
    await tester.pump(const Duration(milliseconds: 20));
    expect(calls, 0, reason: 'the resolver must not be invoked');
    expect(EsenSeo.currentHeadHtml, contains('<title>Home</title>'));
  });

  testWidgets('a synchronous dynamic resolver is also blocked by the switch',
      (tester) async {
    // A dynamic resolver may answer without awaiting. Deciding on the
    // returned type instead of the route kind let its meta through.
    enableSeoForTests();
    final observer = SeoRouteObserver(
      routes: [
        SeoRoute(path: '/', meta: (_) => const SeoMeta(title: 'Home')),
        SeoRoute.dynamic(
          path: '/p/:id',
          resolve: (r) => SeoDocument(meta: SeoMeta(title: 'Sync ${r['id']}')),
        ),
      ],
      resolveDynamicRoutes: false,
    );

    observer.didPush(_route('/'), null);
    observer.didPush(_route('/p/x'), null);
    await tester.pump(const Duration(milliseconds: 20));
    expect(EsenSeo.currentHeadHtml, isNot(contains('Sync x')));
  });

  testWidgets('navigating to an unknown path still cancels a pending read',
      (tester) async {
    // The token used to advance only on a successful match, so a slow
    // product read would set its title on a page the table never knew.
    enableSeoForTests();
    final observer = SeoRouteObserver(
      routes: [
        SeoRoute.dynamic(
          path: '/p/:id',
          resolve: (r) async {
            await Future<void>.delayed(const Duration(milliseconds: 50));
            return SeoDocument(meta: SeoMeta(title: 'P ${r['id']}'));
          },
        ),
      ],
    );

    observer.didPush(_route('/p/slow'), null);
    observer.didPush(_route('/unbekannt'), null); // matches nothing
    await tester.pump(const Duration(milliseconds: 80));
    expect(EsenSeo.currentHeadHtml, isNot(contains('P slow')));
  });

  testWidgets('a SYNCHRONOUSLY throwing resolver is caught too',
      (tester) async {
    // SeoResolver is a FutureOr, so a resolver may throw before it ever
    // returns a Future. That escaped straight out of the
    // NavigatorObserver, which no app expects from a metadata layer.
    enableSeoForTests();
    Object? reported;
    final observer = SeoRouteObserver(
      routes: [
        SeoRoute.dynamic(
          path: '/boom',
          resolve: (_) => throw StateError('config broken'),
        ),
      ],
      onResolveError: (path, error, _) => reported = error,
    );

    expect(() => observer.didPush(_route('/boom'), null), returnsNormally);
    expect(reported, isA<StateError>());
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
