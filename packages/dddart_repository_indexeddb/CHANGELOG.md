## Unreleased

- Add a repeatable native-Chrome separate-tab isolation harness covering revision
  and unique-value races, delete/recreate ABA, and durable receipt replay after
  both pages are destroyed and reopened. Retain source and browser evidence in CI.

## 0.9.0

- Integrate the reviewed IndexedDB CRUD, atomic conditional writes, uniqueness,
  receipts and schema recovery implementations with current typed core APIs.
- Support application-owned concrete identity codecs while preserving existing
  UUID storage and marker-only legacy upgrades.
- Register VM and native Chrome validation, including scoped identity contracts.
- Keep Git-only sibling dependencies resolvable from one revision without overrides.
