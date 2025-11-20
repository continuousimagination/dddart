#!/bin/bash
# Setup git hooks for the repository
# Run this after cloning the repository

set -e

REPO_ROOT=$(git rev-parse --show-toplevel)
HOOK_SOURCE="$REPO_ROOT/scripts/git-hooks/pre-push"
HOOK_TARGET="$REPO_ROOT/.git/hooks/pre-push"

echo "🔧 Setting up git hooks..."

# Create the hook from template
cat > "$HOOK_TARGET" << 'EOF'
#!/bin/bash
# Pre-push hook to run tests before pushing to remote
# This calls the versioned test script to ensure consistency

# Get the root directory of the git repository
REPO_ROOT=$(git rev-parse --show-toplevel)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo "🔍 Running pre-push checks..."
echo ""

# Run the test script
if "$REPO_ROOT/scripts/test-all.sh"; then
  echo ""
  echo -e "${GREEN}✓ All checks passed! Proceeding with push.${NC}"
  exit 0
else
  echo ""
  echo -e "${RED}✗ Pre-push checks failed. Push aborted.${NC}"
  echo ""
  echo "To skip this hook (not recommended), use: git push --no-verify"
  exit 1
fi
EOF

# Make it executable
chmod +x "$HOOK_TARGET"

echo "✓ Pre-push hook installed at .git/hooks/pre-push"
echo ""
echo "The hook will run automatically before every push."
echo "To run checks manually: ./scripts/test-all.sh"
