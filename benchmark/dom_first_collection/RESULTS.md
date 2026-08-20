# DOM-first Collection History Benchmark Results

Measured: 2026-08-20T20:12:12.207Z

Dart 3.6.2; Flutter 3.27.4; Browser: 151.0.7922.140; Node: v23.4.0; Next.js 16.2.11; React 19.2.0.
7 cold runs per cell; 390x844 @2x; 1.6 Mbit/s down, 750 Kbit/s up, 150 ms RTT; 4x slowdown.

| Metric (median / p75) | Hand DOM | Next.js | DOM-first | Flutter |
| --- | ---: | ---: | ---: | ---: |
| Critical JS gzip (KiB) | 1.6 / 1.6 | 145.9 / 145.9 | 24.6 / 24.6 | 498 / 498 |
| Total transfer (KiB) | 3.1 / 3.1 | 147.6 / 147.6 | 27 / 27 | 504.3 / 504.3 |
| LCP (ms) | 420 / 424 | 400 / 404 | 240 / 244 | 240 / 244 |
| TBT (ms) | 0 / 0 | 19 / 20 | 0 / 0 | 636 / 671 |
| First interaction (ms) | 488.2 / 493.8 | 1815.2 / 1822 | 442.1 / 445.3 | n/a |
| Scripted INP proxy (ms) | 46.1 / 46.8 | 46.7 / 52.8 | 47.7 / 51 | n/a |
| CLS | 0.5567 / 0.5567 | 0.0008 / 0.0008 | 0.2553 / 0.2553 | 0 / 0 |

## Acceptance

- PASS: criticalJsGzipKiB absolute ceiling (24.6/24.6 <= 25/25)
- PASS: criticalJsGzipKiB relative bound (DOM 24.6, Next 145.9, Flutter 498)
- PASS: totalTransferKiB absolute ceiling (27/27 <= 100/100)
- PASS: totalTransferKiB relative bound (DOM 27, Next 147.6, Flutter 504.3)
- PASS: lcpMs absolute ceiling (240/244 <= 2000/2500)
- PASS: tbtMs absolute ceiling (0/0 <= 150/200)
- PASS: tbtMs relative bound (DOM 0, Next 19, Flutter 636)
- PASS: firstInteractionMs absolute ceiling (442.1/445.3 <= 2200/2700)
- PASS: scriptedInpMs absolute ceiling (47.7/51 <= 200/200)
- FAIL: cls absolute ceiling (0.2553/0.2553 <= 0.05/0.05)

**Decision: replace or reduce the candidate before release.**

The transfer figures are gzip-compressed response bodies; critical JavaScript
adds gzip-compressed inline scripts to external script responses. The scripted
INP proxy measures dispatch through the resulting paint over search, category,
sort, page, Back and Forward operations. Every operation also asserts canonical
namespaced URL state and preservation of unrelated URL data. It is a reproducible
lab gate, not field INP; the separate field target remains 200 ms at p75 after
release.
