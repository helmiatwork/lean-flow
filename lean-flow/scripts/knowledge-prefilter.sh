#!/usr/bin/env bash
# Knowledge pre-filter — inject relevant patterns when planning starts
# Runs on EnterPlanMode to surface solved patterns before re-solving

KNOWLEDGE_DB="${HOME}/.claude/knowledge/patterns.db"
if [ ! -f "$KNOWLEDGE_DB" ] || ! command -v sqlite3 &>/dev/null; then
  exit 0
fi

# Get current repo name
REPO=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null || echo "unknown")

# Query top 5 patterns by score for this project
PATTERNS=$(sqlite3 "$KNOWLEDGE_DB" "
  SELECT name, score, used_count
  FROM patterns
  WHERE project = '${REPO}'
  ORDER BY score DESC, used_count DESC
  LIMIT 5;
" 2>/dev/null)

if [ -z "$PATTERNS" ]; then
  # Fallback: top patterns across all projects
  PATTERNS=$(sqlite3 "$KNOWLEDGE_DB" "
    SELECT name, score, used_count
    FROM patterns
    ORDER BY score DESC, used_count DESC
    LIMIT 3;
  " 2>/dev/null)
fi

if [ -n "$PATTERNS" ]; then
  MSG="[lean-flow] Relevant patterns found — use pattern_search to get full details before planning:"
  while IFS='|' read -r name score count; do
    MSG="${MSG}"$'\n'"  • ${name} (score: ${score}, used: ${count}x)"
  done <<< "$PATTERNS"

  if command -v jq &>/dev/null; then
    jq -n --arg msg "$MSG" '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":$msg}}'
  else
    # Fallback: manual JSON escaping
    ESCAPED=$(printf '%s' "$MSG" | sed 's/\\/\\\\/g; s/"/\\"/g; s/$/\\n/' | tr -d '\n')
    printf '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"%s"}}\n' "$ESCAPED"
  fi
fi
