#!/usr/bin/env bash
# Track test failures — emit warning at 2nd failure, escalation at 3rd
COUNTER_FILE="/tmp/lean-flow-test-failures"
OUTPUT=$(jq -r '.tool_response.stdout // ""')

# Detect test failure patterns
if echo "$OUTPUT" | grep -qiE '(FAIL|FAILED|failures?:|errors?:)\s*[1-9]|tests?\s+failed|AssertionError|Expected.*but got'; then
  count=0
  [ -f "$COUNTER_FILE" ] && count=$(cat "$COUNTER_FILE")
  count=$((count + 1))
  echo "$count" > "$COUNTER_FILE"

  if [ "$count" -ge 3 ]; then
    echo "{\"hookSpecificOutput\":{\"hookEventName\":\"PostToolUse\",\"additionalContext\":\"⚠️ Test failure #${count}. ESCALATE TO ORACLE — fixer has failed 3+ times. Dispatch oracle (sonnet) for root cause diagnosis before retrying.\"}}"
    echo "0" > "$COUNTER_FILE"
  elif [ "$count" -ge 2 ]; then
    echo "{\"hookSpecificOutput\":{\"hookEventName\":\"PostToolUse\",\"additionalContext\":\"⚠️ Test failure #${count} of 3. One more failure triggers Oracle escalation.\"}}"
  fi
elif echo "$OUTPUT" | grep -qiE '(pass|passed|ok|success|✓)\s|tests?\s+passed|0 failures'; then
  # Reset counter on success
  echo "0" > "$COUNTER_FILE" 2>/dev/null

  # Nudge pattern_store if knowledge MCP is available and we haven't nudged this session
  NUDGE_FILE="/tmp/lean-flow-pattern-nudge"
  if [ ! -f "$NUDGE_FILE" ] && [ -f "${HOME}/.claude/knowledge/patterns.db" ]; then
    touch "$NUDGE_FILE"
    REPO=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null || echo "")
    echo "{\"hookSpecificOutput\":{\"hookEventName\":\"PostToolUse\",\"additionalContext\":\"Tests passed. If this solved a non-trivial problem, run pattern_store to save the approach for future sessions.\"}}"
  fi
fi
