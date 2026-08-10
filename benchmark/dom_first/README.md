# DOM-first tabs benchmark

This matrix compares equivalent tab pages under a fixed mobile profile:
hand-written DOM, Next.js, esen_seo DOM-first and the existing visible shell
followed by Flutter. The frozen limits and run order are recorded before the
first measurement in `PROTOCOL.md`.

The Next.js fixture requires Node.js 20.9 or newer.

```sh
cd benchmark/dom_first
pnpm install
pnpm run build:next
cd ../..
dart run benchmark/dom_first/generate_esen.dart \
  benchmark/dom_first/build/esen/index.html
cd benchmark/dom_first/fixtures/flutter
flutter build web --release
dart run bin/prerender.dart
cd ../..
pnpm run measure -- --write
```

The runner uses seven fresh browser contexts per cell, rotates the declared
order, disables the HTTP cache, applies the fixed network and CPU throttling,
and exits non-zero when an absolute or applicable relative gate fails.
