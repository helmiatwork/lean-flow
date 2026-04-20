#!/usr/bin/env bash
# Test suite for plugin/scripts/track-test-failures.sh
# Uses lightweight inline test framework

set -e

PASS=0
FAIL=0

assert_eq() {
  if [ "$1" = "$2" ]; then
    echo "✓ $3"
    PASS=$((PASS+1))
  else
    echo "✗ $3 (got '$1', want '$2')"
    FAIL=$((FAIL+1))
  fi
}

assert_contains() {
  if echo "$1" | grep -q "$2"; then
    echo "✓ $3"
    PASS=$((PASS+1))
  else
    echo "✗ $3 (output: '$1')"
    FAIL=$((FAIL+1))
  fi
}

assert_not_contains() {
  if ! echo "$1" | grep -q "$2"; then
    echo "✓ $3"
    PASS=$((PASS+1))
  else
    echo "✗ $3 (output contains unexpected: '$2')"
    FAIL=$((FAIL+1))
  fi
}

# Helper to run track-test-failures with test counter file
run_tracker() {
  local counter_file="$1"
  local json_input="$2"
  (
    export COUNTER_FILE="$counter_file"
    export NUDGE_FILE="/tmp/lean-flow-pattern-nudge-test-$$"
    # Create a temporary version of the script with our counter file
    sed "s|COUNTER_FILE=\"/tmp/lean-flow-test-failures\"|COUNTER_FILE=\"$counter_file\"|g; s|NUDGE_FILE=\"/tmp/lean-flow-pattern-nudge\"|NUDGE_FILE=\"$NUDGE_FILE\"|g" \
      /Users/theresiaputri/repo/lean-flow/plugin/scripts/track-test-failures.sh > /tmp/track-test-failures-$$.sh
    echo "$json_input" | bash /tmp/track-test-failures-$$.sh 2>/dev/null
    rm -f /tmp/track-test-failures-$$.sh "$NUDGE_FILE"
  )
}

# Cleanup function
cleanup() {
  rm -f /tmp/lean-flow-test-failures /tmp/lean-flow-test-failures-* /tmp/track-test-failures-*
}

echo "=== Test 1: First failure detection (no output on count=1) ==="
cleanup
counter_file=$(mktemp)
output=$(run_tracker "$counter_file" '{"tool_response":{"stdout":"FAILED 1 test"}}')
count=$(cat "$counter_file" 2>/dev/null || echo "0")
rm -f "$counter_file"

assert_eq "$count" "1" "counter incremented to 1 on first failure"
assert_eq "$output" "" "no output on first failure (count=1)"

echo ""
echo "=== Test 2: Second failure detection (output warning) ==="
cleanup
counter_file=$(mktemp)
echo "1" > "$counter_file"  # Pre-seed to 1
output=$(run_tracker "$counter_file" '{"tool_response":{"stdout":"AssertionError in test_foo.py"}}')
count=$(cat "$counter_file" 2>/dev/null || echo "0")
rm -f "$counter_file"

assert_eq "$count" "2" "counter incremented to 2 on second failure"
assert_contains "$output" "failure #2 of 3" "output warns of 2nd failure"
assert_contains "$output" "One more failure triggers Oracle escalation" "output mentions escalation threshold"

echo ""
echo "=== Test 3: Third failure detection (escalation and reset) ==="
cleanup
counter_file=$(mktemp)
echo "2" > "$counter_file"  # Pre-seed to 2
output=$(run_tracker "$counter_file" '{"tool_response":{"stdout":"tests failed"}}')
count=$(cat "$counter_file" 2>/dev/null || echo "0")
rm -f "$counter_file"

assert_eq "$count" "0" "counter reset to 0 after escalation"
assert_contains "$output" "ESCALATE TO ORACLE" "output escalates to oracle on 3rd failure"
assert_contains "$output" "failure #3" "output shows failure count #3"

echo ""
echo "=== Test 4: Success resets counter (count=0) ==="
cleanup
counter_file=$(mktemp)
echo "2" > "$counter_file"  # Pre-seed to 2
output=$(run_tracker "$counter_file" '{"tool_response":{"stdout":"tests passed"}}')
count=$(cat "$counter_file" 2>/dev/null || echo "0")
rm -f "$counter_file"

assert_eq "$count" "0" "counter reset to 0 on success"
assert_not_contains "$output" "failure" "no failure warning on success"

echo ""
echo "=== Test 5: Success with 'passed' keyword ==="
cleanup
counter_file=$(mktemp)
echo "1" > "$counter_file"
output=$(run_tracker "$counter_file" '{"tool_response":{"stdout":"All tests passed"}}')
count=$(cat "$counter_file" 2>/dev/null || echo "0")
rm -f "$counter_file"

assert_eq "$count" "0" "counter reset on success"

echo ""
echo "=== Test 6: Success with '✓' symbol ==="
cleanup
counter_file=$(mktemp)
echo "1" > "$counter_file"
output=$(run_tracker "$counter_file" '{"tool_response":{"stdout":"✓ test_one ✓ test_two"}}')
count=$(cat "$counter_file" 2>/dev/null || echo "0")
rm -f "$counter_file"

assert_eq "$count" "0" "counter reset on ✓ symbol"

echo ""
echo "=== Test 7: Success with '0 failures' ==="
cleanup
counter_file=$(mktemp)
echo "1" > "$counter_file"
output=$(run_tracker "$counter_file" '{"tool_response":{"stdout":"5 tests run, 0 failures"}}')
count=$(cat "$counter_file" 2>/dev/null || echo "0")
rm -f "$counter_file"

assert_eq "$count" "0" "counter reset on 0 failures pattern"

echo ""
echo "=== Test 8: Failure with 'FAIL' keyword ==="
cleanup
counter_file=$(mktemp)
output=$(run_tracker "$counter_file" '{"tool_response":{"stdout":"FAIL: expected true but got false"}}')
count=$(cat "$counter_file" 2>/dev/null || echo "0")
rm -f "$counter_file"

assert_eq "$count" "1" "failure detected with FAIL keyword"

echo ""
echo "=== Test 9: Failure with 'FAILED' keyword and digit ==="
cleanup
counter_file=$(mktemp)
output=$(run_tracker "$counter_file" '{"tool_response":{"stdout":"FAILED 1 test"}}')
count=$(cat "$counter_file" 2>/dev/null || echo "0")
rm -f "$counter_file"

assert_eq "$count" "1" "failure detected with FAILED keyword and digit"

echo ""
echo "=== Test 10: Failure with 'failures:' pattern ==="
cleanup
counter_file=$(mktemp)
output=$(run_tracker "$counter_file" '{"tool_response":{"stdout":"Summary: 5 passed, failures: 2"}}')
count=$(cat "$counter_file" 2>/dev/null || echo "0")
rm -f "$counter_file"

assert_eq "$count" "1" "failure detected with 'failures:' pattern"

echo ""
echo "=== Test 11: Failure with 'errors:' pattern ==="
cleanup
counter_file=$(mktemp)
output=$(run_tracker "$counter_file" '{"tool_response":{"stdout":"Test run complete. errors: 3"}}')
count=$(cat "$counter_file" 2>/dev/null || echo "0")
rm -f "$counter_file"

assert_eq "$count" "1" "failure detected with 'errors:' pattern"

echo ""
echo "=== Test 12: Failure with 'tests failed' pattern ==="
cleanup
counter_file=$(mktemp)
output=$(run_tracker "$counter_file" '{"tool_response":{"stdout":"Some tests failed"}}')
count=$(cat "$counter_file" 2>/dev/null || echo "0")
rm -f "$counter_file"

assert_eq "$count" "1" "failure detected with 'tests failed' pattern"

echo ""
echo "=== Test 13: Failure with 'AssertionError' ==="
cleanup
counter_file=$(mktemp)
output=$(run_tracker "$counter_file" '{"tool_response":{"stdout":"AssertionError: foo != bar"}}')
count=$(cat "$counter_file" 2>/dev/null || echo "0")
rm -f "$counter_file"

assert_eq "$count" "1" "failure detected with AssertionError pattern"

echo ""
echo "=== Test 14: Failure with 'Expected but got' ==="
cleanup
counter_file=$(mktemp)
output=$(run_tracker "$counter_file" '{"tool_response":{"stdout":"Expected [1,2,3] but got [1,2]"}}')
count=$(cat "$counter_file" 2>/dev/null || echo "0")
rm -f "$counter_file"

assert_eq "$count" "1" "failure detected with 'Expected...but got' pattern"

echo ""
echo "=== Test 15: Neutral output doesn't trigger (no change) ==="
cleanup
counter_file=$(mktemp)
echo "1" > "$counter_file"
output=$(run_tracker "$counter_file" '{"tool_response":{"stdout":"Some neutral output"}}')
count=$(cat "$counter_file" 2>/dev/null || echo "0")
rm -f "$counter_file"

assert_eq "$count" "1" "counter unchanged on neutral output"
assert_eq "$output" "" "no output on neutral pattern"

echo ""
echo "=== Test 16: Case insensitive failure detection ==="
cleanup
counter_file=$(mktemp)
output=$(run_tracker "$counter_file" '{"tool_response":{"stdout":"failures: 1"}}')
count=$(cat "$counter_file" 2>/dev/null || echo "0")
rm -f "$counter_file"

assert_eq "$count" "1" "case insensitive failure detection works"

echo ""
echo "=== Test 17: Empty stdout (missing) ==="
cleanup
counter_file=/tmp/test-empty-$$
output=$(run_tracker "$counter_file" '{"tool_response":{}}')
# File should not be created since empty string triggers no action
if [ -f "$counter_file" ]; then
  count=$(cat "$counter_file")
else
  count="not_created"
fi
rm -f "$counter_file"

assert_eq "$count" "not_created" "empty stdout triggers no action, no file created"

echo ""
echo "=== Test 18: Null stdout ==="
cleanup
counter_file=/tmp/test-null-$$
output=$(run_tracker "$counter_file" '{"tool_response":{"stdout":null}}')
# File should not be created since null becomes empty string which triggers no action
if [ -f "$counter_file" ]; then
  count=$(cat "$counter_file")
else
  count="not_created"
fi
rm -f "$counter_file"

assert_eq "$count" "not_created" "null stdout triggers no action, no file created"

echo ""
echo "=== Test 19: Multiple failure patterns in one output ==="
cleanup
counter_file=$(mktemp)
output=$(run_tracker "$counter_file" '{"tool_response":{"stdout":"FAILED 3 tests: AssertionError in line 42"}}')
count=$(cat "$counter_file" 2>/dev/null || echo "0")
rm -f "$counter_file"

assert_eq "$count" "1" "multiple failure patterns detected correctly"

echo ""
echo "=== Test 20: Success pattern with digits ==="
cleanup
counter_file=$(mktemp)
echo "1" > "$counter_file"
output=$(run_tracker "$counter_file" '{"tool_response":{"stdout":"✓ tests ran"}}')
count=$(cat "$counter_file" 2>/dev/null || echo "0")
rm -f "$counter_file"

assert_eq "$count" "0" "success detected with ✓ followed by word"

echo ""
echo "================================"
echo "$PASS passed, $FAIL failed"
echo "================================"

cleanup
[ "$FAIL" -eq 0 ]
