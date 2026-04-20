#!/usr/bin/env bash
# After subagent completes:
# - If unchecked steps exist → remind to mark [x]
# - If ALL steps checked → congratulate + remind to proceed to audit/PR

PLANS_DIR="${HOME}/.claude/plans"

if [ ! -d "$PLANS_DIR" ]; then
  exit 0
fi

# Find the most recently modified skeleton with steps
latest=""
latest_mtime=0
for f in "$PLANS_DIR"/*.md; do
  [ -f "$f" ] || continue
  # Only consider files with step checkboxes
  if grep -qE '^\s*\d+\.\s+\[[ xX]\]' "$f" 2>/dev/null; then
    if [ "$(uname)" = "Darwin" ]; then
      mtime=$(stat -f%m "$f" 2>/dev/null || echo 0)
    else
      mtime=$(stat -c%Y "$f" 2>/dev/null || echo 0)
    fi
    if [ "$mtime" -gt "$latest_mtime" ]; then
      latest="$f"
      latest_mtime="$mtime"
    fi
  fi
done

[ -z "$latest" ] && exit 0

# Count checked and unchecked
total=$(grep -cE '^\s*\d+\.\s+\[[ xX]\]' "$latest" 2>/dev/null || echo 0)
checked=$(grep -cE '^\s*\d+\.\s+\[[xX]\]' "$latest" 2>/dev/null || echo 0)
unchecked=$((total - checked))
plan_name=$(basename "$latest" .md)

if [ "$unchecked" -gt 0 ]; then
  cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "SubagentStop",
    "additionalContext": "📋 Plan '${plan_name}': ${checked}/${total} steps done. Mark completed step [x] in skeleton now."
  }
}
EOF
elif [ "$total" -gt 0 ]; then
  cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "SubagentStop",
    "additionalContext": "✅ Plan '${plan_name}': ALL ${total} steps complete! Proceed to: security audit → PR parent → main (with release notes) → oracle final review → merge."
  }
}
EOF
fi

exit 0
