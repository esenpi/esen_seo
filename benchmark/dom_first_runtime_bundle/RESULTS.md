# DOM-first Application Runtime Bundle Result

Measured on 2026-08-22 with the toolchains pinned in `PROTOCOL.md`.

## Acceptance result

The frozen Tabs + Collection + Stepper Effects candidate was rejected by the
artifact verifier before delivery:

| Metric | Result | Ceiling | Outcome |
| --- | ---: | ---: | --- |
| Raw JavaScript | 97,874 bytes | 524,288 bytes | pass |
| Level-9 gzip JavaScript | 29,831 bytes | 25,600 bytes | fail |

The gzip result exceeds the predeclared ceiling by 4,231 bytes. No four-cell
browser run was performed for this candidate because it cannot cross the
package's existing delivery boundary. The threshold was not raised.

## Diagnostic builds

These builds isolate the contribution of the adapter families. They are not a
replacement acceptance matrix and do not change the failed result above.

| Members | Raw | Level-9 gzip | Artifact gate |
| --- | ---: | ---: | --- |
| Tabs + Stepper Effects | 72,438 bytes | 22,192 bytes | pass |
| Tabs + Carousel + Stepper Effects | 79,148 bytes | 23,777 bytes | pass |

The bundle mechanism remains usable only when the complete application output
fits the unchanged limits. The public example uses the passing three-member
combination; larger combinations continue to fail closed instead of weakening
the route budget.
