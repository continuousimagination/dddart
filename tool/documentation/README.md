# Executable documentation gate

Run from any working directory, using the script's absolute path if necessary.
The script locates the repository from its own file, never from the caller's cwd.
Use the development SDK (currently Dart 3.13.7), Python 3.10+ and Node 24.15.0+.
Resolve repository tooling first with `dart pub get` from the workspace root.

From that root:

```sh
# Fast drift/inventory check; no services or dependency installation.
python3 tool/documentation/validate.py check
# Refresh only canonical file inclusions after an intentional source edit.
python3 tool/documentation/validate.py sync
# Required local pre-publication gate for workflows without database services.
python3 tool/documentation/validate.py all --service-kind=none
# Database lanes; each fails when its required local service is missing.
python3 tool/documentation/validate.py all --service-kind=mysql
python3 tool/documentation/validate.py all --service-kind=mongo
python3 tool/documentation/validate.py all --service-kind=dynamodb
# Everything; all documented local services must be available.
python3 tool/documentation/validate.py all
# Verify the actual published Git setup instead of local archives.
python3 tool/documentation/validate.py run json --source=git
# Fault tests: real failing generation/analysis/run cases, no external services.
python3 tool/documentation/self_test.py
```

`--source=local` is the default. It reuses `stagePublishedPackage` from the shared
package validation tool to stage Pub-selected archive contents, then replaces
only DDDart source overrides in an otherwise exact quickstart manifest. Each
application starts in a system temporary directory with no generated artifacts
or workspace package config. Pub resolves its dependencies, documented commands
run, required parts must exist, analysis is fatal on infos, and output must match
exactly. Package closure is checked against the shared inventory. Temporary
applications/archives are deleted on both success and failure. Each command has a
timeout and reports its workflow, command, exit and diagnostics on failure.

Local staging is **not hosted-resolution proof**. `--source=git` uses the exact
manifest and verifies its lockfile revision. #100 must reuse these canonical
inputs with actual hosted versions and no overrides; #99 owns that transition.
Nothing here publishes a package or claims that a local service is a cloud test.

## Published source and coverage

`docs/quickstarts/workflows.json` declares files, direct DDDart imports, allowed
local closure, service requirements, command files, expected-output files and
optional JavaScript checks. The nine workflows cover seven primary applications,
additional complete website modeling/configuration programs, and a compile-only
Slack server. The Slack server is never run without a real application-owned
secret and sender. Every canonical Dart input must appear verbatim in scoped
published documentation. `commands.sh` and expected-output inclusions are checked
against the same files used by execution, preventing silent command/output drift.

The scopes are the root README, public package READMEs, public library entrypoint
comments, all website guides and canonical workflow READMEs. Every Dart fence in
those scopes must be either a canonical inclusion or explicitly classified in
`snippets.json`. The latter records a content digest, kind and contextual reason.
A new/changed fragment fails until a maintainer chooses a checked workflow/harness
or supplies an honest non-runnable classification. This is not a claim that
illustrative fragments compile. Deferred designs are negative examples, and the
full distributed HTTP example is matched byte-for-byte to the existing shared
example lane. Existing package/archive/browser/example gates remain required.

The gate also checks every public export/entrypoint against `PUBLIC_API.md` and
all 18 package rows against `CAPABILITIES.md`. It does not infer semantic API
compatibility from an export list. 1.0 is the first compatibility baseline.

JavaScript checks compile and run representative core/JSON programs under Node.
`node_runner.cjs` supplies the browser-like `self` global used by dart2js async
scheduling; it supplies no DOM or browser storage. These checks do not replace
native Chrome IndexedDB contracts, physical WebKit checks, or real-device tests.

## Changing documentation

Edit the canonical file first, then run `sync` and `check`. Keep imports in the
complete pubspec and update the workflow's expected output when behavior changes
intentionally. A missing builder, part or constructor must be fixed, not worked
around by retaining generated files. Add a new executable program to its workflow
and publish it with a `dddart-source` inclusion. `sync` never updates fragment
classification or API inventories automatically.

For a deliberate fragment change, `check` reports its document/fence identifier
and new digest. Review its context, kind and reason before updating the matching
record. Run the relevant execution lane, not just `check`.

## CI and release use

The Test workflow runs on every main-targeting PR and main push, with no docs-only
path filter. Its documentation job checks drift, runs the fault suite, executes
all unserviced consumers and portable JS paths. Database documentation steps reuse
the existing MySQL, MongoDB and DynamoDB package-service jobs. Missing required
services fail their lane. The Pages build/link checker remains a separate check.

For #101's release runbook, run `check`, the fault suite and `all` against the
release candidate with its required services, then retain the separate hosted
consumer results from #100. Git/local results do not substitute for that evidence.
