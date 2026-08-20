# DOM-first Stepper Effects Benchmark Results

Measured: 2026-08-20T23:37:21.827Z

Dart 3.6.2; Flutter 3.27.4; Browser: 151.0.7922.170; Node: v23.4.0; Next.js 16.2.11; React 19.2.0.
7 cold runs per cell; 390x844 @2x; 1.6 Mbit/s down, 750 Kbit/s up, 150 ms RTT; 4x slowdown.

| Metric (median / p75) | Hand DOM | Next.js | DOM-first | Flutter |
| --- | ---: | ---: | ---: | ---: |
| Critical JS gzip (KiB) | 0.8 / 0.8 | 144.3 / 144.3 | 20.1 / 20.1 | 445.3 / 445.3 |
| Total transfer (KiB) | 1.9 / 1.9 | 145.3 / 145.3 | 21.5 / 21.5 | 450.2 / 450.2 |
| LCP (ms) | 380 / 388 | 384 / 396 | 228 / 228 | 244 / 248 |
| TBT (ms) | 0 / 0 | 23 / 24 | 0 / 0 | 556 / 568 |
| First interaction (ms) | 442 / 454.4 | 1742 / 1743.9 | 372.1 / 381.7 | 12019.8 / 12031.3 |
| Scripted INP proxy (ms) | 32.5 / 32.9 | 49.5 / 50.3 | 32.3 / 32.6 | 151.9 / 157.8 |
| CLS | 0.0487 / 0.0487 | 0.0932 / 0.0932 | 0.0487 / 0.0487 | 0 / 0 |

## Acceptance

- PASS: criticalJsGzipKiB absolute ceiling (20.1/20.1 <= 25/25)
- PASS: criticalJsGzipKiB relative bound (DOM 20.1, Next 144.3, Flutter 445.3)
- PASS: totalTransferKiB absolute ceiling (21.5/21.5 <= 100/100)
- PASS: totalTransferKiB relative bound (DOM 21.5, Next 145.3, Flutter 450.2)
- PASS: lcpMs absolute ceiling (228/228 <= 2000/2500)
- PASS: tbtMs absolute ceiling (0/0 <= 150/200)
- PASS: tbtMs relative bound (DOM 0, Next 23, Flutter 556)
- PASS: firstInteractionMs absolute ceiling (372.1/381.7 <= 2200/2700)
- PASS: firstInteractionMs relative bound (DOM 372.1, Next 1742, Flutter 12019.8)
- PASS: scriptedInpMs absolute ceiling (32.3/32.6 <= 200/200)
- PASS: scriptedInpMs relative bound (DOM 32.3, Next 49.5, Flutter 151.9)
- PASS: cls absolute ceiling (0.0487/0.0487 <= 0.05/0.05)

**Decision: keep the compiled candidate. Every applicable gate passed.**

The transfer figures are gzip-compressed response bodies; critical JavaScript
adds gzip-compressed inline scripts to external script responses. Every DOM
interaction requires both the selected panel and its focus effect before two
animation frames complete. The scripted proxy is a lab gate, not field INP;
the separate field target remains 200 ms at p75 after release.
