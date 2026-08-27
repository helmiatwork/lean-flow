#!/usr/bin/env bash
# delegate-task-retry.sh — PostToolUse hook on the Task tool.
#
# Detects common Task delegation failures and appends inline retry guidance
# with concrete fix hints. Adapted from oh-my-opencode-slim's
# delegate-task-retry plugin (github.com/alvinunreal/oh-my-opencode-slim).
#
# Trigger: PostToolUse, matcher = "Task"
# Input: stdin JSON from Claude Code with .tool_response, .tool_input
# Output: JSON with hookSpecificOutput.additionalContext appended to the
#         model's next turn — guides the orchestrator to retry with corrected
#         parameters instead of failing silently or escalating.

set -uo pipefail

# Read tool result (silent exit on missing input)
INPUT=$(cat 2>/dev/null || true)
[ -z "$INPUT" ] && exit 0

# Only process Task tool errors
TOOL_NAME=$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
[ "$TOOL_NAME" != "Task" ] && exit 0

# Combine stdout + stderr + error fields for pattern matching
OUTPUT=$(printf '%s' "$INPUT" | jq -r '
  (.tool_response.stdout // "") + "\n" +
  (.tool_response.stderr // "") + "\n" +
  (.tool_response.error // "") + "\n" +
  (.tool_response // "" | tostring)
' 2>/dev/null)

# Quick exit if output looks healthy (no error signals)
if ! printf '%s' "$OUTPUT" | grep -qiE 'error|invalid|not.found|not.allowed|InputValidationError'; then
  exit 0
fi

# ── Pattern → fix-hint table ────────────────────────────────────────────
# Each entry: regex on three pipe-separated fields:
#   "regex|error_type|fix_hint"
patterns=(
  "subagent_type.*(required|missing)|missing_subagent_type|Add subagent_type='<agent-name>' (e.g. 'fixer', 'explorer', 'oracle')."
  "Unknown.*subagent_type|Invalid.*agent.*type|unknown_agent|The subagent_type is invalid. Use one of: fixer, oracle, explorer, librarian, designer, code-reviewer."
  "InputValidationError|input_validation|Inspect the InputValidationError detail and provide all required parameters before retrying."
  "Permission denied|permission|Tool was blocked by a permission rule. Check ~/.gemini/settings.json permissions.allow / permissions.deny."
  "prompt.*(required|missing|empty)|missing_prompt|The prompt parameter is required and must be a non-empty self-contained brief for the subagent."
  "description.*(required|missing)|missing_description|Add a 3-5 word description parameter."
  "rate.limit|too.many.requests|rate_limit|Rate limited. Wait briefly then retry, or escalate to @oracle for analysis."
)

matched_type=""
matched_hint=""

for entry in "${patterns[@]}"; do
  regex="${entry%%|*}"
  rest="${entry#*|}"
  err_type="${rest%%|*}"
  hint="${rest#*|}"

  if printf '%s' "$OUTPUT" | grep -qiE "$regex"; then
    matched_type="$err_type"
    matched_hint="$hint"
    break
  fi
done

# Generic fallback when output has error signals but no specific pattern matched
if [ -z "$matched_type" ]; then
  matched_type="generic_task_error"
  matched_hint="Task delegation failed. Re-read the error, fix the call, and retry. Provide all required parameters: description, prompt, subagent_type."
fi

# Try to surface "available types" lists from the error output
available=$(printf '%s' "$OUTPUT" | grep -oE 'Available[^:]*:\s*[^.]+' | head -1 | sed 's/^[[:space:]]*//')

# Build guidance block
GUIDANCE="[delegate-task retry suggestion]
Error type: ${matched_type}
Fix: ${matched_hint}"

if [ -n "$available" ]; then
  GUIDANCE="${GUIDANCE}
${available}"
fi

GUIDANCE="${GUIDANCE}
Retry now with corrected parameters. Example:
Agent(description=\"...\", prompt=\"...\", subagent_type=\"fixer\")"

# Emit as additionalContext so Claude sees it on the next turn
jq -n --arg ctx "$GUIDANCE" \
  '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":$ctx}}' 2>/dev/null
