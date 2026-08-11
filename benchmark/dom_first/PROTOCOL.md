# DOM-first Tabs Benchmark Protocol

This protocol was frozen before the first candidate build and measurement.
Thresholds must not be fitted to observed results.

## Pinned toolchains

- Dart SDK 3.6.2
- Flutter 3.27.4
- Next.js 16.2.11 with React 19.2.0
- Playwright 1.62.0
- Exact Chromium and Node versions recorded with each result

## Cells

Every cell carries equivalent content, CSS, fonts and tab behaviour:

1. hand-written DOM as the practical floor;
2. statically rendered Next.js as the competitive reference;
3. esen_seo DOM-first with the application-authored compiled tabs transition;
4. the existing visible shell followed by a Flutter release build.

## Profile

- Cold HTTP cache and a fresh browser context for every run
- Mobile viewport 390 x 844, device scale factor 2
- 1.6 Mbit/s down, 750 Kbit/s up and 150 ms round-trip latency
- 4x CPU slowdown through the Chrome DevTools Protocol
- Seven runs per cell
- Median decides acceptance; p75 is recorded
- Fixed rotating order: ABCD, BCDA, CDAB, DABC, ABCD, BCDA, CDAB

## Absolute ceilings

| Metric | Median | p75 |
| --- | ---: | ---: |
| Critical-path JavaScript gzip | 25 KiB | 25 KiB |
| Total cold-cache transfer | 100 KiB | 100 KiB |
| Largest Contentful Paint | 2,000 ms | 2,500 ms |
| Total Blocking Time | 150 ms | 200 ms |
| First successful scripted interaction | 2,200 ms | 2,700 ms |
| Scripted interaction-to-paint proxy | 200 ms | 200 ms |
| Cumulative Layout Shift | 0.05 | 0.05 |

Field INP has a post-release p75 target of 200 ms and is not part of this lab
matrix. CLS has no relative bound.

## Relative gate

For every other metric where Next.js beats the Flutter baseline, DOM-first
must be numerically closer to Next.js than to Flutter. If Flutter already
matches or beats Next.js, the absolute ceiling alone decides. Both applicable
parts must pass for the compiled candidate to remain.
