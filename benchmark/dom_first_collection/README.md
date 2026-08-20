# DOM-first collection history benchmark

This matrix compares equivalent searchable, sortable and paginated collections
under a fixed mobile profile: hand-written DOM, Next.js, esen_seo DOM-first and
the existing visible shell followed by Flutter. The frozen limits, scripted
history sequence and run order are recorded in `PROTOCOL.md`.

The three permanent DOM cells execute the URL and History sequence. Flutter is
the loading-cost baseline for transfer, LCP, TBT and CLS; its native collection
keeps local state, so browser-History interaction metrics are not applicable.

The Next.js fixture requires Node.js 20.9 or newer.

```sh
cd benchmark/dom_first_collection
pnpm install
pnpm run build:next
cd fixtures/application
dart pub get
dart run esen_seo:esen_seo_runtime \
  --kind collection \
  --id benchmark-collection \
  --library package:esen_seo_collection_benchmark_app/collection_transition.dart \
  --symbol transitionBenchmarkCollection
dart run esen_seo:esen_seo_runtime \
  --kind collection \
  --id benchmark-collection \
  --library package:esen_seo_collection_benchmark_app/collection_transition.dart \
  --symbol transitionBenchmarkCollection \
  --check
cd ../../../..
dart run benchmark/dom_first_collection/generate_esen.dart \
  benchmark/dom_first_collection/build/esen/index.html
cd benchmark/dom_first_collection/fixtures/flutter
flutter pub get
flutter build web --release
dart run bin/prerender.dart
cd ../..
pnpm run measure -- --write
```

The runner uses seven fresh browser contexts per cell, rotates the declared
order, disables the HTTP cache, applies the fixed network and CPU throttling,
and exits non-zero when an absolute or applicable relative gate fails. It also
fails if any scripted URL, History or visible-result assertion diverges.
