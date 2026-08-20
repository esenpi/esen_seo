# DOM-first Stepper effects benchmark

This matrix compares the same three-step flow under a fixed mobile profile:
hand-written DOM, Next.js, esen_seo DOM-first and Flutter. Every accepted
action selects a panel and then focuses that panel. The frozen limits and run
order are recorded in `PROTOCOL.md`.

The Next.js fixture requires Node.js 20.9 or newer.

```sh
export PATH="/opt/homebrew/bin:$PATH"
cd benchmark/dom_first_stepper_effects
pnpm install
pnpm run build:next
cd fixtures/application
flutter pub get
dart run esen_seo:esen_seo_runtime \
  --kind stepper-effects \
  --id benchmark-stepper-effects \
  --library package:esen_seo_stepper_effects_benchmark_app/stepper_effect_transition.dart \
  --symbol transitionBenchmarkStepperEffects \
  --interaction-ids benchmark-stepper
dart run esen_seo:esen_seo_runtime \
  --kind stepper-effects \
  --id benchmark-stepper-effects \
  --library package:esen_seo_stepper_effects_benchmark_app/stepper_effect_transition.dart \
  --symbol transitionBenchmarkStepperEffects \
  --interaction-ids benchmark-stepper \
  --check
cd ../../../..
dart run benchmark/dom_first_stepper_effects/generate_esen.dart \
  benchmark/dom_first_stepper_effects/build/esen/index.html
cd benchmark/dom_first_stepper_effects/fixtures/flutter
flutter pub get
flutter build web --release --pwa-strategy=none
dart run bin/prerender.dart
cd ../..
pnpm run measure -- --write
```

The runner uses seven fresh browser contexts per cell, rotates the declared
order, disables the HTTP cache, applies fixed network and CPU throttling, and
exits non-zero when an absolute or applicable relative gate fails.
