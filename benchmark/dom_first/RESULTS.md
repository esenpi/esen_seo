# DOM-first Tabs Benchmark Results

Measured: 2026-08-10T11:37:56.004Z

Dart 3.6.2; Flutter 3.27.4; Browser: 151.0.7922.77; Node: v24.14.0; Next.js 16.2.11; React 19.2.0.
7 cold runs per cell; 390x844 @2x; 1.6 Mbit/s down, 750 Kbit/s up, 150 ms RTT; 4x slowdown.

| Metric (median / p75) | Hand DOM | Next.js | DOM-first | Flutter |
| --- | ---: | ---: | ---: | ---: |
| Critical JS gzip (KiB) | 0.7 / 0.7 | 144.4 / 144.4 | 17.7 / 17.7 | 427.1 / 427.1 |
| Total transfer (KiB) | 1.7 / 1.7 | 145.2 / 145.2 | 18.7 / 18.7 | 432.3 / 432.3 |
| LCP (ms) | 388 / 392 | 392 / 396 | 232 / 236 | 244 / 248 |
| TBT (ms) | 0 / 0 | 20 / 21 | 0 / 0 | 217 / 219 |
| First interaction (ms) | 454.1 / 458.7 | 1752.3 / 1784 | 351.5 / 358.2 | 285.9 / 287.2 |
| Scripted INP proxy (ms) | 32.8 / 33.3 | 50.1 / 50.7 | 32.8 / 33 | 33.8 / 34.3 |
| CLS | 0.0072 / 0.0072 | 0.0042 / 0.0042 | 0.0072 / 0.0072 | 0.0002 / 0.0002 |

## Acceptance

- PASS: criticalJsGzipKiB absolute ceiling (17.7/17.7 <= 25/25)
- PASS: criticalJsGzipKiB relative bound (DOM 17.7, Next 144.4, Flutter 427.1)
- PASS: totalTransferKiB absolute ceiling (18.7/18.7 <= 100/100)
- PASS: totalTransferKiB relative bound (DOM 18.7, Next 145.2, Flutter 432.3)
- PASS: lcpMs absolute ceiling (232/236 <= 2000/2500)
- PASS: tbtMs absolute ceiling (0/0 <= 150/200)
- PASS: tbtMs relative bound (DOM 0, Next 20, Flutter 217)
- PASS: firstInteractionMs absolute ceiling (351.5/358.2 <= 2200/2700)
- PASS: scriptedInpMs absolute ceiling (32.8/33 <= 200/200)
- PASS: cls absolute ceiling (0.0072/0.0072 <= 0.05/0.05)

**Decision: keep the compiled candidate. Every applicable gate passed.**

The transfer figures are gzip-compressed response bodies; critical JavaScript
adds gzip-compressed inline scripts to external script responses. The scripted
INP proxy measures dispatch through the resulting paint over click and
Arrow/Home/End sequences. It is a reproducible lab gate, not field INP; the
separate field target remains 200 ms at p75 after release.
