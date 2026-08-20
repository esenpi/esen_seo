# DOM-first Collection History Benchmark Results

Measured: 2026-08-20T20:45:27.297Z

Dart 3.6.2; Flutter 3.27.4; Browser: 151.0.7922.140; Node: v23.4.0; Next.js 16.2.11; React 19.2.0.
7 cold runs per cell; 390x844 @2x; 1.6 Mbit/s down, 750 Kbit/s up, 150 ms RTT; 4x slowdown.

| Metric (median / p75) | Hand DOM | Next.js | DOM-first | Flutter |
| --- | ---: | ---: | ---: | ---: |
| Critical JS gzip (KiB) | 1.6 / 1.6 | 145.9 / 145.9 | 24.8 / 24.8 | 498.4 / 498.4 |
| Total transfer (KiB) | 3.1 / 3.1 | 147.6 / 147.6 | 27.4 / 27.4 | 505 / 505 |
| LCP (ms) | 408 / 416 | 392 / 396 | 240 / 240 | 248 / 256 |
| TBT (ms) | 0 / 0 | 19 / 23 | 0 / 0 | 642 / 654 |
| First interaction (ms) | 479.8 / 487.7 | 1805.1 / 1809 | 436.9 / 440.4 | n/a |
| Scripted INP proxy (ms) | 47.3 / 49.2 | 49.2 / 51.5 | 44.8 / 47.7 | n/a |
| CLS | 0.5567 / 0.5567 | 0.0008 / 0.0008 | 0.0022 / 0.0022 | 0 / 0 |

## Acceptance

- PASS: criticalJsGzipKiB absolute ceiling (24.8/24.8 <= 25/25)
- PASS: criticalJsGzipKiB relative bound (DOM 24.8, Next 145.9, Flutter 498.4)
- PASS: totalTransferKiB absolute ceiling (27.4/27.4 <= 100/100)
- PASS: totalTransferKiB relative bound (DOM 27.4, Next 147.6, Flutter 505)
- PASS: lcpMs absolute ceiling (240/240 <= 2000/2500)
- PASS: tbtMs absolute ceiling (0/0 <= 150/200)
- PASS: tbtMs relative bound (DOM 0, Next 19, Flutter 642)
- PASS: firstInteractionMs absolute ceiling (436.9/440.4 <= 2200/2700)
- PASS: scriptedInpMs absolute ceiling (44.8/47.7 <= 200/200)
- PASS: cls absolute ceiling (0.0022/0.0022 <= 0.05/0.05)

**Decision: keep the compiled candidate. Every applicable gate passed.**

The transfer figures are gzip-compressed response bodies; critical JavaScript
adds gzip-compressed inline scripts to external script responses. The scripted
INP proxy measures dispatch through the resulting paint over search, category,
sort, page, Back and Forward operations. Every operation also asserts canonical
namespaced URL state and preservation of unrelated URL data. It is a reproducible
lab gate, not field INP; the separate field target remains 200 ms at p75 after
release.
