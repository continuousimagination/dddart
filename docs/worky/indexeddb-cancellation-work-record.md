# IndexedDB cancellation work record — issue #74

The initial implementation evidence below is historical. The revision section
records integration with the updated parent target and supersedes the original
pending-open close behavior and source fingerprint.

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
  Revision note: the integrated #76 behavior now abandons a pending open promptly,
  drains its late connection, and aborts an abandoned queued upgrade; it does not
  cancel operation transactions already dispatched.

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

## Revision: merge conflict resolution (2026-11-14)

Existing deliverable: https://github.com/continuousimagination/dddart/pull/82.
Prepared branch: `feature/74-indexeddb-define-and-verify-cancellation-of-in-flight-operations`.
Prepared head: `21959bc0fc8db79abf6690d9eb4cc940e1559890`.
Merged target: `feature/79-complete-indexeddb-integration-lifecycle-guarantees-and-browser-verifica`
at `0d9ea4c39866c3363588d80c2bbb247284c71af5`.

Resolved the CHANGELOG, README, and repository `close()` documentation conflicts
by retaining both sets of changes. The integrated repository retains the #74
synchronous dispatch barrier and uncertain-result cancellation contract alongside
#76's prompt pending-open abandonment, late-request draining, queued-upgrade
abort, and version-change invalidation. The README retains #75's independent-tab
harness and removes outdated statements that #75/#76 are still missing.

The first focused VM regression run reproduced nine setup failures because the
#74 database wrapper did not delegate #76's new `onVersionChange` stream. The
wrapper now delegates that stream. The deterministic close-during-open test now
awaits close and all callers **before releasing the native open**, checks zero
transactions (including schema reads), then releases and explicitly awaits the
late connection's closure. Both VM and native Chrome exercise this combined
contract without a timing sleep. No existing operation transaction is aborted.

Validation of the merged working sources (Linux ARM64, Dart 3.13.7, native Chrome
156.0.8078.47, sandbox enabled):

- `dart pub get` from the repository root: exit 0, without dependency overrides.
- `dart analyze --fatal-infos packages/dddart_repository_indexeddb tool/validation`:
  exit 0, no issues.
- `dart format --output=none --set-exit-if-changed packages/dddart_repository_indexeddb tool/validation`:
  exit 0, 27 Dart files unchanged.
- `(cd packages/dddart_repository_indexeddb && dart test --reporter expanded)`:
  exit 0, **94 passing tests, 3 explicit memory-only dispatched-close skips**.
  Includes all 12 native cancellation cases, all four native blocked-upgrade/
  version-change cases, and the VM/native pending-open lifecycle regressions.
  Log: `/tmp/issue74-revision-adapter.log`.

The final adapter fingerprint covers 28 tracked files, sorted by repository-relative
path, hashing `path + NUL + bytes + NUL` for each file with SHA-256:

`7b0487c495bd97f14ef95d7ce0a6f46bb57ea606ee133a843def5b2041c51687`

This fingerprint identifies the actual tested merged sources, not the old PR head.
Worky retains ownership of the merge commit, publication to the existing PR,
recording the new tested head SHA, independent review, and workflow handoff.
No publication, formal review, merge to the target, or physical WebKit verification
is asserted here.

Additional revision checks:

- `dart fix --dry-run packages/dddart_repository_indexeddb`: exit 0, nothing to fix.
- `dart tool/validation/validate.dart consumer dddart_repository_indexeddb`:
  exit 0; isolated consumer analysis/execution passed with only core,
  serialization, and the adapter in its allowed local closure. This validator
  uses temporary consumer-only path overrides, not a published-Git dependency
  verification. Log: `/tmp/issue74-revision-consumer.log`.
- The required repository wrapper's native separate-tab harness passed **10
  rounds**, with successful browser/profile cleanup. Its merged implementation
  source manifest SHA-256 is
  `41991a80167c1d9092bbbedae78cfedd47c96e03c69f723487fb1f36af3decf2`.
  Its report correctly identifies the prepared HEAD plus dirty working sources,
  not a nonexistent published merge commit. The JSON is retained in
  `/tmp/issue74-revision-full-gate.log`.

### Full repository gate limitation on this runner

`./scripts/test-all.sh` was run against the merged sources. Its policy self-tests,
inventory validation, independent-tab harness, and complete adapter package lane
passed (the latter independently reported 94 passes and 3 intended skips).
However, the unrelated `dddart_repository_sqlite` tests fail at connection setup:

```text
Invalid argument(s): Failed to load dynamic library 'libsqlite3.so':
libsqlite3.so: cannot open shared object file: No such file or directory
```

Read-only `ldconfig -p` lists `/lib64/libsqlite3.so.0`, not the unversioned
`libsqlite3.so` requested by the Dart dependency. The subsequent SQLite
`Connection is not open` failures follow that loader failure. No SQLite files,
host libraries, loader configuration, service state, or test exclusions were
changed to work around it. The complete repository gate is **not passing** on
this runner and is not represented as accepted CI or independent-review evidence.
The implementation/conflict resolution is complete; repository-wide validation
and candidate publication remain distinct Worky/operator handoff concerns.

The wrapper was terminated by its configured 1,800-second command timeout
(SIGTERM) while running the core isolated-consumer lane. Before termination,
all 18 integrated package lanes were attempted: 17 reported passing tests and
SQLite reported the native-loader failures above. The adapter isolated-consumer
lane also passed within the wrapper (in addition to the separate successful
consumer run). Remaining isolated-consumer lanes and all example lanes were not
completed. No full-wrapper exit-0 result is claimed. All task-owned validation
commands have ended; no retry, host mutation, commit, or publication was performed.

The three conflict resolutions and the small harness/documentation updates are
staged with no unmerged entries or unstaged changes. `HEAD` remains the prepared
PR head and `MERGE_HEAD` remains the supplied target; Worky can finalize the merge
commit and publish the existing PR using its own handoff.
