# Physical iPhone evidence — 15 November 2026

Sean returned the completed [original JSON report](2026-11-15-iphone-14-plus.json)
from the manual procedure in the [harness checklist](../README.md).
The uploaded bytes are preserved without editing or normalizing device metadata.

- Run: `76bccfbc-6dd7-4241-8269-2f6f5c519170`
- Device: iPhone 14 Plus, operator-entered iOS `26.7.1`
- Mode: Safari browser tab, native IndexedDB, local HTTP origin
- Adapter/core/serialization: `62af23ffa369c2d2cba13c93e39eee4c90c2325d`
- Harness: `fe5feff185ae0c58a38467da25ff7f153bf2047a`, `sourceDirty: false`
- Run started: 15 November 2026, 12:36:24 CET (11:36:24 UTC)
- Report exported: 15 November 2026, 12:43:53 CET (11:43:53 UTC)
- Original JSON SHA-256: `4cff7f4eefb92e013f54cab272e9ac9eb17aab0d4801fa66fbf6d81ef78be648`

All executed checks passed. The report has 123 PASS log entries (including
repeated lifecycle assertions and completion messages), zero FAIL entries, and
no pending lifecycle action. Baseline, reconciliation/retry, schema/fault suite,
reload, background/resume, and close/reopen are complete.

| Lifecycle action | Verification time (CET) | Evidence |
| --- | --- | --- |
| Reload | 12:37:42 | Operator confirmed; new document; saved values, exact revisions, unique ownership, and all 10 receipts verified |
| Background/resume | 12:38:19 | Operator confirmed; hidden for 18.188 seconds; same document; all expected records and receipts verified |
| Safari close/reopen | 12:42:43 | Operator confirmed; new document; all expected records and receipts verified |

The first upload from this run preceded the final reopen verification. The final
upload contains that earlier event history unchanged as its prefix and retains
the same receipt manifest. It adds the missing verification; this is a
continuation of the same run, not a replacement run.

## Interpretation and remaining review

The harness author checked the source pins, flags, chronology, three lifecycle
entries and corresponding read assertions, all 10 success/rejection receipts,
background visibility duration, and the final summary against the raw log.
This is evidence validation by the author, **not independent review**.

The report supports the tested Safari-tab persistence contract on the supplied
physical device. Schema-upgrade abort, unavailable storage, and receipt-write
errors were injected over native IndexedDB, with observed native rollback and
successful recovery. Lost-result recovery deliberately discarded completion; it
did not force an OS kill during a transaction. No application-domain behavior is
involved.

Installed PWA/Home Screen, offline loading, actual quota exhaustion, eviction,
forced OS termination during a write, and long-term retention remain untested.
The exact underlying WebKit build is not established: preserve both the
operator-entered iOS field and raw user agent as reported, without treating the
user agent's `AppleWebKit/605.1.15` token as proof of a precise engine build. No
reproducible failure was reported in this run.

Issue #77 remains open for an independent reviewer to assess the harness,
physical-device provenance, results and stated scope. Do not mark its final
acceptance criterion complete or claim broader platform support on the basis of
this author check alone.
