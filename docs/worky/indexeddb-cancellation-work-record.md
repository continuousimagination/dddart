# IndexedDB cancellation work record — issue #74

## Scope and contract

Prepared base: `503190f7b2db51010acfee3bb7be0fb988442110`.
The supplied implementation branch and parent target are preserved. This is an
adapter-only change: no core/browser dependency, schema migration, receipt format
change, UI policy, cross-tab claim, or physical WebKit claim is introduced.

- `IndexedDbCancellation` is a one-way, per-call signal accepted by the concrete
  adapter's `commitConditional`. Before transaction creation it produces
  `IndexedDbOperationCancelled` carrying the prepared operation ID and digest,
  without dispatching mutations or a receipt. A database open already pending
  finishes first; cancellation is not a blocked-open/upgrade escape hatch.
- After transaction creation, the signal stops waiting and returns `uncertain`,
  never rejection or rollback. The original transaction continues and both race
  branches remain observed. Storage may already have committed when cancellation
  wins the acknowledgment race. Receipt resolution and identical retry preserve
  the original ID, digest and revision map.
- Independent Future timeout/subscription cancellation does not abort IndexedDB.
  Basic CRUD has no durable operation receipt; callers needing recoverable
  uncertain outcomes must use conditional operations and detached immutable input.
- `close()` is a synchronous operation-dispatch barrier plus connection-close
  request, not transaction cancellation or a drain. The check is immediately
  adjacent to transaction creation, with no intervening async boundary. Native
  transactions already created continue normally; calls awaiting opening cannot
  dispatch afterward. Opening/validation itself may finish before close returns.
  New instances can reconcile receipts after closing the original instance.

## Deterministic regression design

The shared test contract runs against the actual memory factory and native
IndexedDB (not `idbFactoryBrowser` or a silent fallback). Wrappers gate database
opening and transaction acknowledgment without delaying native requests or
trying to keep an idle browser transaction alive. Real completion/abort is
observed immediately, separately from the held acknowledgment.

Cases cover already-cancelled input with zero opens, cancellation while opening,
close while opening for every repository entry point, cancellation before real
commit and after real commit but before acknowledgment, confirmed completion
winning, independent timeout, conditional/basic save/delete close-after-dispatch,
and late typed completion failure/request-setup abort after the waiter cancels.

The update/create batch changes aggregate snapshots and unique claims together.
Assertions inspect public reads plus raw aggregate/index/receipt/count records,
preserve an unrelated committed aggregate, verify exact pre-state after abort,
and prove reconciliation and identical retry neither change revisions nor
increment receipt counts twice. Late losing-branch errors are observed inside a
guarded zone and checked for uncaught errors. Native request-error bubbling also
retains the existing separate duplicate-request regression.

The memory factory shares handles and closes them immediately; its behavior is
not native IndexedDB close semantics. Three dispatched-close cases are explicitly
skipped on memory and executed on native Chrome. Raw inspection handles are kept
until teardown so the memory harness does not accidentally close the repository.
The browser suite is serialized through `dart_test.yaml` to limit overlapping
compiler/renderer workers on shared validation hosts.

## Validation evidence

Environment: Linux ARM64, Dart 3.13.7, Chrome for Testing 156.0.8078.47.
The final proposed adapter sources pass:

- Fatal-info analysis for the adapter and validation tooling.
- Formatting for all 21 adapter/tooling Dart files; `dart fix --dry-run` reports
  nothing to fix for the adapter.
- The complete adapter suite: **75 passing test runs, 3 explicit memory-only
  dispatched-close skips**, including all 12 new native cancellation/lifecycle
  cases and 9 new memory cases. The final run exited 0. The focused native suite
  also passed independently (12 cases).
- Validation policy self-tests and inventory check: 18 packages, 15 examples,
  zero workspace exemptions.
- The archive/minimal-consumer lane: fatal-info analysis and execution pass;
  only core, serialization and the adapter resolve as local packages. This lane
  intentionally uses its validator's temporary path overrides; it is not a
  published immutable-Git consumer or accepted upstream SHA claim.
- `git diff --check` passes.

Commands from the repository root, with Dart on PATH and `CHROME_EXECUTABLE`
pointing to the installed native Chrome executable:

```sh
dart analyze --fatal-infos packages/dddart_repository_indexeddb tool/validation
dart format --output=none --set-exit-if-changed packages/dddart_repository_indexeddb tool/validation
dart fix --dry-run packages/dddart_repository_indexeddb
dart tool/validation/self_test.dart
dart tool/validation/validate.dart check
dart tool/validation/validate.dart consumer dddart_repository_indexeddb
(cd packages/dddart_repository_indexeddb && dart test --reporter expanded)
```

The adapter test run was invoked directly (without the nested validator runner)
to fit the shared host's process/thread budget. Its log is
`/tmp/issue74-adapter-tests-final.log`; consumer evidence is
`/tmp/issue74-consumer-final.log` in the implementation environment.

**Full repository gate not established:** `./scripts/test-all.sh` was attempted,
but its nested adapter runners failed to start DartWorker/Chrome threads with
`Resource temporarily unavailable`. Read-only inspection found the gateway
cgroup task limit was 224. The failed wrapper attempts were terminated through
their task-owned process handles; no service, host limit, or other assignment
was changed. Serializing suites alone did not make that nested wrapper fit.
The same final adapter suite passed directly afterward. This is not recorded
as a passing full-repository/package-wrapper gate; other packages' gates were
not reached. Logs: `/tmp/issue74-full-gate.log` and
`/tmp/issue74-full-gate-final.log`.

### Exact tested sources

The prepared base is not represented as a commit containing these changes.
SHA-256 over all 22 nonignored adapter files (tracked plus new files), sorted by
repository-relative path, hashing `path + NUL + bytes + NUL` for each file:

`33ec798f0d5717804df1d0151505eda494e2af57349651c87f04cd9fe67be419`

This covers implementation, tests, package manifests/configuration and adapter
documentation. This work record is outside that package and is not part of the
fingerprint. The candidate commit SHA remains a Worky publication artifact,
not a fabricated local validation reference.

## Publication and independent review

Worky owns the candidate commit, PR publication, formal independent review and
workflow evidence. No PR, review verdict, published tested SHA or merge is claimed
by this implementation record. At publication/review handoff, retain the actual
candidate PR URL and full tested head SHA alongside this record and its validation
results; independent review must inspect that exact candidate. Final merge
remains with the human owner. Physical iPhone/WebKit validation remains #77;
separate-tab isolation and blocked upgrades remain #75 and #76.
