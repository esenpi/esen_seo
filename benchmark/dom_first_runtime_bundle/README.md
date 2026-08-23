# DOM-first Application Runtime Bundle Benchmark

This directory records the frozen acceptance protocol for combining several
application-owned transitions in one route-scoped JavaScript artifact.

The original candidate contains Tabs, Collection and Stepper Effects. Its first
real compiler build crossed the fixed artifact ceiling, so it was rejected
before browser measurements. `RESULTS.md` records that result and separate
diagnostic builds. The ceiling in `PROTOCOL.md` was not changed after seeing the
output. Follow-up pair measurements showed that Collection leaves no safe
budget for a second adapter, so the shipped bundle boundary excludes Collection
instead of exposing a configuration that cannot pass its own artifact gate.

The supported Tabs + Carousel + Stepper Effects candidate has a separate
protocol in `SHIPPED_CANDIDATE_PROTOCOL.md`. Its complete four-cell browser
matrix is recorded in `SHIPPED_RESULTS.md`; every absolute and applicable
relative gate passed. A pre-measurement smoke run also exposed cumulative
layout movement when three controls enhanced at once. The original recorded
matrix reserved stable component areas in shared fixture CSS. The package now
emits runtime-scoped pre-paint geometry for Tabs, Carousel and Stepper itself;
the current fixture deliberately has no component `min-height`, so subsequent
measurements exercise that shipped path rather than a benchmark-only guard.

The Next.js fixture requires Node.js 20.9 or newer. Reproduce the complete
matrix from the repository root:

```sh
export PATH="/opt/homebrew/bin:$PATH"
cd benchmark/dom_first_runtime_bundle/fixtures/application
dart pub get
dart run esen_seo:esen_seo_runtime --bundle runtime_bundle.json
dart run esen_seo:esen_seo_runtime --bundle runtime_bundle.json --check
cd ../../../..
dart run benchmark/dom_first_runtime_bundle/generate_esen.dart \
  benchmark/dom_first_runtime_bundle/build/esen/index.html
cd benchmark/dom_first_runtime_bundle
pnpm install
pnpm run build:next
cd fixtures/flutter
flutter pub get
flutter build web --release --pwa-strategy=none
dart run bin/prerender.dart
cd ../..
pnpm run measure -- --smoke
pnpm run measure -- --write
```

The smoke mode executes one functional rotation and never writes results. The
recorded runner uses seven fresh browser contexts per cell, rotates the frozen
order, disables the HTTP cache, applies the declared network and CPU throttling,
and exits non-zero when an absolute or applicable relative gate fails.
