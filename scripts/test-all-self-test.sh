#!/usr/bin/env bash
# Regression tests for scripts/test-all.sh host-wrapper behavior.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

FAKE_DOCKER="$TMP_DIR/docker"
FAKE_DOCKER_LOG="$TMP_DIR/docker.log"

cat > "$FAKE_DOCKER" <<'FAKE_DOCKER_EOF'
#!/usr/bin/env bash
set -euo pipefail

: "${FAKE_DOCKER_LOG:?FAKE_DOCKER_LOG must be set}"
cmd="${1:-}"
shift || true

case "$cmd" in
  pull)
    echo "pull $*" >> "$FAKE_DOCKER_LOG"
    exit 0
    ;;
  image)
    if [ "${1:-}" = "inspect" ]; then
      shift
      echo "image inspect $*" >> "$FAKE_DOCKER_LOG"
      exit 0
    fi
    ;;
  rm)
    echo "rm $*" >> "$FAKE_DOCKER_LOG"
    exit 0
    ;;
  run)
    echo "run $*" >> "$FAKE_DOCKER_LOG"
    if [[ " $* " == *" --name dddart-test-dynamodb "* ]]; then
      exit 42
    fi
    echo "fake-container-id"
    exit 0
    ;;
  inspect|logs)
    echo "$cmd $*" >> "$FAKE_DOCKER_LOG"
    exit 0
    ;;
esac

echo "unexpected docker command: $cmd $*" >> "$FAKE_DOCKER_LOG"
exit 99
FAKE_DOCKER_EOF
chmod +x "$FAKE_DOCKER"

set +e
DOCKER_BIN="$FAKE_DOCKER" FAKE_DOCKER_LOG="$FAKE_DOCKER_LOG" \
  "$REPO_ROOT/scripts/test-all.sh" > "$TMP_DIR/test-all.out" 2>&1
status=$?
set -e

if [ "$status" -ne 42 ]; then
  echo "Expected fake DynamoDB startup failure to exit 42, got $status"
  cat "$TMP_DIR/test-all.out"
  cat "$FAKE_DOCKER_LOG"
  exit 1
fi

rm_count="$(grep -c '^rm -f dddart-test-mysql dddart-test-dynamodb dddart-test-mongodb$' "$FAKE_DOCKER_LOG" || true)"
if [ "$rm_count" -ne 2 ]; then
  echo "Expected cleanup to run before startup and again from the EXIT trap; saw $rm_count cleanup calls"
  cat "$FAKE_DOCKER_LOG"
  exit 1
fi

if ! grep -q '^pull ' "$FAKE_DOCKER_LOG"; then
  echo "Expected host wrapper to pull pinned images before startup"
  cat "$FAKE_DOCKER_LOG"
  exit 1
fi

echo "✓ test-all host-wrapper cleanup regression passed"
