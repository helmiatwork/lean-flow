#!/usr/bin/env bash
# load-workflow.sh
# SessionStart: inject workflow rules into model context, only when workflow changes.
# Skips the Mermaid diagram (lines 1-242) to minimise token cost.

WORKFLOW_FILE="$(dirname "${CLAUDE_PLUGIN_ROOT}")/workflows/standard-development-flow.md"

[ -f "$WORKFLOW_FILE" ] || exit 0

# Hash-based cache — only re-inject when workflow file changes
WORKFLOW_HASH=$(md5 -q "$WORKFLOW_FILE" 2>/dev/null || md5sum "$WORKFLOW_FILE" 2>/dev/null | cut -d' ' -f1)
CACHE_FILE="/tmp/claude-workflow-${WORKFLOW_HASH}.cache"
[ -f "$CACHE_FILE" ] && exit 0
touch "$CACHE_FILE"

# Clean up old caches (keep last 5)
find /tmp -maxdepth 1 -name "claude-workflow-*.cache" 2>/dev/null | sort | head -n -5 | xargs rm -f 2>/dev/null || true

# Extract prose only — skip lines 1-242 (title + Mermaid diagram)
CONTENT=$(tail -n +243 "$WORKFLOW_FILE")

jq -n --arg content "$CONTENT" \
  '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":$content}}' 2>/dev/null
