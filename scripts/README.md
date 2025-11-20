# Scripts

This directory contains utility scripts for the DDDart project.

## Available Scripts

### `test-all.sh`

Runs all tests and checks across all packages in the workspace. This script mirrors the GitHub Actions workflow and is used by the pre-push hook.

**Usage:**
```bash
./scripts/test-all.sh
```

**What it does:**
- Resolves workspace dependencies
- Runs code generation (where needed)
- Analyzes code with `dart analyze --fatal-infos`
- Checks code formatting
- Runs tests (excluding `requires-mongo` tagged tests)

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
