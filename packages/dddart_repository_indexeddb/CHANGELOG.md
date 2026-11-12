## Unreleased

- Add adapter-local conditional cancellation: prevent dispatch or return an
  uncertain operation identity/digest without aborting an in-flight transaction.
- Make close a dispatch barrier for calls awaiting database opening; document
  non-draining close and independent timeouts. Add deterministic VM/native
  browser cancellation, late-error, receipt/retry and close regressions.

## 0.9.0

- Integrate the reviewed IndexedDB CRUD, atomic conditional writes, uniqueness,
  receipts and schema recovery implementations with current typed core APIs.
- Support application-owned concrete identity codecs while preserving existing
  UUID storage and marker-only legacy upgrades.
- Register VM and native Chrome validation, including scoped identity contracts.
- Keep Git-only sibling dependencies resolvable from one revision without overrides.
