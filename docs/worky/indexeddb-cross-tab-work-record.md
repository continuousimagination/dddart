# IndexedDB separate-tab verification — issue #75

Initial results below are historical. For the current parent-integrated R1
revision and terminal full-gate evidence, see the final section.

## Scope and revision

The adapter/core sources tested are exactly prepared Git SHA
`503190f7b2db51010acfee3bb7be0fb988442110`. This change adds a harness, CI invocation,
and evidence, not another implementation of conditional writes or receipts.
The prepared feature branch and parent integration target were preserved.

The harness was tested as uncommitted changes on that SHA; it is **not** claimed
to exist at the base commit. The machine-readable
[run report](indexeddb-cross-tab-results.json) records every library/manifest and
harness file's SHA-256, the actual working-tree status at execution, and the
combined source-manifest hash:
`d6379fac3f2f55b1a3597ca15feb8962e3da058726c51d804c0493eefc299b7e`.
This pins the executed sources without inventing a published candidate SHA.
Worky owns candidate commit/publication and subsequent independent review.

## Real-browser result — 12 November 2026

Environment: Linux ARM64, Dart 3.13.7, Chrome for Testing **156.0.8078.47**,
DevTools protocol 1.3. Chrome ran headless with its sandbox enabled. No memory
factory, external database service, physical device, or WebKit was used.

The default 10-round run **passed**:

| Check | Observed result |
| --- | --- |
| Independently loaded same-origin tabs | Two distinct top-level `page` targets and Dart context IDs; both opened native IndexedDB against the same database |
| Same-revision races | 10 committed writers and 10 `staleRevision` rejections; both tabs read the winner's exact snapshot/revision |
| Shared unique-value races | 10 committed owners and 10 `uniqueConflict` rejections; both tabs found exactly the winner and no losing record |
| Cross-tab delete/recreate ABA | B staged its old-revision write before A deleted and recreated the identity; B received `staleRevision` and the new incarnation was preserved |
| Receipt recovery after page destruction | Both original page targets closed; two newly loaded pages resolved and retried all **45** original operations using their original IDs, payloads, and digests |
| Durable rejection despite changed conditions | After the last unique owner was deleted, the losing claim still replayed its original rejection rather than acquiring the now-free value |
| No duplicate mutation | Replay preserved exact receipts, existing records, unique owners, absent losing/deleted records, and all surviving revisions, including the recreated aggregate |
| Changed-payload operation-ID reuse | Both commit and resolution with the changed digest failed with `constraint`; data and original receipt were unchanged |

The 45 receipts comprise **24 committed**, **21 rejected** (11 stale revision,
10 unique conflict), and **zero uncertain** outcomes. The run report includes
every request, precomputed digest, and exact original/replayed result, plus all
four page target IDs and independent Dart context IDs.

The coordinator prepares both tab-local requests before sending either commit,
then dispatches both without waiting for the other result. It does not implement
a cross-tab application mutex. Native IndexedDB supplies transaction ordering;
the harness does not require or claim a particular winning tab or browser process
layout. Independent JavaScript documents, not distinct OS processes, are the
isolation boundary under test.

## Repeat and verification

With Dart and Chrome available, from the repository root:

```sh
dart pub get
dart packages/dddart_repository_indexeddb/tool/verify_cross_tab.dart > cross-tab-results.json
dart tool/validation/validate.dart package dddart_repository_indexeddb --mode=local
dart tool/validation/validate.dart consumer dddart_repository_indexeddb
dart tool/validation/self_test.dart
dart tool/validation/validate.dart check
```

Set `CHROME_EXECUTABLE` if Chrome is not on the normal path. The optional positive
round-count argument follows the harness filename. The runner needs no Node or
WebDriver installation. Each CDP command has a 30-second timeout; failed checks
exit nonzero. Test-owned temporary browser/profile, database, and loopback server
are cleaned up. A preliminary one-round smoke run also passed.

The adapter's CI matrix lane invokes the same default harness after integrated
package validation and uploads the resulting JSON. The repository's
`scripts/test-all.sh` invokes it as well, keeping the local and CI checks aligned.
CI execution is not claimed by this local record.

Fatal-info adapter/validation-tool analysis, formatting, validation policy
self-tests, workspace inventory checks (18 packages, 15 examples), and the
isolated minimal adapter consumer all pass. The standalone VM suite passes all
22 tests. The initial combined package run reached 49 passing tests before
Dart worker creation failed with `Resource temporarily unavailable`; a CPU-bound
retry and a Chrome-only sequential retry also encountered the host thread limit.
These interrupted attempts are not claimed as successful package gates. No host
limits or services were changed, and only task-owned failed test processes were
terminated. A preliminary page-readiness timeout prompted deterministic
navigation: the final harness now subscribes to `Page.loadEventFired` before
explicit navigation, then verifies the participant's initialization marker. The
final standalone 10-round run above passed with that implementation, and
`scripts/test-all.sh` repeated the same 10-round harness successfully. Its
integrated adapter lane then passed analysis, formatting, **all 54 VM/Chrome test
runs** (22 VM, 32 Chrome), and the Git-only publish-dry-run exemption. This is the
successful final adapter gate; the earlier interrupted attempts do not replace it.

## Independent review and limits

Independent review is **not self-attested**: Worky owns formal review and its
publication against the published candidate. The implementation handoff provides
this evidence for that review; this record does not assert approval or merge.
After publication, repeat the harness at the full candidate SHA so its report
records a clean committed candidate, and retain the independent review reference
with that report. The source hashes above identify the locally verified patch
until that publication occurs.

Cancellation (#74), blocked schema upgrades (#76), and physical iPhone/WebKit
validation (#77) remain separate. The temporary-profile test demonstrates durable
IndexedDB outcomes after destroying/reopening both page contexts, not browser
crash/power-loss durability, origin eviction resistance, or physical WebKit
behavior. No production adapter code, domain naming policy, deployment,
workflow/project state, branch target, or merge authority changed.

## Integrated parent merge and R1 revision — 13 November 2026

This section supersedes the initial local-source verification above for Worky
assignment `773340d8-a9b1-4e13-b636-f395c443d944` / issue #75 / PR #83. Earlier
results remain historical evidence, not validation of the newly integrated
parent adapter. The new [compact report](indexeddb-cross-tab-cleanup-results.json)
records only checks rerun against this prepared worktree's integrated sources.

### Merge and resolution

Worktree: `/home/ec2-user/.openclaw/workspace-dev/.worky-attempt.Ie4wFpZfp4/clone`.
The prepared branch remains
`feature/75-indexeddb-prove-conditional-write-isolation-across-separate-browser-tabs`.
`HEAD` remains `b726123d00c4aaaf41c6be83319c82caed61dc5d`. The command
`git merge --no-commit --no-ff 3164d1e81eddb3bfc17fdfd05d14a3e77dec4efc`
integrated the supplied target
`feature/79-complete-indexeddb-integration-lifecycle-guarantees-and-browser-verifica`.
`MERGE_HEAD` deliberately remains
`3164d1e81eddb3bfc17fdfd05d14a3e77dec4efc`; no merge commit or publication was
performed. The initial merge exited 1 because of one content conflict in
`packages/dddart_repository_indexeddb/README.md`.

The resolution retains both the parent's blocked-upgrade/lifecycle documentation
and this branch's separate-tab harness section, removes obsolete claims that
#75/#76 coverage is still absent, and documents R1 cleanup behavior. The other
eight parent files merged without conflict. Parent production adapter and new
blocked-upgrade/open-lifecycle test files match the exact supplied target; no
additional persistence implementation or sibling work was introduced.

### R1 source recovery and behavior

Inspected and recovered exactly these retained files from the **read-only** old
worktree `.worky-attempt.SfL6xIF0G6/clone`, after confirming its HEAD and the
runner's unchanged base matched the reviewed head:

- `packages/dddart_repository_indexeddb/tool/verify_cross_tab.dart`
- `packages/dddart_repository_indexeddb/tool/verification_cleanup.dart`
- `packages/dddart_repository_indexeddb/test/verification_cleanup_test.dart`

Recursive profile deletion is asynchronous and retries filesystem failures at
most five times, backing off 100/200/400/800 ms; an already-removed directory is
successful cleanup. Teardown attempts every step, reports every persistent
failure, and preserves the original verification error and stack. Without a
primary verification failure, a cleanup failure is rethrown with its original
stack and the process exits nonzero. Socket close, browser exit, and server close
have explicit timeout bounds. The runner emits `PASS` JSON only **after** cleanup
succeeds, and includes the helper in its source manifest. Only test tooling is
changed beyond the supplied parent merge and README conflict resolution.

The old report at
`.worky-attempt.SfL6xIF0G6/clone/docs/worky/indexeddb-cross-tab-cleanup-results.json`
is referenced by path/hash for historical provenance, **not reused as evidence**
for these changed parent sources. No old raw report is presented as a new run.

### Final integrated-source verification

Environment: Linux ARM64, Dart **3.13.7**, Chrome for Testing **156.0.8078.47**,
with Chrome's sandbox enabled and no memory factory substituted for native IDB.
All commands ran from the prepared worktree (the focused `dart test` ran from
the adapter package after root workspace resolution):

```sh
dart pub get
dart analyze --fatal-infos packages/dddart_repository_indexeddb tool/validation
dart format --output=none --set-exit-if-changed packages/dddart_repository_indexeddb tool/validation
(cd packages/dddart_repository_indexeddb && dart test -p vm test/verification_cleanup_test.dart --reporter expanded)
dart fix --dry-run packages/dddart_repository_indexeddb
# Run this default 10-round command three times, each with its own fresh profile:
dart packages/dddart_repository_indexeddb/tool/verify_cross_tab.dart
./scripts/test-all.sh
```

Root dependency resolution, fatal-info analysis, formatting (**24 files, zero
changed**), all **9** focused VM cleanup tests, and the fix dry-run passed (all
exit 0; no fixes suggested). The tests exercise real populated-directory
deletion, deterministic transient/persistent filesystem failures, the five-attempt
bound, already-removed paths, non-filesystem errors without retry, all-step
teardown, and preservation of original errors/stacks with or without cleanup
failure. No claim is made that real Chrome happened to reproduce the transient
filesystem failure during successful browser runs.

All **three** consecutive default **10-round** clean-profile browser runs exited
**0**, including cleanup. Each proved same-revision one-winner/stale rejection,
unique-value one-owner/record consistency, cross-tab delete/recreate ABA, durable
rejection after unique release, and identical resolution/retry of **45** original
operations after destroying/reopening both pages. Each had **24 committed** and
**21 rejected** receipts (11 stale, 10 unique), zero uncertain results, four
independent page/context identities, no duplicate mutation/revision, and
changed-payload rejection.

All three runs and the full gate's fourth run match the integrated **32-file**
source manifest:
`e4670ca8824190b63e156df41c3c9928c285e1965928079b9e0ab406dffe4783`.
The cleanup test is pinned separately at
`09ad523f4e4deb1f32aca0d1b29c01d7d2b66f024f9b695fc0c55185d64f5ae2`.
All recorded hashes were recomputed after the gate. An additional snapshot of
**841** tracked non-evidence files remained unchanged through verification;
there were no post-test source changes.

### Complete local gate: terminal evidence

The full gate was run **once** against these integrated sources with the correct
SQLite environment and was allowed to finish. It started at `2026-11-13T16:55:28Z`
and finished at `2026-11-13T17:32:57Z`, with terminal script exit **0**. The original
shell wrote the script's immediate `$?` directly to
`/tmp/issue75-integrated.Uuw1Nm/test-all.exit` and exited with that same status.
This is not a pipeline-status inference or a running-state claim.

```sh
export PATH=/home/ec2-user/.local/share/flutter-3.47.8/bin/cache/dart-sdk/bin:$PATH
export CHROME_EXECUTABLE=/home/ec2-user/.local/share/chrome-for-testing-156.0.8078.47/chrome-linux-arm64/chrome
export LD_LIBRARY_PATH=/tmp/issue75-integrated.Uuw1Nm/lib
./scripts/test-all.sh > /tmp/issue75-integrated.Uuw1Nm/test-all.log 2>&1
GATE_EXIT=$?
printf '%s\n' "$GATE_EXIT" > /tmp/issue75-integrated.Uuw1Nm/test-all.exit
```

The task-local `lib/libsqlite3.so` symlink points to the pre-existing
`/lib64/libsqlite3.so.0`. No packages were installed, host services/configuration
changed, or validation policy relaxed. Existing generator output warns that its
analyzer dependency's language support predates this installed Dart SDK; no
unsupported dependency upgrade was attempted, and all required checks passed.

Completed coverage:

- Validation-tool fatal-info analysis/formatting, validation-policy self-tests,
  and inventory/dependency checks (**18 packages, 15 examples**).
- Another native Chrome 10-round separate-tab run with **45** operations
  resolved/retried; `PASS` includes successful cleanup and the same manifest.
- **All 18 integrated package lanes: 1690 passed, 1 skipped**.
  The IndexedDB lane passed **73 VM/Chrome tests**, including the parent's new
  blocked-upgrade and connection-lifecycle regressions plus the R1 cleanup tests.
  The SQLite lane passed **97 tests**. Analysis, formatting, required generation,
  and applicable publish dry-runs/exemptions completed.
- **All 18 isolated consumers** completed analysis, minimal-entrypoint execution,
  and permitted dependency-closure verification.
- **All 15 example lanes** completed their configured local policy: **53 compiled
  entrypoints**, **17 also executed**, **36 compile-only**, **six legacy exclusions**.
  Generation, analysis, formatting, and available example tests completed.
- No terminal validator/test-failure markers were found.

Retained raw artifacts are under `/tmp/issue75-integrated.Uuw1Nm/`:
`cross-tab-{1,2,3}.json`, corresponding `.stderr`/`.exit` files,
`cross-tab-full-gate.json` (extracted from the full log), focused-check logs and
exit files, the pre-gate source snapshot/merge state, and `test-all.log` with
terminal/start/finish files. The compact report pins their exact paths and
SHA-256 values. Full-gate log SHA-256:
`1d5910c86a474276bc842b9838b6c32466c0a34a4febb3a84c9a942260448187`.

### Limits and handoff

This is the default **local** gate, not CI or `--with-services`.
`requires-mongo`, `requires-dynamodb`, and `requires-mysql` tests were excluded
under the repository policy; the MySQL suite also reported one skipped test.
Service-backed examples were compile-only. No live Slack/AWS integration,
physical iPhone/WebKit behavior, browser crash/power-loss durability, or origin
eviction resistance is asserted. Raw logs are local temporary artifacts, not
committed repository files.

The merge has no unresolved index entries; staged and unstaged `git diff
--check` both pass. Intended source/evidence changes remain available for the
Worky-owned merge commit, publication, candidate-SHA verification and independent
review. No branch/PR creation, workflow/GitHub mutation, formal review approval,
final merge, deployment, or external lifecycle messaging was performed.
