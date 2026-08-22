# DOM-first Application Runtime Bundle Benchmark

This directory records the frozen acceptance protocol for combining several
application-owned transitions in one route-scoped JavaScript artifact.

The original candidate contains Tabs, Collection and Stepper Effects. Its first
real compiler build crossed the fixed artifact ceiling, so it was rejected
before browser measurements. `RESULTS.md` records that result and separate
diagnostic builds. The ceiling in `PROTOCOL.md` was not changed after seeing the
output.
