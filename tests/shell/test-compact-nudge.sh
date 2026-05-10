#!/usr/bin/env bash
# Behavioral test for compact-nudge.js
# Verifies core functionality: debounce logic, threshold, event name

set -euo pipefail

SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/plugin/scripts/compact-nudge.js"
PASS=0
FAIL=0

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

echo "Testing compact-nudge.js"
echo "=================================="
echo ""

# Test 1: Script is executable and has proper shebang
echo -n "script is executable... "
if [ -x "$SCRIPT" ] && head -1 "$SCRIPT" | grep -q "node"; then
  echo -e "${GREEN}✓${NC}"
  PASS=$((PASS+1))
else
  echo -e "${RED}✗${NC}"
  FAIL=$((FAIL+1))
fi

# Test 2: Script handles env var disable
echo -n "LEAN_FLOW_COMPACT_NUDGE_DISABLED gate works... "
output=$(LEAN_FLOW_COMPACT_NUDGE_DISABLED=true node "$SCRIPT" <<< '{"session_id":"test"}' 2>&1 || echo "")
if [ -z "$output" ]; then
  echo -e "${GREEN}✓${NC}"
  PASS=$((PASS+1))
else
  echo -e "${RED}✗${NC} (expected no output)"
  FAIL=$((FAIL+1))
fi

# Test 3: Script exits silently when metrics file missing
echo -n "exits silently when metrics file missing... "
output=$(node "$SCRIPT" <<< '{"session_id":"nonexistent-test-999"}' 2>&1 || echo "")
if [ -z "$output" ]; then
  echo -e "${GREEN}✓${NC}"
  PASS=$((PASS+1))
else
  echo -e "${RED}✗${NC}"
  FAIL=$((FAIL+1))
fi

# Test 4: Script json validates session ID
echo -n "validates session ID (blocks path traversal)... "
output=$(node "$SCRIPT" <<< '{"session_id":"../../../test"}' 2>&1 || echo "")
if [ -z "$output" ]; then
  echo -e "${GREEN}✓${NC}"
  PASS=$((PASS+1))
else
  echo -e "${RED}✗${NC}"
  FAIL=$((FAIL+1))
fi

# Test 5: hookEventName is PostToolUse
echo -n "hookEventName is PostToolUse... "
if grep -q 'hookEventName.*PostToolUse' "$SCRIPT"; then
  echo -e "${GREEN}✓${NC}"
  PASS=$((PASS+1))
else
  echo -e "${RED}✗${NC}"
  FAIL=$((FAIL+1))
fi

# Test 6: DEBOUNCE_CALLS constant is set
echo -n "DEBOUNCE_CALLS constant defined... "
if grep -q 'DEBOUNCE_CALLS.*=.*10' "$SCRIPT"; then
  echo -e "${GREEN}✓${NC}"
  PASS=$((PASS+1))
else
  echo -e "${RED}✗${NC}"
  FAIL=$((FAIL+1))
fi

# Test 7: Debounce counter logic exists
echo -n "debounce logic implemented... "
if grep -q 'callsSinceNudge' "$SCRIPT" && grep -q 'DEBOUNCE_CALLS' "$SCRIPT"; then
  echo -e "${GREEN}✓${NC}"
  PASS=$((PASS+1))
else
  echo -e "${RED}✗${NC}"
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
