#!/usr/bin/env bash
# Behavioral test for warn-browser-snapshot.sh
# Verifies that warnings are sent to stderr (not stdout)

set -euo pipefail

SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/plugin/scripts/warn-browser-snapshot.sh"
PASS=0
FAIL=0

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

echo "Testing warn-browser-snapshot.sh"
echo "=================================="
echo ""

# Test 1: browser_snapshot should trigger warning to stderr
echo -n "browser_snapshot triggers warning on stderr... "
stderr_output=$( (export CLAUDE_TOOL_NAME="mcp__playwright__browser_snapshot"; bash "$SCRIPT" 2>&1 >/dev/null) || true)

if echo "$stderr_output" | grep -q "Warning: browser_snapshot"; then
  echo -e "${GREEN}✓${NC}"
  PASS=$((PASS+1))
else
  echo -e "${RED}✗${NC} (warning not found on stderr)"
  FAIL=$((FAIL+1))
fi

# Test 2: other tools should not trigger warning
echo -n "other tools don't trigger warning... "
export CLAUDE_TOOL_NAME="mcp__playwright__browser_evaluate"
output=$(bash "$SCRIPT" 2>&1 || true)

if [ -z "$output" ]; then
  echo -e "${GREEN}✓${NC}"
  PASS=$((PASS+1))
else
  echo -e "${RED}✗${NC} (unexpected output: $output)"
  FAIL=$((FAIL+1))
fi

# Test 3: stdout should be empty when warning is sent to stderr
echo -n "stdout is empty when warning on stderr... "
stdout_output=$( (export CLAUDE_TOOL_NAME="mcp__playwright__browser_snapshot"; bash "$SCRIPT" 2>/dev/null) || true)

if [ -z "$stdout_output" ]; then
  echo -e "${GREEN}✓${NC}"
  PASS=$((PASS+1))
else
  echo -e "${RED}✗${NC} (stdout not empty: $stdout_output)"
  FAIL=$((FAIL+1))
fi

echo ""
echo "=================================="
echo "PASS=$PASS FAIL=$FAIL"

if [ "$FAIL" -eq 0 ]; then
  echo -e "${GREEN}All tests passed!${NC}"
  exit 0
else
  echo -e "${RED}Some tests failed!${NC}"
  exit 1
fi
