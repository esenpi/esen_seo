# DOM-first Stepper Effects Benchmark Results

Measured: 2026-08-20T22:07:08.495Z

Dart 3.6.2; Flutter 3.27.4; Browser: 151.0.7922.140; Node: v23.4.0; Next.js 16.2.11; React 19.2.0.
7 cold runs per cell; 390x844 @2x; 1.6 Mbit/s down, 750 Kbit/s up, 150 ms RTT; 4x slowdown.

| Metric (median / p75) | Hand DOM | Next.js | DOM-first | Flutter |
| --- | ---: | ---: | ---: | ---: |
| Critical JS gzip (KiB) | 0.8 / 0.8 | 144.3 / 144.3 | 19.7 / 19.7 | 445.2 / 445.2 |
| Total transfer (KiB) | 1.9 / 1.9 | 145.3 / 145.3 | 21.1 / 21.1 | 450.1 / 450.1 |
| LCP (ms) | 388 / 396 | 396 / 400 | 228 / 236 | 248 / 252 |
| TBT (ms) | 0 / 0 | 22 / 24 | 0 / 0 | 549 / 557 |
| First interaction (ms) | 461.6 / 471.6 | 1754.2 / 1762.7 | 381.1 / 389.1 | 13061.6 / 13191.6 |
| Scripted INP proxy (ms) | 33.2 / 33.6 | 50.2 / 50.9 | 32.5 / 32.6 | 151.5 / 156.4 |
| CLS | 0.0487 / 0.0487 | 0.0932 / 0.0932 | 0.0487 / 0.0487 | 0 / 0 |

## Acceptance

- PASS: criticalJsGzipKiB absolute ceiling (19.7/19.7 <= 25/25)
- PASS: criticalJsGzipKiB relative bound (DOM 19.7, Next 144.3, Flutter 445.2)
- PASS: totalTransferKiB absolute ceiling (21.1/21.1 <= 100/100)
- PASS: totalTransferKiB relative bound (DOM 21.1, Next 145.3, Flutter 450.1)
- PASS: lcpMs absolute ceiling (228/236 <= 2000/2500)
- PASS: tbtMs absolute ceiling (0/0 <= 150/200)
- PASS: tbtMs relative bound (DOM 0, Next 22, Flutter 549)
- PASS: firstInteractionMs absolute ceiling (381.1/389.1 <= 2200/2700)
- PASS: firstInteractionMs relative bound (DOM 381.1, Next 1754.2, Flutter 13061.6)
- PASS: scriptedInpMs absolute ceiling (32.5/32.6 <= 200/200)
- PASS: scriptedInpMs relative bound (DOM 32.5, Next 50.2, Flutter 151.5)
- PASS: cls absolute ceiling (0.0487/0.0487 <= 0.05/0.05)

**Decision: keep the compiled candidate. Every applicable gate passed.**

The transfer figures are gzip-compressed response bodies; critical JavaScript
adds gzip-compressed inline scripts to external script responses. Every DOM
interaction requires both the selected panel and its focus effect before two
animation frames complete. The scripted proxy is a lab gate, not field INP;
the separate field target remains 200 ms at p75 after release.
