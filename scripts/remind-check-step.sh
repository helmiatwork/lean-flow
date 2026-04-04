#!/usr/bin/env bash
# Remind orchestrator to mark completed plan steps [x] in the skeleton.
# Fires on SubagentStop — checks if any plan skeleton has unchecked steps.

PLANS_DIR="${HOME}/.claude/plans"

# Skip if no plans directory
if [ ! -d "$PLANS_DIR" ]; then
  exit 0
fi

# Check if any skeleton has unchecked steps
unchecked=0
for f in "$PLANS_DIR"/*.md; do
  [ -f "$f" ] || continue
  if grep -qE '^\s*\d+\.\s+\[ \]' "$f" 2>/dev/null; then
    unchecked=1
    break
  fi
done

if [ "$unchecked" -eq 1 ]; then
  cat <<'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "SubagentStop",
    "additionalContext": "📋 REMINDER: If this subagent completed a plan step, mark it [x] in the skeleton file (~/.claude/plans/*.md) now. The plan viewer updates live."
  }
}
EOF
fi

exit 0
