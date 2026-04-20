#!/usr/bin/env bash
# load-workflow.sh
# UserPromptSubmit: inject workflow rules once per session into model context.
# Skips Mermaid diagram (lines 1-242) to minimise token cost.

INPUT=$(cat)
SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)

WORKFLOW_FILE="$(dirname "${CLAUDE_PLUGIN_ROOT}")/workflows/standard-development-flow.md"

[ -f "$WORKFLOW_FILE" ] || exit 0
[ -z "$SESSION_ID" ] && exit 0

# Fire once per session only
SESSION_CACHE="/tmp/claude-workflow-session-${SESSION_ID}.cache"
[ -f "$SESSION_CACHE" ] && exit 0
touch "$SESSION_CACHE"

# Clean up old session caches (keep last 10)
ls -1t /tmp/claude-workflow-session-*.cache 2>/dev/null | tail -n +11 | xargs rm -f 2>/dev/null || true

# Extract prose only — skip lines 1-242 (title + Mermaid diagram)
PROSE=$(tail -n +243 "$WORKFLOW_FILE")

HEADER="[LEAN-FLOW WORKFLOW ACTIVE]
CRITICAL: This project uses lean-flow ONLY. Never suggest /gsd-* commands.
Use lean-flow equivalents instead:
- Scoping/discussion → lean-flow:discuss (NOT /gsd-discuss-phase)
- Planning → lean-flow:fixer with plan-plus skill (NOT /gsd-plan-phase)
- Execution → lean-flow:fixer (NOT /gsd-executor)
- Verification → lean-flow:verifier (NOT /gsd-verify-phase)
Always follow the workflow rules below exactly.

"
CONTENT="${HEADER}${PROSE}"

jq -n --arg content "$CONTENT" \
  '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":$content}}' 2>/dev/null
