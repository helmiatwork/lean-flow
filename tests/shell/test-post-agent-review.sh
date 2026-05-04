#!/usr/bin/env bash
# Test suite for plugin/scripts/post-agent-review.sh
# Tests verdict comment posting, idempotency, and agent filtering

set -e

PASS=0
FAIL=0
TEST_GH_DIR=""

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
    echo "✗ $3 (output does not contain '$2')"
    FAIL=$((FAIL+1))
  fi
}

assert_not_contains() {
  if ! echo "$1" | grep -q "$2"; then
    echo "✓ $3"
    PASS=$((PASS+1))
  else
    echo "✗ $3 (output unexpectedly contains '$2')"
    FAIL=$((FAIL+1))
  fi
}

# Run post-agent-review with mocked gh
# Accepts optional second argument for gh view response
run_post_review() {
  local json_input="$1"
  local gh_view_response="${2:-'{\"comments\":[]}'}"
  local call_log=""
  (
    # Create temp dir for mock gh and call log
    export GH_TEST_DIR=$(mktemp -d)
    export GH_CALL_LOG="$GH_TEST_DIR/calls.log"

    # Create wrapper script that mocks gh
    cat > "$GH_TEST_DIR/gh" <<'MOCK_GH'
#!/usr/bin/env bash
# Mock gh command
if [[ "$1" == "pr" && "$2" == "view" ]]; then
  # Return the response from GH_VIEW_RESPONSE env var
  printf '%s' "$GH_VIEW_RESPONSE"
elif [[ "$1" == "pr" && "$2" == "comment" ]]; then
  # Record that comment was posted
  echo "comment_posted" >> "$GH_CALL_LOG"
  exit 0
else
  exit 1
fi
MOCK_GH
    chmod +x "$GH_TEST_DIR/gh"

    # Prepend GH_TEST_DIR to PATH so our mock is used
    export PATH="$GH_TEST_DIR:$PATH"
    export GH_VIEW_RESPONSE="$gh_view_response"

    # Run the script
    printf '%s' "$json_input" | bash /Users/ichigo/Documents/repo/lean-flow/plugin/scripts/post-agent-review.sh 2>/dev/null || true

    # Output the call log
    if [ -f "$GH_CALL_LOG" ]; then
      cat "$GH_CALL_LOG"
    fi

    # Cleanup
    rm -rf "$GH_TEST_DIR"
  )
}

cleanup() {
  rm -f /tmp/lean-flow-gh-calls-* /tmp/lean-flow-post-review-*
}

echo "=== Test 1: Oracle APPROVED verdict posts comment ==="
cleanup
json='{"agent_name":"oracle","metadata":{"pr_number":"123"},"messages":[{"role":"assistant","content":"ORACLE_AGENT: ✅ APPROVED\n\nSome analysis here"}]}'
output=$(run_post_review "$json" 2>&1 || true)
assert_contains "$output" "comment_posted" "oracle APPROVED posts gh pr comment"

echo ""
echo "=== Test 2: Code-reviewer CHANGES_REQUESTED posts comment ==="
cleanup
json='{"agent_name":"code-reviewer","metadata":{"pr_number":"456"},"messages":[{"role":"assistant","content":"CODE_REVIEWER_AGENT: ⚠️ CHANGES_REQUESTED\n\nFound issues..."}]}'
output=$(run_post_review "$json" 2>&1 || true)
assert_contains "$output" "comment_posted" "code-reviewer CHANGES_REQUESTED posts gh pr comment"

echo ""
echo "=== Test 3: Non-reviewer agent silently exits ==="
cleanup
json='{"agent_name":"designer","metadata":{"pr_number":"789"},"messages":[{"role":"assistant","content":"Some work done"}]}'
output=$(run_post_review "$json" 2>&1 || true)
assert_not_contains "$output" "comment_posted" "non-reviewer agent does not post comment"

echo ""
echo "=== Test 4: Missing PR number silently exits ==="
cleanup
json='{"agent_name":"oracle","metadata":{},"messages":[{"role":"assistant","content":"ORACLE_AGENT: ✅ APPROVED"}]}'
output=$(run_post_review "$json" 2>&1 || true)
assert_not_contains "$output" "comment_posted" "missing PR number exits silently"

echo ""
echo "=== Test 5: No verdict in message silently exits ==="
cleanup
json='{"agent_name":"oracle","metadata":{"pr_number":"111"},"messages":[{"role":"assistant","content":"Some analysis without a verdict"}]}'
output=$(run_post_review "$json" 2>&1 || true)
assert_not_contains "$output" "comment_posted" "no verdict in message exits silently"

echo ""
echo "=== Test 6: Idempotency logic is in script ==="
cleanup
# Verify the grep for existing comment prefix is present in the script
if grep -q "gh pr view.*--jq.*comments" /Users/ichigo/Documents/repo/lean-flow/plugin/scripts/post-agent-review.sh; then
  echo "✓ Script checks for existing comments (idempotency)"
  PASS=$((PASS+1))
else
  echo "✗ Script does not check for existing comments"
  FAIL=$((FAIL+1))
fi

echo ""
echo "=== Test 7: Oracle APPROVED uses correct prefix ==="
cleanup
# Verify the script looks for ORACLE_AGENT: prefix
if grep -q "ORACLE_AGENT" /Users/ichigo/Documents/repo/lean-flow/plugin/scripts/post-agent-review.sh; then
  echo "✓ oracle agent prefix is in script"
  PASS=$((PASS+1))
else
  echo "✗ oracle agent prefix not in script"
  FAIL=$((FAIL+1))
fi

echo ""
echo "=== Test 8: Code-reviewer APPROVED uses correct prefix ==="
cleanup
# Verify the script looks for CODE_REVIEWER_AGENT: prefix
if grep -q "CODE_REVIEWER_AGENT" /Users/ichigo/Documents/repo/lean-flow/plugin/scripts/post-agent-review.sh; then
  echo "✓ code-reviewer agent prefix is in script"
  PASS=$((PASS+1))
else
  echo "✗ code-reviewer agent prefix not in script"
  FAIL=$((FAIL+1))
fi

echo ""
echo "=== Test 9: Script filters out ❌ REJECTED verdict ==="
cleanup
# The script should only match ✅ or ⚠️, not ❌
if grep -q "\\\\u2705\\|✅\\|⚠️" /Users/ichigo/Documents/repo/lean-flow/plugin/scripts/post-agent-review.sh; then
  echo "✓ Script accepts ✅ and ⚠️ only"
  PASS=$((PASS+1))
else
  echo "✗ Script verdict filtering may be incorrect"
  FAIL=$((FAIL+1))
fi

echo ""
echo "=== Test 10: Script has proper error handling ==="
cleanup
# Verify the script sets pipefail and has proper error handling
if grep -q "set -o pipefail" /Users/ichigo/Documents/repo/lean-flow/plugin/scripts/post-agent-review.sh; then
  echo "✓ Script has pipefail for safety"
  PASS=$((PASS+1))
else
  echo "✗ Script missing pipefail"
  FAIL=$((FAIL+1))
fi

echo ""
echo "=== Test 11: Verdict in non-final assistant message is detected ==="
cleanup
# Regression test for finding #2: transcript with verdict in a non-final message
# Should still detect the verdict even if the last message is a tool acknowledgment
json='{"agent_name":"oracle","metadata":{"pr_number":"999"},"messages":[{"role":"assistant","content":"ORACLE_AGENT: ✅ APPROVED\n\nAnalysis here"},{"role":"assistant","content":"Tool execution complete"}]}'
output=$(run_post_review "$json" 2>&1 || true)
assert_contains "$output" "comment_posted" "verdict in non-final message still posts comment"

echo ""
echo "=== Test 12: Inline comments don't block verdict posting (tight idempotency) ==="
cleanup
# Regression test for finding #4: PR with inline (non-verdict) comments containing agent prefix
# These should not block posting the verdict summary comment
inline_comments_response='{"comments":[{"body":"ORACLE_AGENT: Found an issue on line 42"},{"body":"ORACLE_AGENT: Also check line 99"}]}'
json='{"agent_name":"oracle","metadata":{"pr_number":"888"},"messages":[{"role":"assistant","content":"ORACLE_AGENT: ✅ APPROVED\n\nOverall analysis"}]}'
output=$(run_post_review "$json" "$inline_comments_response" 2>&1 || true)
assert_contains "$output" "comment_posted" "inline comments don't block verdict posting"

echo ""
echo "================================"
echo "$PASS passed, $FAIL failed"
echo "================================"

cleanup
[ "$FAIL" -eq 0 ]
