# IndexedDB integration work record — issue #78

## Scope and source

Prepared base: `78ed81181b547140197e90f5169de193fc17d094`.
The prepared implementation branch and parent integration target were preserved.
The reviewed browser contribution was imported from
`b2f1150d2500dcca7dcbd7fc300b05f1d82991a7`, not merged wholesale over current core.
Current structural Value equality, typed identities and repository APIs remain
intact. Worky owns candidate commits, PR publication and independent review;
human final merge authority remains unchanged.

## Reconciliation

- Core exports `ConditionalRepository<T, I>`, `ConditionalCommit<T, I>`,
  `ConditionalMutation<T, I>`, `VersionedAggregate<T, I>` and `CommitResult<I>`.
  Aggregate identities remain concrete throughout reads, mutation IDs and receipt
  revision maps. Operation IDs remain UUIDs, independently of aggregate identity.
- The adapter implements current `Repository<T, I>` and the optional conditional
  capability. Consumers supply snapshot encoding/decoding and registered canonical
  identity codecs. No browser dependency or application normalization policy was
  added to core.
- Existing UUID envelopes, physical keys, unique owners, receipts and digests keep
  their reviewed format. The version-1 marker-only upgrade still scans/validates
  records, ownership and receipt counts inside its atomic upgrade transaction.
- Other identity kinds encode their explicit registry discriminator and canonical
  key in a disjoint namespaced tuple, avoiding aliases with UUID and internal
  schema/receipt/unique keys. Scoped IDs retain case, scope and Unicode. Malformed
  UTF-16 canonical keys fail before opening storage; missing codecs fail at
  construction. Decoded keys and snapshots are checked for identity agreement.
- Existing transaction completion, explicit abort, stale revision, uniqueness,
  receipt idempotency/capacity and uncertain-outcome handling were retained.
  The pinned idb_shim native error guard was retained with its regression test.
- The root workspace and validation inventory include the adapter and its minimal
  core/serialization closure. Package test configuration includes VM and Chrome,
  so native-browser tests are part of the shared package gate, not an optional
  undocumented command.

## Evidence — 12 November 2026

Environment: Linux ARM64, Dart 3.13.7, Chrome for Testing 156.0.8078.47.
No physical WebKit or external database services were used.

Verified on the proposed sources:

- Core and adapter fatal-info analysis passes.
- Core VM regression suite: 223 tests pass, including compiler-positive and nine
  compiler-negative identity probes. The new probes cover conditional lookup,
  mutation/commit bounds and concrete receipt revision-map keys.
- All 59 core/adapter/validation Dart files pass the formatting check.
- Validation tooling analysis, formatting, self-tests and workspace inventory
  check pass: 18 packages, 15 examples, zero workspace exemptions.
- An initial native Chrome run passed 30 tests, including reviewed UUID CRUD,
  schema recovery, request-error, transaction failure and typed scoped contracts.
  Subsequent typed edge-key tests pass on VM and native Chrome in the clean Git
  consumer below.
- Final adapter package lane passes analysis, formatting and all 54 test runs
  (22 VM, 32 Chrome, including native IndexedDB). Its Git-only manifest explicitly
  exempts the pub.dev dry-run. The adapter archive/minimal-consumer lane passes
  with exactly core, serialization and the adapter.
- Core archive/minimal-consumer validation passes with only its allowed closure.

The core package lane passes analysis, formatting and its 223 tests but its
publication dry-run in the prepared checkout reports only the uncommitted-file
warning (exit 65). No warning was suppressed and no prepared-branch commit was
made to satisfy packaging. This is distinct from a behavioral test failure. The identical core package
also passed `dart pub publish --dry-run` with **zero warnings** from the clean
committed local test fixture, confirming the warning is checkout state only.

### Immutable outside-workspace Git consumer

A task-local Git test fixture contains byte-identical library files and manifests
for core, serialization and the adapter. Its only repository-level substitution
is a three-package workspace declaration for isolation. It is not a publication
or an accepted upstream revision.

Fixture SHA: `c20378236817d022ee17036d97e08bbd475fc34a`.
All 29 relevant library/manifest files were compared to the proposed checkout.
The SHA-256 over `path + NUL + bytes + NUL`, sorted within each package in
core/serialization/adapter order, is:
`6dcae511c6bdeab9852d780ab75eb6198a685b407295da73649805f095becd4d`.

The new immutable-consumer helper resolved all three packages from that full Git
SHA **without dependency overrides**, checked every lockfile Git revision,
passed fatal-info analysis, and passed all nine VM/native-Chrome contract runs.
Those runs cover empty and reserved-looking raw IDs, malformed Unicode before
I/O, scoped/case-sensitive CRUD/reopen/delete isolation, conditional atomicity,
uniqueness rejection, delete/recreate revision protection and durable receipt
resolution/retry. The consumer independently resolved newer test/analyzer
versions than the workspace, without inheriting its dependency lockfile.

Commands (from the prepared repository root, with Dart and Chrome available):

```sh
dart analyze --fatal-infos packages/dddart packages/dddart_repository_indexeddb tool/validation
dart format --output=none --set-exit-if-changed packages/dddart packages/dddart_repository_indexeddb tool/validation
dart tool/validation/self_test.dart
dart tool/validation/validate.dart check
dart tool/validation/validate.dart package dddart --mode=local
dart tool/validation/validate.dart consumer dddart
dart tool/validation/validate.dart package dddart_repository_indexeddb --mode=local
dart tool/validation/validate.dart consumer dddart_repository_indexeddb
dart tool/validation/verify_indexeddb_git_consumer.dart c20378236817d022ee17036d97e08bbd475fc34a file:///tmp/issue78-git-fixture.eShFhD
```

Initial overlapping Chrome validation processes exhausted the host's available
threads and aborted Dart worker creation. Only task-owned test processes were
terminated; sequential execution recovered. An early edge-key test used the
unsupported database-enumeration API; it was replaced with a tracking factory
that directly verifies zero opens, and rerun. Neither failed attempt is counted
as a passing gate.

## Remaining integration acceptance

The fixture SHA above must not be recorded as the accepted public SHA. Once
Worky publishes the reviewed candidate and the integration is accepted into
main, the final Git verification command is:

```sh
dart tool/validation/verify_indexeddb_git_consumer.dart <accepted-full-main-sha>
```

Retain its output and accepted SHA as the final upstream-consumer evidence.
Independent review, publication, the parent/main integration and that final
upstream SHA are not claimed by this implementation work record. The same
helper is available for the published PR candidate before merge.

Use a dedicated database for each aggregate/identity codec. Changes of concrete
identity kind, stable codec registration key or canonical key format require an
explicit application migration; this integration does not convert UUID data
into application IDs. Payload format changes require an appropriate codec
version and explicit migration.

Cancellation (#74), isolation across separate tabs (#75), blocked schema upgrade
handling (#76), physical iPhone/WebKit evidence (#77), and pub.dev publication
(#30) remain separate. Existing racing-writer tests use connections in a single
browser context and are not a cross-tab/device proof.
