# Scripts

This directory contains utility scripts for the DDDart project.

## Available Scripts

### `test-all.sh`

Runs all tests and checks across all packages in the workspace. This script mirrors the GitHub Actions workflow and is used by the pre-push hook.

**Usage:**
```bash
./scripts/test-all.sh
```

**Prerequisite:** a Docker-compatible runtime available as `docker`, or set `DOCKER_BIN` to a compatible CLI wrapper. On Amazon Linux EC2 hosts, the provisioning path is:

```bash
sudo dnf install -y docker
sudo systemctl enable --now docker
sudo usermod -aG docker "$USER"
# start a new login shell/group session, then verify:
docker version
./scripts/test-all.sh
```

**What it does:**
- Pulls the pinned Docker images listed in `scripts/test-images.env`
- Starts MongoDB, DynamoDB Local, and MySQL containers
- Runs the full workspace check inside the pinned Dart container
- Resolves workspace dependencies
- Runs code generation (including the `dddart_rest` dependency needed by `dddart_repository_rest`)
- Analyzes code with `dart analyze --fatal-infos`
- Checks code formatting
- Runs all tests, including integration tests

To update image versions, update `scripts/test-images.env` with digest-pinned image references. CI should invoke this script rather than duplicating service-image definitions so local and CI stay on the same container versions.

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
