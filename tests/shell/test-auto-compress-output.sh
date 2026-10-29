#!/usr/bin/env bash
# Behavioral test for auto-compress-output.sh
# Verifies the documented opt-out toggle stops the hook before it runs anything

set -euo pipefail

SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/plugin/scripts/auto-compress-output.sh"
PASS=0
FAIL=0

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

echo "Testing auto-compress-output.sh"
echo "=================================="
echo ""

# Run from an empty directory so a failing (old) script cannot run a real git log here
cd "$(mktemp -d)"
MARKER="$(mktemp -u)"
# A high-output command (matches ^git log) that would leave a marker file if executed
INPUT="{\"tool_input\":{\"command\":\"git log; touch $MARKER\"}}"

# Test 1: opt-out exits 0 without running the command
echo -n "LEAN_FLOW_AUTO_COMPRESS_OUTPUT_DISABLED=true skips the hook... "
output=$(printf '%s' "$INPUT" | LEAN_FLOW_AUTO_COMPRESS_OUTPUT_DISABLED=true bash "$SCRIPT" 2>&1) && rc=0 || rc=$?

if [ "$rc" -eq 0 ] && [ -z "$output" ] && [ ! -e "$MARKER" ]; then
  echo -e "${GREEN}✓${NC}"
  PASS=$((PASS+1))
else
  echo -e "${RED}✗${NC} (command ran or output produced: $output)"
  FAIL=$((FAIL+1))
fi
rm -f "$MARKER"

# Test 2: summaries use a Claude 5.5 model
echo -n "summary model is claude-haiku-5-5... "
if grep -q 'HAIKU_MODEL="claude-haiku-5-5"' "$SCRIPT"; then
  echo -e "${GREEN}✓${NC}"
  PASS=$((PASS+1))
else
  echo -e "${RED}✗${NC} (unexpected model)"
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
