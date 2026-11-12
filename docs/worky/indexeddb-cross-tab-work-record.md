# IndexedDB separate-tab verification — issue #75

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
