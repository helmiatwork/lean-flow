#!/usr/bin/env bash
# Regression test for plugin/scripts/load-workflow.sh
#
# Specifically guards the install-path bug fixed in PR #20:
#   - Before fix: looked for $(dirname CLAUDE_PLUGIN_ROOT)/workflows/claude-rules.md,
#     a path that never existed in production installs (only `plugin/` ships).
#     Hook silently exited, workflow rules never reached the model.
#   - After fix: reads from ${CLAUDE_PLUGIN_ROOT}/workflows/claude-rules.md.
#
# Tests assert:
#   1. workflows/claude-rules.md exists at the expected install path
#   2. load-workflow.sh produces non-empty output for a fresh session
#   3. Output is well-formed JSON with the expected hookSpecificOutput shape
#   4. Output references superpowers (not deprecated plan-plus)
#   5. Per-session caching works (idempotent on second call within same session)
#   6. Missing CLAUDE_PLUGIN_ROOT or missing rules file exits cleanly (no crash)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="${REPO_ROOT}/plugin/scripts/load-workflow.sh"
RULES_FILE="${REPO_ROOT}/plugin/workflows/claude-rules.md"

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
    echo "✗ $3 (missing '$2')"
    FAIL=$((FAIL+1))
  fi
}

assert_not_contains() {
  if ! echo "$1" | grep -q "$2"; then
    echo "✓ $3"
    PASS=$((PASS+1))
  else
    echo "✗ $3 (unexpected '$2')"
    FAIL=$((FAIL+1))
  fi
}

assert_nonempty() {
  if [ -n "$1" ] && [ "${#1}" -gt 100 ]; then
    echo "✓ $2 (${#1} bytes)"
    PASS=$((PASS+1))
  else
    echo "✗ $2 (got ${#1} bytes, want > 100)"
    FAIL=$((FAIL+1))
  fi
}

# Fresh test cache dir per run
SESSION_ID="test-load-workflow-$$"
CACHE_FILE="/tmp/claude-workflow-session-${SESSION_ID}.cache"
rm -f "$CACHE_FILE"

cleanup() {
  rm -f "$CACHE_FILE" 2>/dev/null || true
}
trap cleanup EXIT

# ─────────────────────────────────────────────
echo "=== Test 1: workflows/claude-rules.md ships in plugin bundle ==="
# Regression: file MUST live under plugin/ so the marketplace install includes it.
if [ -f "$RULES_FILE" ]; then
  echo "✓ rules file present at plugin/workflows/claude-rules.md"
  PASS=$((PASS+1))
else
  echo "✗ rules file missing at $RULES_FILE — install-path bug regressed"
  FAIL=$((FAIL+1))
fi

echo ""
echo "=== Test 2: load-workflow.sh emits non-empty JSON for fresh session ==="
INPUT=$(printf '{"session_id":"%s","prompt":"hello"}' "$SESSION_ID")
export CLAUDE_PLUGIN_ROOT="${REPO_ROOT}/plugin"
output=$(echo "$INPUT" | bash "$SCRIPT" 2>&1)
assert_nonempty "$output" "load-workflow produces non-empty stdout"

echo ""
echo "=== Test 3: output is well-formed JSON ==="
if command -v jq &>/dev/null; then
  if echo "$output" | jq -e '.hookSpecificOutput.hookEventName == "UserPromptSubmit"' >/dev/null 2>&1; then
    echo "✓ output has hookSpecificOutput.hookEventName == UserPromptSubmit"
    PASS=$((PASS+1))
  else
    echo "✗ output is not valid JSON or missing hookEventName"
    FAIL=$((FAIL+1))
  fi
  if echo "$output" | jq -e '.hookSpecificOutput.additionalContext | length > 100' >/dev/null 2>&1; then
    echo "✓ additionalContext has substantive payload"
    PASS=$((PASS+1))
  else
    echo "✗ additionalContext is empty or too short"
    FAIL=$((FAIL+1))
  fi
else
  echo "⊘ jq not available, skipping JSON shape checks"
fi

echo ""
echo "=== Test 4: output references superpowers, not plan-plus ==="
assert_contains "$output" "superpowers:writing-plans" "output mentions superpowers:writing-plans"
assert_contains "$output" "superpowers:executing-plans" "output mentions superpowers:executing-plans"
assert_contains "$output" "LEAN-FLOW WORKFLOW ACTIVE" "output has expected header"
# The retired plan-plus auto-routing should not be the recommended planning system anymore.
# We don't ban the literal substring "plan-plus" since deprecation notes legitimately mention it.
# Instead we check the OLD broken header line is gone.
assert_not_contains "$output" "lean-flow:fixer with plan-plus skill" "old plan-plus routing line removed"

echo ""
echo "=== Test 5: per-session caching (second call exits silently) ==="
# Cache should now exist from Test 2; second invocation must be a silent no-op.
output2=$(echo "$INPUT" | bash "$SCRIPT" 2>&1)
if [ -z "$output2" ]; then
  echo "✓ second call within same session produces no output (cache hit)"
  PASS=$((PASS+1))
else
  echo "✗ second call should be silent but emitted ${#output2} bytes"
  FAIL=$((FAIL+1))
fi

echo ""
echo "=== Test 6: missing rules file exits cleanly ==="
broken_root=$(mktemp -d)
output3=$(echo "$INPUT" | CLAUDE_PLUGIN_ROOT="$broken_root" bash "$SCRIPT" 2>&1; echo "exit=$?")
exit_code=$(echo "$output3" | tail -1 | sed 's/exit=//')
assert_eq "$exit_code" "0" "missing rules file exits 0 (does not crash)"
rm -rf "$broken_root"

echo ""
echo "=== Test 7: missing session_id exits cleanly ==="
output4=$(echo '{"prompt":"hi"}' | bash "$SCRIPT" 2>&1; echo "exit=$?")
exit_code=$(echo "$output4" | tail -1 | sed 's/exit=//')
assert_eq "$exit_code" "0" "missing session_id exits 0"

echo ""
echo "================================"
echo "$PASS passed, $FAIL failed"
echo "================================"
[ "$FAIL" -eq 0 ]
