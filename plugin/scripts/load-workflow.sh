#!/usr/bin/env bash
# load-workflow.sh
# UserPromptSubmit: inject workflow rules once per session into model context.
# Skips Mermaid diagram (lines 1-242) to minimise token cost.

INPUT=$(cat)
SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)

WORKFLOW_FILE="${CLAUDE_PLUGIN_ROOT}/workflows/claude-rules.md"

[ -f "$WORKFLOW_FILE" ] || exit 0
[ -z "$SESSION_ID" ] && exit 0

# Fire once per session only
SESSION_CACHE="/tmp/claude-workflow-session-${SESSION_ID}.cache"
[ -f "$SESSION_CACHE" ] && exit 0
touch "$SESSION_CACHE"

# Clean up old session caches (keep last 10)
ls -1t /tmp/claude-workflow-session-*.cache 2>/dev/null | tail -n +11 | xargs rm -f 2>/dev/null || true

PROSE=$(cat "$WORKFLOW_FILE")

HEADER="[LEAN-FLOW WORKFLOW ACTIVE]
CRITICAL: Use lean-flow agents + superpowers methodologies. Never suggest /gsd-* commands.
Routing:
- Scoping/discussion → lean-flow:discuss (NOT /gsd-discuss-phase)
- Planning (medium/heavy) → superpowers:writing-plans (NOT /gsd-plan-phase)
- Execution → superpowers:executing-plans + lean-flow:fixer (NOT /gsd-executor)
- Verification → superpowers:verification-before-completion + lean-flow:verifier (NOT /gsd-verify-phase)
- Bugs → superpowers:systematic-debugging FIRST
- Features → superpowers:test-driven-development (failing test before code)
Always follow the workflow rules below exactly.

"
CONTENT="${HEADER}${PROSE}"

jq -n --arg content "$CONTENT" \
  '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":$content}}' 2>/dev/null
