#!/usr/bin/env bash
# Session briefing — fires once per unique (repo, branch, working-tree state)
# Subsequent sessions with no changes produce zero output = zero tokens

if ! git rev-parse --is-inside-work-tree &>/dev/null; then
  exit 0
fi

REPO=$(basename "$(git rev-parse --show-toplevel)")
BRANCH=$(git branch --show-current 2>/dev/null || echo "detached")
CHANGES=$(git status --short 2>/dev/null | head -20)

# Query patterns to include in state hash for cache invalidation
PATTERN_SIG=""
KNOWLEDGE_DB="${HOME}/.claude/knowledge/patterns.db"
if [ -f "$KNOWLEDGE_DB" ] && command -v sqlite3 &>/dev/null; then
  PATTERN_SIG=$(sqlite3 "$KNOWLEDGE_DB" \
    "SELECT GROUP_CONCAT(key) FROM (SELECT key FROM patterns WHERE project='${REPO}' AND category != 'session-observation' ORDER BY score DESC, used_count DESC, created_at DESC LIMIT 3);" 2>/dev/null || echo "")

  PATTERNS=$(sqlite3 "$KNOWLEDGE_DB" \
    "SELECT solution FROM patterns WHERE project='${REPO}' AND category != 'session-observation' ORDER BY score DESC, used_count DESC, created_at DESC LIMIT 3;" 2>/dev/null || echo "")
fi

# Cache key: changes only if repo/branch/working-tree/patterns actually changed
STATE_HASH=$(printf '%s\n%s\n%s\n%s' "$REPO" "$BRANCH" "$CHANGES" "$PATTERN_SIG" | md5)
CACHE_FILE="/tmp/claude-briefing-${STATE_HASH}.cache"

# Already briefed for this exact state — skip
[ -f "$CACHE_FILE" ] && exit 0

# Mark as briefed
touch "$CACHE_FILE"

# Clean up old briefing caches (keep last 20)
find /tmp -maxdepth 1 -name "claude-briefing-*.cache" 2>/dev/null | \
  sort -t- -k3 | head -n -20 | xargs -r python3 -c "import sys,os; [os.remove(f) for f in sys.argv[1:]]" 2>/dev/null || true

PATTERN_BULLETS=""
if [ -n "$PATTERNS" ]; then
  while IFS= read -r p; do
    [ -n "$p" ] && PATTERN_BULLETS="${PATTERN_BULLETS}
💡 ${p:0:80}"
  done <<< "$PATTERNS"
fi

BRIEFING="${REPO} | ${BRANCH}
${CHANGES:-(clean)}${PATTERN_BULLETS}"

if command -v jq &>/dev/null; then
  jq -n --arg msg "$BRIEFING" '{"systemMessage": $msg}'
else
  ESCAPED=$(printf '%s' "$BRIEFING" | sed 's/\\/\\\\/g; s/"/\\"/g; s/$/\\n/' | tr -d '\n')
  printf '{"systemMessage": "%s"}\n' "$ESCAPED"
fi
