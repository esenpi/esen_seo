# DOM-first Tabs Benchmark Results

Measured: 2026-08-11T15:02:30.733Z

Dart 3.6.2; Flutter 3.27.4; Browser: 151.0.7922.77; Node: v24.14.0; Next.js 16.2.11; React 19.2.0.
7 cold runs per cell; 390x844 @2x; 1.6 Mbit/s down, 750 Kbit/s up, 150 ms RTT; 4x slowdown.

| Metric (median / p75) | Hand DOM | Next.js | DOM-first | Flutter |
| --- | ---: | ---: | ---: | ---: |
| Critical JS gzip (KiB) | 0.7 / 0.7 | 144.4 / 144.4 | 18.7 / 18.7 | 427.2 / 427.2 |
| Total transfer (KiB) | 1.7 / 1.7 | 145.2 / 145.2 | 19.9 / 19.9 | 432.4 / 432.4 |
| LCP (ms) | 384 / 392 | 384 / 396 | 232 / 236 | 252 / 252 |
| TBT (ms) | 0 / 0 | 22 / 27 | 0 / 0 | 229 / 234 |
| First interaction (ms) | 443 / 455.8 | 1744.1 / 1775.2 | 361 / 371.4 | 294.4 / 295.5 |
| Scripted INP proxy (ms) | 32.4 / 32.8 | 49.5 / 50 | 32.4 / 32.6 | 32.3 / 32.8 |
| CLS | 0.0072 / 0.0072 | 0.0042 / 0.0042 | 0.0072 / 0.0072 | 0.0002 / 0.0072 |

## Acceptance

- PASS: criticalJsGzipKiB absolute ceiling (18.7/18.7 <= 25/25)
- PASS: criticalJsGzipKiB relative bound (DOM 18.7, Next 144.4, Flutter 427.2)
- PASS: totalTransferKiB absolute ceiling (19.9/19.9 <= 100/100)
- PASS: totalTransferKiB relative bound (DOM 19.9, Next 145.2, Flutter 432.4)
- PASS: lcpMs absolute ceiling (232/236 <= 2000/2500)
- PASS: tbtMs absolute ceiling (0/0 <= 150/200)
- PASS: tbtMs relative bound (DOM 0, Next 22, Flutter 229)
- PASS: firstInteractionMs absolute ceiling (361/371.4 <= 2200/2700)
- PASS: scriptedInpMs absolute ceiling (32.4/32.6 <= 200/200)
- PASS: cls absolute ceiling (0.0072/0.0072 <= 0.05/0.05)

**Decision: keep the compiled candidate. Every applicable gate passed.**

The transfer figures are gzip-compressed response bodies; critical JavaScript
adds gzip-compressed inline scripts to external script responses. The scripted
INP proxy measures dispatch through the resulting paint over click and
Arrow/Home/End sequences. It is a reproducible lab gate, not field INP; the
separate field target remains 200 ms at p75 after release.
