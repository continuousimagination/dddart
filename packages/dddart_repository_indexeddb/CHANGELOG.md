## Unreleased

- Add adapter-local conditional cancellation: prevent dispatch or return an
  uncertain operation identity/digest without aborting an in-flight transaction.
- Make close a dispatch barrier for calls awaiting database opening; document
  non-draining close and independent timeouts. Add deterministic VM/native
  browser cancellation, late-error, receipt/retry and close regressions.
- Add a repeatable native-Chrome separate-tab isolation harness covering revision
  and unique-value races, delete/recreate ABA, and durable receipt replay after
  both pages are destroyed and reopened. Retain source and browser evidence in CI.

## 0.9.0

- Fail blocked schema opens with a recoverable typed connection error, abort
  abandoned queued upgrades, and release connections on version change.
- Add a native cross-context iframe regression for blocked/abandoned upgrades,
  safe retry, record/metadata preservation, and schema/codec fences.

- Integrate the reviewed IndexedDB CRUD, atomic conditional writes, uniqueness,
  receipts and schema recovery implementations with current typed core APIs.
- Support application-owned concrete identity codecs while preserving existing
  UUID storage and marker-only legacy upgrades.
- Register VM and native Chrome validation, including scoped identity contracts.
- Keep Git-only sibling dependencies resolvable from one revision without overrides.
