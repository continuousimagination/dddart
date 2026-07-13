#!/usr/bin/env bash
# Run the full workspace test matrix inside Docker.
#
# Usage: ./scripts/test-all.sh
#
# Host mode:
#   1. Starts MongoDB, DynamoDB Local, and MySQL containers using the same
#      images/configuration as GitHub Actions.
#   2. Runs this script again inside a Dart 3.9.4 container on the host
#      network so localhost-based tests can reach the services.
#
# Container mode (TEST_ALL_IN_DOCKER=1):
#   Runs the actual workspace checks directly.
#
# This script is also called by the git pre-push hook.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOCKER_BIN="${DOCKER_BIN:-docker}"
DART_IMAGE="${TEST_ALL_DART_IMAGE:-dart:3.9.4}"
MONGO_IMAGE="${TEST_ALL_MONGODB_IMAGE:-mongo:latest}"
DYNAMODB_IMAGE="${TEST_ALL_DYNAMODB_IMAGE:-amazon/dynamodb-local:latest}"
MYSQL_IMAGE="${TEST_ALL_MYSQL_IMAGE:-mysql:8.0}"
MONGO_CONTAINER="${TEST_ALL_MONGODB_CONTAINER:-dddart-test-mongodb}"
DYNAMODB_CONTAINER="${TEST_ALL_DYNAMODB_CONTAINER:-dddart-test-dynamodb}"
MYSQL_CONTAINER="${TEST_ALL_MYSQL_CONTAINER:-dddart-test-mysql}"
IN_DOCKER="${TEST_ALL_IN_DOCKER:-0}"

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
  "dddart_repository_rest"
  "dddart_repository_sql"
  "dddart_repository_sqlite"
  "dddart_repository_mysql"
  "dddart_webhooks"
  "dddart_webhooks_slack"
  "dddart_events_distributed"
)

log_section() {
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "$1"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

require_docker() {
  if ! command -v "$DOCKER_BIN" >/dev/null 2>&1; then
    echo -e "${RED}✗ Docker is required to run ./scripts/test-all.sh${NC}"
    echo "  Set DOCKER_BIN to a compatible wrapper or install Docker first."
    exit 1
  fi
}

restore_ulimit() {
  if [ "${ULIMIT_ADJUSTED:-0}" -eq 1 ]; then
    ulimit -n "$ORIGINAL_ULIMIT" 2>/dev/null || true
  fi
}

wait_for_tcp_port() {
  local host=$1
  local port=$2
  local label=$3
  local attempts=${4:-60}

  for _ in $(seq 1 "$attempts"); do
    if bash -c ">/dev/tcp/$host/$port" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done

  echo -e "${RED}✗ $label failed to become ready at $host:$port${NC}"
  return 1
}

wait_for_container_healthy() {
  local container=$1
  local label=$2
  local attempts=${3:-60}

  for _ in $(seq 1 "$attempts"); do
    local status
    status="$($DOCKER_BIN inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$container" 2>/dev/null || true)"
    if [ "$status" = "healthy" ]; then
      return 0
    fi
    sleep 1
  done

  echo -e "${RED}✗ $label failed to become healthy${NC}"
  $DOCKER_BIN logs "$container" || true
  return 1
}

cleanup_services() {
  $DOCKER_BIN rm -f "$MYSQL_CONTAINER" "$DYNAMODB_CONTAINER" "$MONGO_CONTAINER" >/dev/null 2>&1 || true
}

start_services() {
  cleanup_services

  echo "🐳 Starting Docker services..."

  $DOCKER_BIN run -d --name "$MONGO_CONTAINER" -p 27017:27017 \
    --health-cmd "mongosh --eval 'db.runCommand({ ping: 1 })'" \
    --health-interval 10s \
    --health-timeout 5s \
    --health-retries 5 \
    "$MONGO_IMAGE" >/dev/null

  $DOCKER_BIN run -d --name "$DYNAMODB_CONTAINER" -p 8000:8000 "$DYNAMODB_IMAGE" >/dev/null

  $DOCKER_BIN run -d --name "$MYSQL_CONTAINER" -p 3307:3306 \
    -e MYSQL_ROOT_PASSWORD=test_password \
    -e MYSQL_DATABASE=test_db \
    --health-cmd "mysqladmin ping -h localhost -ptest_password" \
    --health-interval 10s \
    --health-timeout 5s \
    --health-retries 10 \
    --health-start-period 30s \
    "$MYSQL_IMAGE" >/dev/null

  wait_for_container_healthy "$MONGO_CONTAINER" "MongoDB"
  wait_for_tcp_port 127.0.0.1 8000 "DynamoDB Local"
  wait_for_container_healthy "$MYSQL_CONTAINER" "MySQL"
}

run_package_checks() {
  local pkg=$1
  local pkg_path="$REPO_ROOT/packages/$pkg"

  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "📦 Testing: $pkg"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  (
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
      return 1
    fi
    echo -e "  ${GREEN}✓ Analysis passed${NC}"

    # Check formatting
    echo "  📝 Checking formatting..."
    if ! dart format --output=none --set-exit-if-changed . 2>/dev/null; then
      echo -e "  ${RED}✗ Formatting check failed${NC}"
      echo -e "  ${YELLOW}  Run 'dart format .' to fix${NC}"
      return 1
    fi
    echo -e "  ${GREEN}✓ Formatting check passed${NC}"

    # Run tests
    echo "  🧪 Running tests..."
    if ! dart test; then
      echo -e "  ${RED}✗ Tests failed${NC}"
      return 1
    fi
    echo -e "  ${GREEN}✓ Tests passed${NC}"
  )

  echo ""
}

run_workspace_checks() {
  cd "$REPO_ROOT"

  echo "🔍 Running all checks..."
  echo ""

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

  trap restore_ulimit EXIT INT TERM

  echo "📦 Getting workspace dependencies..."
  if ! dart pub get; then
    echo -e "${RED}✗ Failed to get dependencies${NC}"
    exit 1
  fi
  echo -e "${GREEN}✓ Dependencies resolved${NC}"
  echo ""

  for pkg in "${PACKAGES[@]}"; do
    if ! run_package_checks "$pkg"; then
      FAILED=1
      echo -e "${RED}✗ $pkg failed checks${NC}"
      echo ""
    fi
  done

  log_section "Summary"
  if [ "$FAILED" -eq 0 ]; then
    echo -e "${GREEN}✓ All checks passed!${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    exit 0
  fi

  echo -e "${RED}✗ Some checks failed.${NC}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "Fix the issues above and try again."
  exit 1
}

run_host_wrapper() {
  require_docker

  start_services
  trap cleanup_services EXIT INT TERM

  echo "🐳 Running checks inside ${DART_IMAGE}..."
  echo ""

  $DOCKER_BIN run --rm \
    --network host \
    --user "$(id -u):$(id -g)" \
    -e HOME=/tmp \
    -e PUB_CACHE=/tmp/.pub-cache \
    -e TEST_ALL_IN_DOCKER=1 \
    -e MYSQL_HOST=localhost \
    -e MYSQL_PORT=3307 \
    -e MYSQL_USER=root \
    -e MYSQL_PASSWORD=test_password \
    -e MYSQL_DATABASE=test_db \
    -v "$REPO_ROOT:/workspace" \
    -w /workspace \
    "$DART_IMAGE" \
    bash /workspace/scripts/test-all.sh
}

if [ "$IN_DOCKER" = "1" ]; then
  run_workspace_checks
else
  run_host_wrapper
fi
