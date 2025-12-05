#!/bin/bash
# Script to run all tests locally (mirrors GitHub Actions workflow)
# Usage: ./scripts/test-all.sh
#
# This script is also called by the git pre-push hook
#
# Note: This script excludes tests that require external services:
# - MongoDB tests (requires-mongo tag)
# - DynamoDB tests (requires-dynamodb tag)
# - MySQL tests (requires-mysql tag) - includes collection integration tests
#
# To run MySQL collection tests locally:
#   1. Start MySQL: docker run -d -p 3307:3306 -e MYSQL_ROOT_PASSWORD=test_password -e MYSQL_DATABASE=test_db mysql:8.0
#   2. Run: cd packages/dddart_repository_mysql && dart test
#
# To run SQLite collection tests locally (no external service needed):
#   cd packages/dddart_repository_sqlite && dart test

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

# Check and adjust ulimit if needed
ORIGINAL_ULIMIT=$(ulimit -n)
REQUIRED_ULIMIT=4096
ULIMIT_ADJUSTED=0

if [ "$ORIGINAL_ULIMIT" -lt "$REQUIRED_ULIMIT" ]; then
  echo -e "${YELLOW}⚠ File descriptor limit is low ($ORIGINAL_ULIMIT)${NC}"
  echo "  Temporarily increasing to $REQUIRED_ULIMIT for tests..."
  if ulimit -n "$REQUIRED_ULIMIT" 2>/dev/null; then
    ULIMIT_ADJUSTED=1
    echo -e "${GREEN}✓ Limit increased to $(ulimit -n)${NC}"
  else
    echo -e "${YELLOW}⚠ Could not increase limit (may need sudo or system config)${NC}"
    echo "  Tests may fail. Consider running: ulimit -n $REQUIRED_ULIMIT"
  fi
  echo ""
fi

# Function to restore ulimit on exit
restore_ulimit() {
  if [ "$ULIMIT_ADJUSTED" -eq 1 ]; then
    ulimit -n "$ORIGINAL_ULIMIT" 2>/dev/null || true
  fi
}

# Set trap to restore ulimit on exit (success, error, or interrupt)
trap restore_ulimit EXIT INT TERM

# List of packages to test
PACKAGES=(
  "dddart"
  "dddart_serialization"
  "dddart_json"
  "dddart_rest"
  "dddart_config"
  "dddart_repository_mongodb"
  "dddart_repository_dynamodb"
  "dddart_repository_rest"
  "dddart_repository_sql"
  "dddart_repository_sqlite"
  "dddart_repository_mysql"
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
  
  # Run tests (excluding MongoDB, DynamoDB, and MySQL integration tests)
  # Note: Integration tests (including collection tests) run in CI with service containers
  echo "  🧪 Running tests..."
  if ! dart test --exclude-tags=requires-mongo --exclude-tags=requires-dynamodb --exclude-tags=requires-mysql; then
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
