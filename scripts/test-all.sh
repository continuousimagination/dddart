#!/bin/bash
# Script to run all tests locally (mirrors GitHub Actions workflow)
# Usage: ./scripts/test-all.sh
#
# This script is also called by the git pre-push hook

set -e  # Exit on first error

echo "🔍 Running all checks..."
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Track overall status
FAILED=0

# List of packages to test
PACKAGES=(
  "dddart"
  "dddart_serialization"
  "dddart_json"
  "dddart_rest"
  "dddart_config"
  "dddart_repository_mongodb"
  "dddart_repository_dynamodb"
  "dddart_webhooks"
  "dddart_webhooks_slack"
)

# Get workspace dependencies first
echo "📦 Getting workspace dependencies..."
if ! dart pub get; then
  echo -e "${RED}✗ Failed to get dependencies${NC}"
  exit 1
fi
echo -e "${GREEN}✓ Dependencies resolved${NC}"
echo ""

# Function to run checks for a package
check_package() {
  local pkg=$1
  local pkg_path="packages/$pkg"
  
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "📦 Testing: $pkg"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  
  cd "$pkg_path"
  
  # Run code generation if needed
  if grep -q "build_runner" pubspec.yaml 2>/dev/null; then
    echo "  🔨 Running code generation..."
    if ! dart run build_runner build --delete-conflicting-outputs > /dev/null 2>&1; then
      echo -e "  ${YELLOW}⚠ Code generation had warnings (continuing)${NC}"
    fi
  fi
  
  # Analyze code
  echo "  🔍 Analyzing code..."
  if ! dart analyze --fatal-infos; then
    echo -e "  ${RED}✗ Analysis failed${NC}"
    cd - > /dev/null
    return 1
  fi
  echo -e "  ${GREEN}✓ Analysis passed${NC}"
  
  # Check formatting
  echo "  📝 Checking formatting..."
  if ! dart format --output=none --set-exit-if-changed . 2>/dev/null; then
    echo -e "  ${RED}✗ Formatting check failed${NC}"
    echo -e "  ${YELLOW}  Run 'dart format .' to fix${NC}"
    cd - > /dev/null
    return 1
  fi
  echo -e "  ${GREEN}✓ Formatting check passed${NC}"
  
  # Run tests (excluding MongoDB integration tests)
  # Note: MongoDB integration tests run in CI with a MongoDB service container
  echo "  🧪 Running tests..."
  if ! dart test --exclude-tags=requires-mongo; then
    echo -e "  ${RED}✗ Tests failed${NC}"
    cd - > /dev/null
    return 1
  fi
  echo -e "  ${GREEN}✓ Tests passed${NC}"
  
  cd - > /dev/null
  echo ""
  return 0
}

# Run checks for all packages
for pkg in "${PACKAGES[@]}"; do
  if ! check_package "$pkg"; then
    FAILED=1
    echo -e "${RED}✗ $pkg failed checks${NC}"
    echo ""
  fi
done

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ $FAILED -eq 0 ]; then
  echo -e "${GREEN}✓ All checks passed!${NC}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  exit 0
else
  echo -e "${RED}✗ Some checks failed.${NC}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "Fix the issues above and try again."
  exit 1
fi
