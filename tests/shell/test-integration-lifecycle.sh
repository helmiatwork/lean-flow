#!/usr/bin/env bash
# Integration test for the full hook lifecycle.
#
# Simulates a Claude Code session by feeding fake event payloads through
# workflow-hook.sh (the central router) for each event type, and asserts
# the merged output is well-formed and references the right skills.
#
# Lifecycle covered:
#   - SessionStart      → session-briefing emits systemMessage
#   - UserPromptSubmit  → pattern-recall + load-workflow + star-clarify merged
#   - PostToolUse Write|Edit → enforce-tdd injection
#   - SubagentStop      → remind-check-step
#   - Stop              → background scripts (no stdout, but exit 0)

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HOOK="${REPO_ROOT}/plugin/scripts/workflow-hook.sh"
export CLAUDE_PLUGIN_ROOT="${REPO_ROOT}/plugin"

PASS=0
FAIL=0

assert_zero_exit() {
  local desc="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    echo "✓ $desc"
    PASS=$((PASS+1))
  else
    echo "✗ $desc (exit $?)"
    FAIL=$((FAIL+1))
  fi
}

# Use isolated HOME so we don't pollute the user's actual cache files.
TEST_HOME=$(mktemp -d)
export HOME="$TEST_HOME"

cleanup() {
  rm -rf "$TEST_HOME" 2>/dev/null || true
  rm -f /tmp/claude-workflow-session-integ-test-*.cache 2>/dev/null || true
  rm -f /tmp/claude-briefing-*.cache 2>/dev/null || true
}
trap cleanup EXIT

echo "=== Lifecycle event 1: SessionStart ==="
INPUT='{"session_id":"integ-test-session","cwd":"'"$TEST_HOME"'"}'
output=$(echo "$INPUT" | bash "$HOOK" SessionStart 2>&1)
exit_code=$?
if [ "$exit_code" -eq 0 ]; then
  echo "✓ SessionStart hook exits 0"
  PASS=$((PASS+1))
else
  echo "✗ SessionStart hook exit $exit_code"
  FAIL=$((FAIL+1))
fi

echo ""
echo "=== Lifecycle event 2: UserPromptSubmit ==="
SESSION_ID="integ-test-userprompt-$$"
INPUT='{"session_id":"'"$SESSION_ID"'","prompt":"build a feature for the auth module"}'
output=$(echo "$INPUT" | bash "$HOOK" UserPromptSubmit 2>&1)
exit_code=$?
if [ "$exit_code" -eq 0 ]; then
  echo "✓ UserPromptSubmit hook exits 0"
  PASS=$((PASS+1))
else
  echo "✗ UserPromptSubmit hook exit $exit_code"
  FAIL=$((FAIL+1))
fi

if [ -n "$output" ]; then
  if command -v jq &>/dev/null; then
    if echo "$output" | jq -e '.hookSpecificOutput.hookEventName == "UserPromptSubmit"' >/dev/null 2>&1; then
      echo "✓ UserPromptSubmit produces valid JSON with correct hookEventName"
      PASS=$((PASS+1))
    else
      echo "✗ UserPromptSubmit JSON shape wrong"
      FAIL=$((FAIL+1))
    fi
    additional=$(echo "$output" | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null)
    if echo "$additional" | grep -q "LEAN-FLOW WORKFLOW ACTIVE"; then
      echo "✓ UserPromptSubmit injects workflow rules"
      PASS=$((PASS+1))
    else
      echo "✗ UserPromptSubmit missing LEAN-FLOW header"
      FAIL=$((FAIL+1))
    fi
    # star-clarify injects either [STAR PROTOCOL] (general) or [TDD PRE-CHECK]
    # (when prompt looks like code creation). Either is acceptable.
    if echo "$additional" | grep -qE "STAR PROTOCOL|TDD PRE-CHECK"; then
      echo "✓ UserPromptSubmit injects STAR or TDD pre-check"
      PASS=$((PASS+1))
    else
      echo "✗ UserPromptSubmit missing STAR/TDD injection"
      FAIL=$((FAIL+1))
    fi
  fi
else
  echo "✗ UserPromptSubmit produced no output"
  FAIL=$((FAIL+1))
fi

echo ""
echo "=== Lifecycle event 3: PostToolUse Write|Edit (TDD enforcement) ==="
INPUT='{"session_id":"'"$SESSION_ID"'","tool_name":"Write","tool_input":{"file_path":"'"$TEST_HOME"'/src/foo.ts","content":"export const x = 1;"}}'
output=$(echo "$INPUT" | bash "$HOOK" PostToolUse "Write|Edit" 2>&1)
exit_code=$?
if [ "$exit_code" -eq 0 ]; then
  echo "✓ PostToolUse Write|Edit hook exits 0"
  PASS=$((PASS+1))
else
  echo "✗ PostToolUse Write|Edit exit $exit_code"
  FAIL=$((FAIL+1))
fi

echo ""
echo "=== Lifecycle event 4: SubagentStop ==="
INPUT='{"session_id":"'"$SESSION_ID"'"}'
output=$(echo "$INPUT" | bash "$HOOK" SubagentStop 2>&1)
exit_code=$?
if [ "$exit_code" -eq 0 ]; then
  echo "✓ SubagentStop hook exits 0"
  PASS=$((PASS+1))
else
  echo "✗ SubagentStop exit $exit_code"
  FAIL=$((FAIL+1))
fi

echo ""
echo "=== Lifecycle event 5: Stop ==="
INPUT='{"session_id":"'"$SESSION_ID"'"}'
# Stop runs background tasks; the hook itself returns immediately.
output=$(echo "$INPUT" | bash "$HOOK" Stop 2>&1)
exit_code=$?
if [ "$exit_code" -eq 0 ]; then
  echo "✓ Stop hook exits 0"
  PASS=$((PASS+1))
else
  echo "✗ Stop exit $exit_code"
  FAIL=$((FAIL+1))
fi

echo ""
echo "=== Lifecycle event 6: PostCompact ==="
output=$(echo "$INPUT" | bash "$HOOK" PostCompact 2>&1)
exit_code=$?
if [ "$exit_code" -eq 0 ]; then
  echo "✓ PostCompact hook exits 0"
  PASS=$((PASS+1))
else
  echo "✗ PostCompact exit $exit_code"
  FAIL=$((FAIL+1))
fi

echo ""
echo "=== Lifecycle event 7: PostToolUse ExitPlanMode (plan restructure) ==="
# This invokes generate-plan-viewer; should not crash even without a real plan file.
INPUT='{"session_id":"'"$SESSION_ID"'","tool_name":"ExitPlanMode","tool_input":{"plan":"# Test plan\n\n- [ ] step 1"}}'
output=$(echo "$INPUT" | bash "$HOOK" PostToolUse ExitPlanMode 2>&1)
exit_code=$?
if [ "$exit_code" -eq 0 ]; then
  echo "✓ PostToolUse ExitPlanMode exits 0"
  PASS=$((PASS+1))
else
  echo "✗ PostToolUse ExitPlanMode exit $exit_code"
  FAIL=$((FAIL+1))
fi

echo ""
echo "=== Lifecycle event 8: unknown event is no-op ==="
output=$(echo "$INPUT" | bash "$HOOK" UnknownEvent 2>&1)
exit_code=$?
if [ "$exit_code" -eq 0 ] && [ -z "$output" ]; then
  echo "✓ unknown event exits 0 with empty output"
  PASS=$((PASS+1))
else
  echo "✗ unknown event misbehaved (exit $exit_code, output: '$output')"
  FAIL=$((FAIL+1))
fi

echo ""
echo "================================"
echo "$PASS passed, $FAIL failed"
echo "================================"
[ "$FAIL" -eq 0 ]
