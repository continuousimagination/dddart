# Develop and test DDDart

Run `dart pub get` from the repository root. Use the SDK constraint in the
[root pubspec](../pubspec.yaml). Make changes in the relevant package under
`packages/`, update regressions and examples with the code, then run the
checks for the affected packages.

## Package and example checks

Run these commands from the repository root:

```sh
# Validate coverage and dependency policy.
dart tool/validation/validate.dart check
dart tool/validation/self_test.dart

# Check one package or example.
dart tool/validation/validate.dart package dddart_json --mode=local
dart tool/validation/validate.dart example dddart_json_example --mode=local

# Test an isolated consumer of the package archive.
dart tool/validation/validate.dart consumer dddart_repository_mysql

# Run the full local gate, including native Chrome.
./scripts/test-all.sh
```

The [shared inventory](../tool/validation/inventory.json) lists package
closures, generation rules, sample programs, and services. Package checks
regenerate required parts before analysis and tests, then check package
contents and isolated consumer resolution. The example lane uses its own
pubspec, generates the needed parts, analyzes and compiles its programs, and
runs entries marked for execution. Keep the inventory and the example's program
table in sync when adding or changing an entry. Do not edit generated parts.

Use `--mode=local` to run without the test databases: it excludes the tagged
service tests and compiles the service examples. Use `--mode=ci` for a package
or example whose required service is running; a missing service fails the
lane. Run `./scripts/test-all.sh --with-services` for all required lanes.
Start disposable databases using the matching [MySQL](../docs/quickstarts/mysql/README.md),
[MongoDB](../docs/quickstarts/mongodb/README.md), or
[DynamoDB Local](../docs/quickstarts/dynamodb/README.md) setup. Keep test
storage separate from application data. The SQLite adapter needs its native
shared library but no database server.

The CI matrices come from `validate.dart matrix` and
`validate.dart example-matrix`. Use the
[Actions page](https://github.com/continuousimagination/dddart/actions) to see
which workflows are enabled and their results. To install the optional
pre-push hook for the local gate, run `./scripts/setup-hooks.sh`.

## Browser validation

Install Chrome for browser checks. Set `CHROME_EXECUTABLE` if needed. The
IndexedDB package's `dart test -p vm` lane exercises its memory/failure
contracts; `dart test -p chrome` exercises native IndexedDB. Run those commands
from the [adapter package](../packages/dddart_repository_indexeddb/).

From the repository root, run the separate-tab harness and public Git consumer:

```sh
dart packages/dddart_repository_indexeddb/tool/verify_cross_tab.dart
dart tool/validation/verify_indexeddb_git_consumer.dart <full-commit-sha>
```

The harness launches Chrome headlessly with a temporary profile and two
same-origin top-level pages. It checks competing writes, uniqueness, and
receipt replay after reopening. Its JSON output is a test artifact; keep it
with the run. The Git consumer checks the lockfile revision and runs the typed
VM and Chrome contracts outside the workspace. Use the actual commit the
application will install.

## Documentation

Follow the [documentation checks](../tool/documentation/README.md) when editing
guides, public Dartdoc, or the source of an example. See
[website development](../website/README.md) for the site build and preview.
Use Bash for repository orchestration and standard tools such as jq and
`xmllint` for structured data. Existing Dart tests and the website application
keep their existing languages.
