#!/usr/bin/env bash
# auto-compress-output.sh
# PreToolUse: Bash — intercept high-output commands, run them directly,
# compress output via haiku if large, return summary, block original call.
# Zero cost for small output — falls through transparently.

INPUT=$(cat)
COMMAND=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
[ -z "$COMMAND" ] && exit 0

# Commands worth intercepting (read-heavy, potentially large output)
is_high_output() {
  local cmd="$1"
  [[ "$cmd" =~ ^git\ (log|diff|show|blame|shortlog) ]]     && return 0
  [[ "$cmd" =~ ^(grep|rg)\ .*(\ -r|\ -R|\ --recursive) ]] && return 0
  [[ "$cmd" =~ ^(npm|yarn|pnpm)\ (test|run\ test) ]]        && return 0
  [[ "$cmd" =~ ^(pytest|py\.test) ]]                         && return 0
  [[ "$cmd" =~ ^(cargo\ test|go\ test|rspec|jest) ]]         && return 0
  [[ "$cmd" =~ ^(find\ |ls\ -la?R) ]]                        && return 0
  return 1
}

is_high_output "$COMMAND" || exit 0

# Run the command directly — no model needed for execution
OUTPUT=$(eval "$COMMAND" 2>&1)
EXIT_CODE=$?
LINE_COUNT=$(printf '%s' "$OUTPUT" | wc -l | tr -d ' ')

# Small output — not worth compressing, let Claude run it normally
[ "$LINE_COUNT" -lt 25 ] && exit 0

# Large output — compress via haiku
HAIKU_MODEL="claude-haiku-4-5-20251001"
SUMMARY=""

if command -v claude &>/dev/null; then
  SUMMARY=$(printf '%s' "$OUTPUT" | claude -p \
    "Summarize this command output. Keep: errors, file names, counts, key values, failed tests. Remove: repetitive lines, progress bars, blank lines. Max 20 lines. No preamble." \
    --model "$HAIKU_MODEL" 2>/dev/null)
fi

# Fallback: truncate to first 30 lines if haiku unavailable
if [ -z "$SUMMARY" ]; then
  SUMMARY=$(printf '%s' "$OUTPUT" | head -30)
  SUMMARY="${SUMMARY}
... [${LINE_COUNT} lines truncated — haiku unavailable]"
fi

STATUS_NOTE=""
[ "$EXIT_CODE" -ne 0 ] && STATUS_NOTE=" (exit $EXIT_CODE)"

RESULT="\$ ${COMMAND}${STATUS_NOTE}
[${LINE_COUNT} lines → compressed by haiku]
${SUMMARY}"

jq -n --arg r "$RESULT" \
  '{"hookSpecificOutput": {"hookEventName": "PreToolUse", "additionalContext": $r}}'

exit 2
