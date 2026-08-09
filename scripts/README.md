# Scripts

This directory contains utility scripts for the DDDart project.

## Available Scripts

### `test-all.sh`

Runs the workspace-derived validation policy and is used by the pre-push hook.
The policy is shared with CI through
[`tool/validation/inventory.json`](../tool/validation/inventory.json); package
lists must not be duplicated in this script or in the workflow.

**Usage:**
```bash
./scripts/test-all.sh
```

**What it does:**

- verifies that every root workspace member is either an intended public package
  or has a justified exemption;
- analyzes, format-checks, and self-tests the shared validation tooling;
- isolates nested Git and Pub subprocesses from repository-local environment
  variables exported by hooks, so fixture repositories cannot affect the
  caller's index or configuration;
- checks each public package's frozen local dependency closure;
- verifies each package's explicit `generation: required|none` policy against
  its manifest and generated-part topology, then runs required generation in
  inventory order;
- rejects stale, duplicate, or unclassified external-service test tags by
  comparing the inventory with `dart_test.yaml` and test metadata;
- analyzes, format-checks, and tests all 15 intended public packages;
- excludes MongoDB, DynamoDB, and MySQL service tests locally according to the
  explicit policy (CI runs each adapter only with its package-scoped service);
- runs `dart pub publish --dry-run` for packages whose metadata does not set
  `publish_to: none`;
- creates a temporary consumer for every intended public package by extracting
  Pub's own archive file set (including nested `.pubignore` semantics), confines
  local path overrides to that fixture, and proves its resolved dddart
  dependency graph contains exactly the smallest allowed closure;
- discovers every `packages/*/example` directory and matches it against the
  shared runnable/illustrative/legacy inventory;
- resolves each example from its declared workspace or standalone context,
  proves its smallest local dependency closure, regenerates declared outputs
  from clean state, analyzes its source with a local analysis configuration,
  compiles every supported entrypoint, and runs finite local entrypoints;
- compiles external-service examples locally. CI derives example matrices from
  the same inventory and runs the MongoDB, DynamoDB, and MySQL lanes with their
  provisioned services. Slack entrypoints remain compile-only because they need
  real credentials and inbound requests.

### Validation tool

The root validator can also run focused lanes:

```bash
# Inventory drift, closure policy, and exemption checks
dart tool/validation/validate.dart check

# Full or service-scoped CI matrices derived from that inventory
dart tool/validation/validate.dart matrix
dart tool/validation/validate.dart matrix --service-kind=mysql

# Full or service-scoped example matrices from the same inventory
dart tool/validation/validate.dart example-matrix
dart tool/validation/validate.dart example-matrix --service-kind=dynamodb

# One integrated package lane
dart tool/validation/validate.dart package dddart_json --mode=local

# One outside-workspace minimal consumer
dart tool/validation/validate.dart consumer dddart_repository_mysql

# One example or all examples; local mode does not assume external services
dart tool/validation/validate.dart example dddart_json_example --mode=local
dart tool/validation/validate.dart examples --mode=local

# Fast policy and dependency-boundary regression tests
dart tool/validation/self_test.dart
```

### `setup-hooks.sh`

Installs git hooks for the repository. Run this after cloning the repository.

**Usage:**
```bash
./scripts/setup-hooks.sh
```

**What it does:**
- Installs the pre-push hook at `.git/hooks/pre-push`
- The hook automatically runs `test-all.sh` before every push
- Prevents pushing code that would fail CI

## Git Hooks

### Pre-Push Hook

The pre-push hook runs automatically before every `git push` to catch issues before they reach CI.

**To skip the hook (not recommended):**
```bash
git push --no-verify
```

**Note:** The hook itself is not committed to git (it lives in `.git/hooks/`), but the logic is in the versioned `test-all.sh` script. This ensures the hook behavior is consistent across all developers and can be updated through git.
