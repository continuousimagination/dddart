# Executable documentation gate

Run from any working directory, using the script's absolute path if necessary.
The script locates the repository from its own file, never from the caller's cwd.
The fast checks require Bash 3.2+, jq 1.6+, Git and standard Unix tools. Execution
checks also require the development SDK (currently Dart 3.13.7), Node 24.15.0+,
tar and GNU `timeout` (`brew install coreutils` on macOS supplies it).
Resolve repository tooling first with `dart pub get` from the workspace root.

From that root:

```sh
# Fast drift/inventory check; no services or dependency installation.
bash tool/documentation/validate.sh check
# Refresh only canonical file inclusions after an intentional source edit.
bash tool/documentation/validate.sh sync
# Required local pre-publication gate for workflows without database services.
bash tool/documentation/validate.sh all --service-kind=none
# Database lanes; each fails when its required local service is missing.
bash tool/documentation/validate.sh all --service-kind=mysql
bash tool/documentation/validate.sh all --service-kind=mongo
bash tool/documentation/validate.sh all --service-kind=dynamodb
# Everything; all documented local services must be available.
bash tool/documentation/validate.sh all
# Verify the actual published Git setup instead of local archives.
bash tool/documentation/validate.sh run json --source=git
# Fault tests: real failing generation/analysis/run cases, no external services.
bash tool/documentation/self_test.sh
```

`--source=local` is the default. Bash invokes the same `dart pub publish
--skip-validation --to-archive=...` command as the shared package gate to stage
Pub-selected archive contents, then replaces
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

The surface inventory covers **every repository Markdown/MDX/RST document**, including
standalone guides, testing/how-to pages, all sample READMEs and the website. All
library and sample Dartdoc is discovered recursively, including implementation libraries.
New documents fail until added to `surfaces.json` after review. Historical work
records, specs, changelogs and handoffs require a visible notice pointing to current
usage; agent steering files are explicitly internal. Those records preserve history
without advertising obsolete APIs as supported instructions.

Every Dart fence in current documentation must be a verbatim `dddart-source`
inclusion owned by a checked quickstart or an active example entrypoint. There
is no illustrative-fragment exemption. Incomplete duplicates have been replaced
with links to complete programs, source contracts or executable tests. All 15
sample README program tables and exact validation commands are checked against
`tool/validation/inventory.json`, so a changed execution boundary cannot retain an
old claim that a program runs. The shared example gate separately discovers new
entrypoints and verifies each program's declared generation/analysis/compile/run lane.

Relative links, Markdown heading anchors, and GitHub links into `main` or the
canonical code revision are resolved against this checkout. Other immutable
revision links may intentionally preserve historical evidence and are not mapped
to current files. External URL availability is not checked by this deterministic
local gate. The website checker additionally validates site routes/assets/anchors.
Links to code are not a claim that arbitrary prose is mechanically verified:
API behavior still needs review against the implementation and its contract tests.

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
and publish it with a `dddart-source` inclusion. `sync` never updates surface, sample or API inventories automatically.

For new code, add a complete canonical workflow or inventoried sample first,
then include it. Add each new guide to `surfaces.json` as current. Keep sample
coverage tables exactly aligned with the shared inventory; `sample_table` in
`validate.sh` defines their canonical Markdown using jq. Run the relevant execution lane,
not just `check`. The fault suite checks new documents, deep Dartdoc, standalone
snippets, broken links/anchors, sample coverage drift and missing history notices,
as well as real failing generation, analysis and execution.

## CI and release use

The Test workflow defines gates for every main-targeting PR and main push, with no docs-only
path filter. It is currently disabled in this repository; run these gates locally
until the owner re-enables it. Its documentation job checks drift, runs the fault suite, executes
all unserviced consumers and portable JS paths. Database documentation steps reuse
the existing MySQL, MongoDB and DynamoDB package-service jobs. Missing required
services fail their lane. The separate active Documentation workflow runs the fast
surface/source/link checks on every main-targeting PR and main push. It never deploys.
Website builds and deploys only for changes to the site, its imported quickstarts,
the shared checker helper or its workflow file. Its homepage imports complete
checked core programs as raw source; a fault test
rejects replacement with an unchecked code literal. Heavy Dart execution remains
in the local/Test gates.

For #101's release runbook, run `check`, the fault suite and `all` against the
release candidate with its required services, then retain the separate hosted
consumer results from #100. Git/local results do not substitute for that evidence.
