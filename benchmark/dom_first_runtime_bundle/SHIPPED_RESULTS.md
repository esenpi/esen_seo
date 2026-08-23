# Shipped Runtime Bundle Benchmark Results

Measured: 2026-08-23T19:14:22.515Z

Dart 3.6.2; Flutter 3.27.4; Browser: 151.0.7922.170; Node: v23.4.0; Next.js 16.2.11; React 19.2.0.
7 cold runs per cell; 390x844 @2x; 1.6 Mbit/s down, 750 Kbit/s up, 150 ms RTT; 4x slowdown.

| Metric (median / p75) | Hand DOM | Next.js | DOM-first | Flutter |
| --- | ---: | ---: | ---: | ---: |
| Critical JS gzip (KiB) | 1.5 / 1.5 | 145 / 145 | 23.1 / 23.1 | 469.8 / 469.8 |
| Total transfer (KiB) | 3.2 / 3.2 | 146.5 / 146.5 | 25.2 / 25.2 | 475.2 / 475.2 |
| LCP (ms) | 388 / 400 | 392 / 392 | 236 / 240 | 244 / 248 |
| TBT (ms) | 0 / 0 | 23 / 23 | 0 / 0 | 652 / 696 |
| First interaction (ms) | 432 / 450.7 | 1286 / 1293.5 | 378.8 / 385 | 12202.1 / 12277.1 |
| Scripted INP proxy (ms) | 32.1 / 32.5 | 49.4 / 49.5 | 32.4 / 32.8 | 188.5 / 194.5 |
| CLS | 0.0159 / 0.0159 | 0.0057 / 0.0057 | 0.0194 / 0.0194 | 0 / 0 |

## Acceptance

- PASS: criticalJsGzipKiB absolute ceiling (23.1/23.1 <= 25/25)
- PASS: criticalJsGzipKiB relative bound (DOM 23.1, Next 145, Flutter 469.8)
- PASS: totalTransferKiB absolute ceiling (25.2/25.2 <= 100/100)
- PASS: totalTransferKiB relative bound (DOM 25.2, Next 146.5, Flutter 475.2)
- PASS: lcpMs absolute ceiling (236/240 <= 2000/2500)
- PASS: tbtMs absolute ceiling (0/0 <= 150/200)
- PASS: tbtMs relative bound (DOM 0, Next 23, Flutter 652)
- PASS: firstInteractionMs absolute ceiling (378.8/385 <= 2200/2700)
- PASS: firstInteractionMs relative bound (DOM 378.8, Next 1286, Flutter 12202.1)
- PASS: scriptedInpMs absolute ceiling (32.4/32.8 <= 200/200)
- PASS: scriptedInpMs relative bound (DOM 32.4, Next 49.4, Flutter 188.5)
- PASS: cls absolute ceiling (0.0194/0.0194 <= 0.05/0.05)

**Decision: keep the supported bundle candidate. Every applicable gate passed.**

The transfer figures are gzip-compressed response bodies; critical JavaScript
adds gzip-compressed inline scripts to external script responses. The fixed
sequence exercises all three independent state slices, Carousel keyboard
wiring and the Stepper focus effect. The scripted proxy is a lab gate, not
field INP; the separate field target remains 200 ms at p75 after release.
