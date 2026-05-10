#!/usr/bin/env bash
# Behavioral test for require-plan-for-medium-heavy.sh
# Verifies opt-in gate and plan enforcement for medium/heavy tasks

set -euo pipefail

SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/plugin/scripts/require-plan-for-medium-heavy.sh"
TMPDIR="${TMPDIR:-/tmp}"
STATE_DIR="${TMPDIR}/test-state-$(date +%s%N | tail -c 6)"
CLASSIFICATION_FILE="${STATE_DIR}/current-task.classification"
PLAN_MARKER="${STATE_DIR}/current-task.plan"

PASS=0
FAIL=0

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

cleanup() {
  rm -rf "$STATE_DIR"
}

trap cleanup EXIT

mkdir -p "$STATE_DIR"

check() {
  local name="$1"
  local enabled="$2"
  local classification="$3"
  local plan_exists="$4"
  local expected_exit="$5"

  rm -f "$CLASSIFICATION_FILE" "$PLAN_MARKER"

  if [ -n "$classification" ]; then
    echo "$classification" > "$CLASSIFICATION_FILE"
  fi

  if [ "$plan_exists" = "true" ]; then
    echo "/path/to/plan" > "$PLAN_MARKER"
  fi

  local actual_exit=0
  CLAUDE_STATE_DIR="$STATE_DIR" \
  LEAN_FLOW_REQUIRE_PLAN_ENABLED="$enabled" \
  bash "$SCRIPT" >/dev/null 2>&1 || actual_exit=$?

  if [ "$actual_exit" = "$expected_exit" ]; then
    echo -e "${GREEN}✓${NC} $name"
    PASS=$((PASS+1))
  else
    echo -e "${RED}✗${NC} $name (expected=$expected_exit actual=$actual_exit)"
    FAIL=$((FAIL+1))
  fi
}

echo "Testing require-plan-for-medium-heavy.sh"
echo "=========================================="
echo ""

echo "Opt-in disabled (default):"
check "disabled: medium task without plan -> allow" \
  "false" "medium" "false" \
  0

check "disabled: heavy task without plan -> allow" \
  "false" "heavy" "false" \
  0

echo ""
echo "Opt-in enabled (LEAN_FLOW_REQUIRE_PLAN_ENABLED=true):"

check "enabled: no classification -> allow" \
  "true" "" "false" \
  0

check "enabled: simple task -> allow" \
  "true" "simple" "false" \
  0

check "enabled: medium with plan -> allow" \
  "true" "medium" "true" \
  0

check "enabled: medium without plan -> block" \
  "true" "medium" "false" \
  2

check "enabled: heavy with plan -> allow" \
  "true" "heavy" "true" \
  0

check "enabled: heavy without plan -> block" \
  "true" "heavy" "false" \
  2

echo ""
echo "=========================================="
echo "PASS=$PASS FAIL=$FAIL"

if [ "$FAIL" -eq 0 ]; then
  echo -e "${GREEN}All tests passed!${NC}"
  exit 0
else
  echo -e "${RED}Some tests failed!${NC}"
  exit 1
fi
