#!/bin/bash
# Run the repository's workspace-derived local validation policy.
#
# The authoritative package inventory, dependency boundaries, and justified
# external-service exclusions live in tool/validation/inventory.json. CI calls
# the same validator in ci mode, where the service-backed tests are enabled.

set -euo pipefail

DDDART_VALIDATION_MODE=local
case "${1:-}" in
  "") ;;
  --with-services) DDDART_VALIDATION_MODE=ci ;;
  *) echo "Usage: ./scripts/test-all.sh [--with-services]" >&2; exit 2 ;;
esac
if [ "$#" -gt 1 ]; then
  echo "Usage: ./scripts/test-all.sh [--with-services]" >&2
  exit 2
fi

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Git hooks export repository-local variables such as GIT_DIR. Clear them
# before validation creates fixture repositories or invokes Pub so each child
# discovers Git state from its own working directory.
while IFS= read -r git_environment_variable; do
  unset "$git_environment_variable"
done < <(git rev-parse --local-env-vars)

ORIGINAL_ULIMIT=$(ulimit -n)
REQUIRED_ULIMIT=4096
ULIMIT_ADJUSTED=0

if [ "$ORIGINAL_ULIMIT" -lt "$REQUIRED_ULIMIT" ]; then
  if ulimit -n "$REQUIRED_ULIMIT" 2>/dev/null; then
    ULIMIT_ADJUSTED=1
  else
    echo "Warning: could not raise the file descriptor limit to $REQUIRED_ULIMIT." >&2
  fi
fi

restore_ulimit() {
  if [ "$ULIMIT_ADJUSTED" -eq 1 ]; then
    ulimit -n "$ORIGINAL_ULIMIT" 2>/dev/null || true
  fi
}

trap restore_ulimit EXIT INT TERM

cd "$REPOSITORY_ROOT"

dart analyze --fatal-infos tool/validation
dart format --output=none --set-exit-if-changed tool/validation
dart tool/validation/self_test.dart
# Keep the independent-page browser check aligned with the adapter CI lane.
dart packages/dddart_repository_indexeddb/tool/verify_cross_tab.dart
dart tool/validation/validate.dart all --mode="$DDDART_VALIDATION_MODE"
