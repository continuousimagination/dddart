# Contributing to dddart

This guide is the canonical workflow for changing and validating this repository.
For framework and package relationships, see
[`docs/framework-map.md`](docs/framework-map.md). Automated agents must also
follow [`AGENTS.md`](AGENTS.md).

## Prerequisites

- Dart SDK `>=3.5.0 <4.0.0`. CI currently uses Dart `3.9.4`.
- Git.
- Docker or equivalent local services only when running MongoDB, DynamoDB, or
  MySQL integration tests.

The repository does not currently have one uniform package-release workflow.
Version bumps and publishing belong to an explicit release task, not an ordinary
implementation change.

## Understand the workspace

The root [`pubspec.yaml`](pubspec.yaml) is the authoritative list of Dart
workspace members. Resolve all workspace members together from the repository
root:

```bash
dart pub get
```

Do not use `dart test` at the repository root as an all-workspace test command;
there is no root test suite. Run checks from each affected package or example.

Examples fall into two groups:

- Workspace examples are listed in the root `pubspec.yaml` and use the root
  dependency resolution.
- Standalone examples have their own `pubspec.yaml` but are not workspace
  members. Resolve and validate them from their own directories.

The root workspace defines package membership. The shared validation policy,
including runnable, illustrative, and legacy example classifications, lives in
[`tool/validation/inventory.json`](tool/validation/inventory.json). The
[framework map](docs/framework-map.md#workspace-and-examples) is the human
orientation guide rather than a second validation inventory.

## Scope a change

Before editing, identify:

- the package or example that owns the handwritten source;
- public contracts and barrel exports affected;
- generator inputs and outputs affected;
- downstream workspace members that consume the changed contract;
- focused behavioral tests that prove the change;
- external services, shared build state, or examples needed for validation.

Keep changes within that scope. Preserve unrelated working-tree changes and do
not repair unrelated examples or generated state unless they block the declared
completion gate.

For cross-package, persistence, generated-code, or REST client/server planning,
use [`skills/dddart-architect/SKILL.md`](skills/dddart-architect/SKILL.md).

## Focused development workflow

Run commands from the affected package or example unless a command says
otherwise. A typical change follows this order:

1. Resolve workspace dependencies from the root if needed.
2. Run and verify required code generation.
3. Format the changed handwritten Dart paths.
4. Run the narrowest behavioral test that proves the change.
5. Analyze and test the affected package.
6. Validate affected downstream packages and examples.
7. Run the appropriate broad regression gate.

For example:

```bash
cd packages/<package>

# When this consumer owns annotated source or generated parts:
dart run build_runner build --delete-conflicting-outputs

dart format <changed-handwritten-paths>
dart test test/<focused_test>.dart
dart analyze --fatal-infos
dart format --output=none --set-exit-if-changed .
dart test
```

Use the package's existing `analysis_options.yaml` and `dart_test.yaml`. Several
database packages intentionally serialize tests or extend timeouts.

## Code generation

Run generation from the consumer package or example that owns the annotated
handwritten library and its `part` directive:

```bash
dart run build_runner build --delete-conflicting-outputs
```

Current serializer, JWT, and repository generators generally emit cached
`*.g.part` fragments. SourceGen combines all contributions for one input library
into a single `source_name.g.dart`, referenced by:

```dart
part 'source_name.g.dart';
```

Do not add separate serializer and backend-repository part directives unless the
selected generator explicitly emits standalone libraries. See the
[generator table](docs/framework-map.md#generated-code-topology) for current
builder identifiers and the distributed-event registry exception.

Generated `*.g.dart` and `*.freezed.dart` files, `.dart_tool`, `build/`, and
`pubspec.lock` are normally ignored by Git. The tracked
`packages/dddart_rest/lib/src/standard_claims.g.dart` is retained for package
runtime use but remains generator-owned. Therefore:

- never hand-edit generated output or `.dart_tool/build`;
- do not treat locally present ignored output as authoritative;
- give generation a single owner or isolate build state;
- verify that the expected output exists and matches the owning library's `part`
  directive;
- analyze or test the owning library so the combined output is compiled;
- do not accept a successful command exit if a required output is absent.

A generator change needs both:

- generator-focused tests, such as existing `build_test` coverage; and
- a generated consumer fixture that imports or compiles the owning library and
  proves the relevant behavior.

## Validate packages and examples

### Focused and package checks

Prefer a narrow worker-local proof first, followed by package checks:

```bash
dart test test/<focused_test>.dart
dart analyze --fatal-infos
dart format --output=none --set-exit-if-changed .
dart test
```

After changing a shared public type, serializer contract, generator, repository
contract, or REST contract, run the affected downstream workspace members too.

### Examples

Package analysis is not proof that nested examples compile; examples are separate
packages and some package analysis configurations exclude them. For every
affected example:

1. Resolve dependencies from the root if it is a workspace member, or locally if
   it is standalone.
2. Run generation if the example owns generated source.
3. Run `dart analyze` in the example.
4. Run its tests when a `test/` directory exists.
5. Smoke-test a relevant runnable entry point when it is safe and meaningful.

### External-service tests

The local convenience gate excludes tests tagged `requires-mongo`,
`requires-dynamodb`, and `requires-mysql`. To run package tests without those
services:

```bash
dart test \
  --exclude-tags=requires-mongo \
  --exclude-tags=requires-dynamodb \
  --exclude-tags=requires-mysql
```

CI uses these service endpoints:

| Service | Endpoint/configuration | Test tag |
|---|---|---|
| MongoDB | `localhost:27017` | `requires-mongo` |
| DynamoDB Local | `localhost:8000` | `requires-dynamodb` |
| MySQL 8 | `localhost:3307`, database `test_db`, user `root`, password `test_password` | `requires-mysql` |
| SQLite | Embedded; no external service | None |

CI-equivalent local containers can be started with:

```bash
docker run --rm -d -p 27017:27017 mongo:latest
docker run --rm -d -p 8000:8000 amazon/dynamodb-local:latest
docker run --rm -d -p 3307:3306 \
  -e MYSQL_ROOT_PASSWORD=test_password \
  -e MYSQL_DATABASE=test_db \
  mysql:8.0
```

MySQL settings may be overridden with `MYSQL_HOST`, `MYSQL_PORT`, `MYSQL_USER`,
`MYSQL_PASSWORD`, and `MYSQL_DATABASE`. If service-backed tests are not run, state
that explicitly in the change handoff.

## Broad checks

Run the local convenience gate from the repository root:

```bash
./scripts/test-all.sh
```

The optional pre-push hook installs that command as a Git hook:

```bash
./scripts/setup-hooks.sh
```

`scripts/test-all.sh` first validates the shared policy, then runs
`dart tool/validation/validate.dart all --mode=local`. The root workspace and
discovered examples are checked against
[`tool/validation/inventory.json`](tool/validation/inventory.json), which owns
package generation prerequisites, expected outputs, isolated-consumer closure,
and each example's runnable, illustrative, or legacy action. CI derives its
package and example matrices from that same inventory.

The shared inventory currently covers all 15 framework packages and 13 examples.
Generation failures are fatal. Local mode intentionally excludes MongoDB,
DynamoDB, and MySQL service-backed tests and compile-checks examples that require
those services; CI supplies the service lanes. Report any service-backed checks
that were not run locally.

## Public API, documentation, and release notes

For an intentional public API change:

- export new public types from the affected package barrel;
- add behavioral tests at the public contract;
- inspect and validate downstream workspace consumers;
- update affected package documentation and examples;
- update the package changelog when that package maintains one;
- provide migration guidance for a breaking contract or generated-code shape
  change.

Do not bundle a version bump or publication into an ordinary change unless the
task explicitly includes release work.

## Before handing off

Report:

- changed packages, examples, and public contracts;
- focused, package, downstream, generation, and broad checks run;
- generated or shared state prepared;
- external-service tests not run;
- documentation/source conflicts or framework ambiguities still unresolved.
