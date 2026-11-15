# Physical iPhone IndexedDB check — dddart #77

This standalone Dart web harness exercises the native IndexedDB adapter with
small, generic aggregates. A human operates the physical iPhone; the page makes
assertions and exports evidence. It does not require Flutter, Xcode, USB access,
a remote device service, or a GitHub Actions runner on the phone.

Core, serialization, and adapter are Git-pinned to the same accepted PR #81 merge:
`62af23ffa369c2d2cba13c93e39eee4c90c2325d`. The committed lockfile and build-time
check enforce those resolved revisions without dependency overrides. Dependencies
come from Git, not the surrounding workspace. The report separately records the
harness source commit and whether its source tree was modified at build time.

## Run on your Mac

Prerequisites: Git, Python 3, Dart **3.12–3.x**, and a physical iPhone. The launcher
also finds a compatible Dart bundled with an installed Flutter. On Sean's Mac it
selects the Flutter-bundled 3.12 SDK instead of the older default Dart 3.9 SDK.
`DART_BIN=/absolute/path/to/dart` can select another compatible SDK.

From the prepared checkout:

```sh
cd /private/tmp/dddart-iphone-77
./tool/iphone_indexeddb/run.sh
```

From a fresh directory on another computer:

```sh
git clone --single-branch --branch codex/issue-77-iphone-harness \
  https://github.com/continuousimagination/dddart.git dddart-iphone-77
cd dddart-iphone-77
./tool/iphone_indexeddb/run.sh
```

The script resolves the locked dependencies, verifies the Git pins, compiles the
page, and prints a LAN URL such as `http://192.168.0.18:8787/`. Keep the terminal
open and the Mac awake. Connect the iPhone and Mac to the same Wi-Fi, and open the
printed URL in **regular Safari**, not Private Browsing or another app's embedded
browser. Allow local-network access if macOS asks. If the URL fails, check the
Mac's Wi-Fi IP and whether the network isolates devices. Port 8787 can be changed
by passing a port to `run.sh`, but never change the address or port mid-run.

Only the compiled page is served. Test records and the report stay in the phone's
browser storage; the server does not receive the report. Stop with Control-C.

## iPhone checklist (about 10 minutes)

Use one test tab. Do not clear website data, change origins, rebuild the harness,
or start a second run while collecting evidence.

1. Enter the **iPhone model** and **iOS version**, including its build if shown in
   Settings → General → About → iOS Version. Tap **Start baseline**. Wait for the
   checks to finish. Save the exact displayed run URL, including the `#…` suffix,
   in Notes or a bookmark. That suffix identifies this run.
2. Tap **Discard result and reload**. After the automatic reload, tap
   **Reconcile and retry**. This deliberately discards an operation's response,
   then resolves its receipt and retries the identical request. It is not an
   assertion that the OS killed an in-flight transaction.
3. Tap **Run schema and fault checks**. Wait for completion.
4. Tap **Reload**. After reload, tick **I completed the armed action on this
   device**, then tap **Verify saved state**.
5. Tap **Arm background**. Switch to another app for at least 15 seconds, return
   to Safari, tick the confirmation, then tap **Verify saved state**.
6. Tap **Arm reopen**. Close the test tab. Swipe Safari away in the app switcher.
   Reopen Safari and the exact saved run URL. Tick the confirmation and tap
   **Verify saved state**. A restored run must retain its original run ID.
7. When the page says **Checklist complete for this mode**, add any notes and tap
   **Download results JSON**. On iPhone, use Safari's downloads list / Files to
   locate `dddart-77-<run-id>.json`. Attach that file in the Codex chat that prepared
   the harness, or attach it to [issue #77](https://github.com/continuousimagination/dddart/issues/77).
   **Show / select report** is a copy-and-paste fallback.

If anything fails, stop and export the report anyway. Include what you tapped
and what happened. If the page is blank or the run manifest disappears, send the
exact run URL and a screenshot or error text; do not restart and substitute a
passing run for that failure. A missing manifest is reported explicitly rather
than automatically creating fresh data.

The report includes user agent (including the exposed WebKit identifier),
operator-supplied device/OS details, timestamps, mode, origin, run ID, code
versions, results, visibility/page events, lifecycle attestations, and limits.
Safari may not expose an exact underlying WebKit build; record that as unavailable
rather than deriving a precise engine version from a generic user-agent token.

## What is checked

| Case | Evidence |
| --- | --- |
| CRUD | Create/read/update/delete; updated value and deleted identity checked after each lifecycle action |
| Conditional changes | Two-record create/update; stale revision and uniqueness rejection; ABA rejection after delete/recreate |
| Receipts | Committed and rejected operation decisions, rejection reasons, and exact revision maps retained across lifecycle actions |
| Atomicity | Stale batch leaves its other record unchanged; injected receipt-write failure rolls back both native records, unique claims, receipt and receipt count |
| Lost response | Caller intent/digest saved before dispatch; completion discarded; request reconstructed after reload; reconciliation and identical retry preserve revisions; changed payload with reused ID rejected |
| Schema | Native version-1 data seeded; injected upgrade abort preserves old version/data and omits schema marker; compatible retry succeeds; incompatible codec rejected without rewriting payload |
| Recoverable storage error | Injected factory-open failure becomes a typed connection error; native reads recover when injection is removed; exact retry succeeds after injected receipt failure |
| Lifecycle | Manual reload, app background/resume, and Safari tab/app close/reopen; verification reads expected state and never reseeds data |

Fault injection uses wrappers around **`idbFactoryNative`**. There is no fallback
to memory storage. Injected triggers and observed native rollback are labeled
separately. No actual quota exhaustion, OS eviction, device crash, or long-term
storage retention is claimed. Do not deliberately fill your phone's storage.

The initial supported procedure covers a **Safari browser tab**. Installed PWA,
other browsers, Private Browsing, offline application loading, and Flutter UI
behavior remain untested. This page has no service worker. A separate HTTPS /
installed-PWA procedure and independent report are needed to claim that mode;
Safari-tab data must not be assumed to transfer into a Home Screen app.

## Validation and acceptance

Local preparation checks:

```sh
cd tool/iphone_indexeddb
./dart.sh analyze --fatal-infos
./dart.sh test -p chrome --reporter expanded
./build.sh
# With serve.py/run.sh listening on 8787, and Node >=22 + Chrome installed:
node test/ui_smoke.mjs
```

The native browser integration test serializes and restores the caller manifest,
runs the contract/recovery scenarios, then deliberately deletes a database and
asserts that verification fails. The compiled-UI smoke test checks the guided
flow, page reload, background visibility, a full Chrome process restart, report
content, and missing-manifest detection at a mobile viewport. These are desktop
checks, **not physical iPhone evidence**. Temporary desktop reports are written
to the OS temporary directory, not committed as device evidence.

A device report does not itself close #77. Independent review must check the
physical-device provenance, pinned SHA, tested mode, lifecycle evidence, any
failures and the stated limits. Reproducible failures need separate tracked
issues before claiming support. Human attestations are explicit; the harness
cannot independently prove that it ran on physical hardware or that Safari was
swiped away. Keep #77 open until the device report and review are recorded.
