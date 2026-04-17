#!/usr/bin/env bash
# Session briefing — minimal context, max signal

if ! git rev-parse --is-inside-work-tree &>/dev/null; then
  exit 0
fi

REPO=$(basename "$(git rev-parse --show-toplevel)")
BRANCH=$(git branch --show-current 2>/dev/null || echo "detached")
COMMITS=$(git log --oneline -5 2>/dev/null || echo "(no commits)")
CHANGES=$(git status --short 2>/dev/null | head -10)

# Knowledge: 1-line count only — use pattern_search on demand
KN=""
KNOWLEDGE_DB="${HOME}/.claude/knowledge/patterns.db"
if [ -f "$KNOWLEDGE_DB" ] && command -v sqlite3 &>/dev/null; then
  total=$(sqlite3 "$KNOWLEDGE_DB" "SELECT COUNT(*) FROM patterns;" 2>/dev/null || echo "0")
  repo_count=$(sqlite3 "$KNOWLEDGE_DB" "SELECT COUNT(*) FROM patterns WHERE project='${REPO}';" 2>/dev/null || echo "0")
  [ "$total" -gt 0 ] && KN="Patterns: ${repo_count}/${total} for ${REPO}"
fi

BRIEFING="${REPO} | ${BRANCH}
${COMMITS}
${CHANGES:+---
${CHANGES}}${KN:+
${KN}}"

if command -v jq &>/dev/null; then
  jq -n --arg msg "$BRIEFING" '{"systemMessage": $msg}'
else
  ESCAPED=$(printf '%s' "$BRIEFING" | sed 's/\\/\\\\/g; s/"/\\"/g; s/$/\\n/' | tr -d '\n')
  printf '{"systemMessage": "%s"}\n' "$ESCAPED"
fi
