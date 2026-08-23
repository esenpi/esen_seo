# Shipped Runtime Bundle Benchmark Results

Measured: 2026-08-23T20:21:05.843Z

Dart 3.6.2; Flutter 3.27.4; Browser: 151.0.7922.170; Node: v23.4.0; Next.js 16.2.11; React 19.2.0.
7 cold runs per cell; 390x844 @2x; 1.6 Mbit/s down, 750 Kbit/s up, 150 ms RTT; 4x slowdown.

| Metric (median / p75) | Hand DOM | Next.js | DOM-first | Flutter |
| --- | ---: | ---: | ---: | ---: |
| Critical JS gzip (KiB) | 1.5 / 1.5 | 145 / 145 | 24.3 / 24.3 | 470.5 / 470.5 |
| Total transfer (KiB) | 3.2 / 3.2 | 146.5 / 146.5 | 26.8 / 26.8 | 476.1 / 476.1 |
| LCP (ms) | 392 / 404 | 400 / 404 | 240 / 244 | 240 / 244 |
| TBT (ms) | 0 / 0 | 19 / 23 | 0 / 0 | 598 / 602 |
| First interaction (ms) | 450.8 / 464.1 | 1331.8 / 1339.2 | 415 / 421.9 | 12231.3 / 12232.4 |
| Scripted INP proxy (ms) | 65.9 / 67 | 99.9 / 101.5 | 66.2 / 66.6 | 228.2 / 229.5 |
| CLS | 0.168 / 0.168 | 0.2861 / 0.2861 | 0.004 / 0.004 | 0 / 0 |

## Acceptance

- PASS: criticalJsGzipKiB absolute ceiling (24.3/24.3 <= 25/25)
- PASS: criticalJsGzipKiB relative bound (DOM 24.3, Next 145, Flutter 470.5)
- PASS: totalTransferKiB absolute ceiling (26.8/26.8 <= 100/100)
- PASS: totalTransferKiB relative bound (DOM 26.8, Next 146.5, Flutter 476.1)
- PASS: lcpMs absolute ceiling (240/244 <= 2000/2500)
- PASS: tbtMs absolute ceiling (0/0 <= 150/200)
- PASS: tbtMs relative bound (DOM 0, Next 19, Flutter 598)
- PASS: firstInteractionMs absolute ceiling (415/421.9 <= 2200/2700)
- PASS: firstInteractionMs relative bound (DOM 415, Next 1331.8, Flutter 12231.3)
- PASS: scriptedInpMs absolute ceiling (66.2/66.6 <= 200/200)
- PASS: scriptedInpMs relative bound (DOM 66.2, Next 99.9, Flutter 228.2)
- PASS: cls absolute ceiling (0.004/0.004 <= 0.05/0.05)

**Decision: keep the supported bundle candidate. Every applicable gate passed.**

The transfer figures are gzip-compressed response bodies; critical JavaScript
adds gzip-compressed inline scripts to external script responses. The fixed
sequence exercises all three independent state slices, Carousel keyboard
wiring and the Stepper focus effect. The scripted proxy is a lab gate, not
field INP; the separate field target remains 200 ms at p75 after release.
