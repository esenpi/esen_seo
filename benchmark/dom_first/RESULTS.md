# DOM-first Tabs Benchmark Results

Measured: 2026-08-13T19:38:55.967Z

Dart 3.6.2; Flutter 3.27.4; Browser: 151.0.7922.137; Node: v24.19.0; Next.js 16.2.11; React 19.2.0.
7 cold runs per cell; 390x844 @2x; 1.6 Mbit/s down, 750 Kbit/s up, 150 ms RTT; 4x slowdown.

| Metric (median / p75) | Hand DOM | Next.js | DOM-first | Flutter |
| --- | ---: | ---: | ---: | ---: |
| Critical JS gzip (KiB) | 0.7 / 0.7 | 144.4 / 144.4 | 18.7 / 18.7 | 427.2 / 427.2 |
| Total transfer (KiB) | 1.7 / 1.7 | 145.2 / 145.2 | 19.9 / 19.9 | 432.4 / 432.4 |
| LCP (ms) | 388 / 400 | 396 / 412 | 248 / 256 | 240 / 248 |
| TBT (ms) | 0 / 0 | 31 / 49 | 0 / 0 | 250 / 345 |
| First interaction (ms) | 466.1 / 497.3 | 1389.5 / 1773.4 | 386.9 / 391.2 | 304.6 / 340.8 |
| Scripted INP proxy (ms) | 31.4 / 32.1 | 49 / 49.2 | 31.8 / 32 | 31.6 / 32.2 |
| CLS | 0.0072 / 0.0072 | 0.0042 / 0.0042 | 0.0072 / 0.0072 | 0.0072 / 0.0072 |

## Acceptance

- PASS: criticalJsGzipKiB absolute ceiling (18.7/18.7 <= 25/25)
- PASS: criticalJsGzipKiB relative bound (DOM 18.7, Next 144.4, Flutter 427.2)
- PASS: totalTransferKiB absolute ceiling (19.9/19.9 <= 100/100)
- PASS: totalTransferKiB relative bound (DOM 19.9, Next 145.2, Flutter 432.4)
- PASS: lcpMs absolute ceiling (248/256 <= 2000/2500)
- PASS: tbtMs absolute ceiling (0/0 <= 150/200)
- PASS: tbtMs relative bound (DOM 0, Next 31, Flutter 250)
- PASS: firstInteractionMs absolute ceiling (386.9/391.2 <= 2200/2700)
- PASS: scriptedInpMs absolute ceiling (31.8/32 <= 200/200)
- PASS: cls absolute ceiling (0.0072/0.0072 <= 0.05/0.05)

**Decision: keep the compiled candidate. Every applicable gate passed.**

The transfer figures are gzip-compressed response bodies; critical JavaScript
adds gzip-compressed inline scripts to external script responses. The scripted
INP proxy measures dispatch through the resulting paint over click and
Arrow/Home/End sequences. It is a reproducible lab gate, not field INP; the
separate field target remains 200 ms at p75 after release.
