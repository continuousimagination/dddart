# IndexedDB parent integration — issue #79

## Prepared candidate and scope

Existing draft: https://github.com/continuousimagination/dddart/pull/85.
Prepared head: `599470e321f443b62e88c81bca5b48555c380e74`.
The supplied `feature/79-complete-indexeddb-integration-lifecycle-guarantees-and-browser-verifica`
branch and `main` target are preserved.

The candidate already contains the integrated implementation and regression
coverage from #78 (typed core/adapter integration), #74 (cancellation), #75
(independent-tab isolation) and #76 (blocked upgrades/connection lifecycle).
No additional persistence implementation is needed. This parent change updates
the adapter's stale physical-device status and links the completed #77 evidence;
it does not import the standalone device harness into the public package or
change any executable sources, dependency constraints, schema or receipt format.
Historical child records remain intact rather than being rewritten as new runs.

## Physical-device evidence and source equivalence

The original [physical report](https://github.com/continuousimagination/dddart/blob/a6460b05727614fb4c1900f89cb05eef167cb3df/tool/iphone_indexeddb/results/2026-11-15-iphone-14-plus.json)
is retained at evidence commit `a6460b05727614fb4c1900f89cb05eef167cb3df`.
Its bytes hash to SHA-256
`4cff7f4eefb92e013f54cab272e9ac9eb17aab0d4801fa66fbf6d81ef78be648`.
The [procedure](https://github.com/continuousimagination/dddart/blob/fe5feff185ae0c58a38467da25ff7f153bf2047a/tool/iphone_indexeddb/README.md)
and committed Git lockfile identify harness commit
`fe5feff185ae0c58a38467da25ff7f153bf2047a`, with `sourceDirty: false`.
Core, serialization and adapter all resolve without dependency overrides at
`62af23ffa369c2d2cba13c93e39eee4c90c2325d`, the PR #81 merge tested on device.

Direct Git comparison confirms that this tested merge and prepared candidate
`599470e321f443b62e88c81bca5b48555c380e74` have the **same complete Git tree**:
`79255bfc9e01828472154d3913c9e4f17c26e8a2`.
Thus the physical report applies to the same integrated adapter implementation
restored by the prepared PR. Source equivalence does not mean the separate-tab
harness or every cancellation/blocked-upgrade regression ran on the phone;
those broader regression suites ran on Linux/Chrome as described below.
This parent patch changes documentation only. The earlier merge was rolled back;
its historical acceptance/device-test SHA is not a claim that this restored PR
has already been reviewed, merged or accepted. Worky owns the new candidate SHA
and publication; final accepted-main verification remains a post-merge check.

Run `76bccfbc-6dd7-4241-8269-2f6f5c519170` was supplied by Sean from a physical
iPhone 14 Plus in regular Safari browser-tab mode, native IndexedDB, local HTTP.
The operator-entered iOS version is `26.7.1`; raw user-agent metadata is retained
unchanged and does not establish an exact WebKit build. The JSON contains 123
PASS log entries, zero FAIL entries, ten committed/rejected operation receipts,
completed baseline/reconciliation/fault flags and no pending lifecycle action.
PASS entries include repeated assertions/completion messages, not 123 distinct
tests. The recorded lifecycle verifications are:

| Action | Verified UTC, 15 November 2026 | Observed evidence |
| --- | --- | --- |
| Reload | 11:37:42 | Operator confirmation, new document, saved state/receipts verified |
| Background/resume | 11:38:19 | Operator confirmation, 18.188 seconds hidden, saved state/receipts verified |
| Safari close/reopen | 11:42:43 | Operator confirmation, new document, saved state/receipts verified |

Checks include committed CRUD, conditional revision/uniqueness rejection,
multi-record atomicity, ABA prevention, durable decisions/revisions, lost-result
reconciliation and identical retry, upgrade rollback/retry, codec rejection,
and recoverable storage errors. Fault triggers were injected over native IDB;
lost completion was deliberately discarded. These are not real quota exhaustion
or forced OS interruption during a write. Physical hardware/app-switcher actions
are operator attestations, not something the browser can independently prove.

[Issue #77](https://github.com/continuousimagination/dddart/issues/77) now records
Sean's requested closure after the successful manual run. It explicitly leaves
its independent-review criterion unchecked. This parent does not convert author
validation into independent device review, assert all original review criteria
were met, or supersede Worky's independent PR review. Installed PWA/Home Screen,
offline loading, real quota exhaustion/eviction, forced OS termination during a
write and long-term retention remain untested. Public publication remains #30.

## Integrated validation

Environment: Linux ARM64, Dart 3.13.7, Chrome for Testing 156.0.8078.47, native
IndexedDB with the browser sandbox enabled. Device results above are the retained
physical run, not a new run on this Linux host.

The outside-workspace immutable Git consumer passed at the device-tested
`62af23ffa369c2d2cba13c93e39eee4c90c2325d`: dependency resolution without overrides,
all three lockfile Git pins checked, fatal-info analysis, and nine VM/native
Chrome contract runs. It exercises scoped typed identities, malformed keys
before I/O, CRUD/reopen/delete isolation, conditional atomicity, uniqueness,
ABA protection and durable receipt resolution/retry. This is an actual public
repository Git resolution, not a locally fabricated fixture SHA.

The raw physical JSON was separately checked against its SHA-256, source pins,
committed harness lockfile, clean-source flag, chronological events, completion
flags, all ten distinct receipt IDs/decision types, all three confirmed lifecycle
entries and background visibility interval. The original report is unchanged.
This is implementation-side evidence reconciliation, not independent review.

All 72 tracked library/test/tool files plus package manifests and test-platform
configurations in core, serialization and adapter were compared byte-for-byte
with the device-tested merge. Their combined SHA-256, sorting repository-relative
paths and hashing `path + NUL + bytes + NUL`, is:
`46cc8f230893bdd0433d07e7e6d2538c516c24d7f42d867736c4a5464f927019`.

The full gate's native separate-tab harness passed ten rounds and resolved and
retried all 45 original operations after destroying/reopening both documents.
It verified revision races, unique-owner races/record consistency, cross-tab ABA,
durable rejection after unique release, unchanged replayed revisions and
changed-payload operation-ID rejection. Four distinct page/context identities
were recorded; cleanup completed before `PASS`. Its source manifest SHA-256 is
`41991a80167c1d9092bbbedae78cfedd47c96e03c69f723487fb1f36af3decf2`.
The report records prepared HEAD plus the documentation-only dirty tree, not an
invented published parent commit.

The integrated adapter package lane passed fatal-info analysis, formatting and
**94 VM/Chrome test runs with three explicit memory-only dispatched-close
skips**. Native runs include cancellation, blocked upgrades and version-change
lifecycle cases; memory skips do not replace their native assertions. The
adapter's Git-only publication exemption is unchanged. The adapter fix dry-run
also completed with nothing to fix.

### Terminal complete-gate result

`./scripts/test-all.sh` ran once, from **19:26:16 to 20:04:46 UTC on 15 November
2026**, and exited **0**. The invoking shell recorded the immediate command exit
status directly, without a pipeline. Completed coverage:

- Validation-tool fatal-info analysis/formatting, policy self-tests and workspace
  inventory/dependency-closure checks: 18 packages, 15 examples.
- The native ten-round separate-tab run described above.
- All **18 integrated package lanes: 1,711 passing tests, four skips** (three
  memory-only adapter cases, one MySQL case), including analysis, formatting,
  required generation and applicable publication dry-runs/exemptions.
- All **18 isolated consumers**: analysis, permitted minimal local dependency
  closure and entrypoint execution. These validator fixtures intentionally use
  fixture-only local path overrides; they are distinct from the immutable Git
  consumers verified without overrides.
- All **15 example lanes**: 53 entrypoints compiled, 17 also executed, 36
  compile-only and six explicitly excluded legacy entrypoints.

The SQLite lane used a task-local `lib/libsqlite3.so` symlink to the already
installed `/lib64/libsqlite3.so.0`, exposed only through this command's
`LD_LIBRARY_PATH`. Its 97 tests passed. No host library, service, configuration,
validation policy or test exclusion was changed. Existing generation warnings
about the analyzer's older language support remain; no unrelated dependency
upgrade was attempted. All required commands completed successfully.

This is the default **local** gate, not CI or `--with-services`. MongoDB,
DynamoDB Local and MySQL service-tagged tests were excluded under the existing
policy, and service-backed/Slack examples remained compile-only. No live
AWS/Slack integration, deployment or additional physical-device run is claimed.

The immutable Git consumer was then independently repeated at the exact
prepared PR head `599470e321f443b62e88c81bca5b48555c380e74`: resolution without
overrides, lockfile pin checks, fatal-info analysis and all nine VM/native Chrome
contract runs passed, exit 0. Browser lanes ran sequentially.

Reproduction commands, with the installed Dart/Chrome on PATH and
`CHROME_EXECUTABLE` set as needed:

```sh
dart pub get
dart tool/validation/verify_indexeddb_git_consumer.dart 62af23ffa369c2d2cba13c93e39eee4c90c2325d
dart fix --dry-run packages/dddart_repository_indexeddb
# Supply the task-local SQLite loader path described above when required.
./scripts/test-all.sh
dart tool/validation/verify_indexeddb_git_consumer.dart 599470e321f443b62e88c81bca5b48555c380e74
git diff --check
```

Raw local artifacts are retained at `/tmp/issue79-validation.wL6JWY/`, including
`full-gate.log`, direct `.exit`/start/finish files, `full-gate-summary.json`,
`cross-tab-full-gate.json`, both Git-consumer logs/exit files,
`device-report-validation.json` and `source-equivalence.json`.
Full-gate log SHA-256:
`ed78cab1b3f0b934c826e04320781930fb63cf22f79538681183f31eec2f81e1`.
The machine-readable source/evidence checks and logs are implementation artifacts,
not self-attested CI or independent-review evidence.

## Handoff

Only the adapter README and this parent work record change. Executable sources
and package/test manifests remain byte-identical to the verified prepared head;
`git diff --check` passes, and no unmerged entries exist. No candidate commit,
publication, PR readiness change, formal review, workflow mutation or final merge
was performed. Worky owns those handoffs; human final-merge authority is unchanged.
Repeat the immutable consumer at the final accepted main SHA after publication
and merge. The documented physical-device scope and missing independent device
review must remain explicit during that review.
