#!/usr/bin/env bash
# Session briefing — fires once per unique (repo, branch, working-tree state)
# Subsequent sessions with no changes produce zero output = zero tokens

if ! git rev-parse --is-inside-work-tree &>/dev/null; then
  exit 0
fi

REPO=$(basename "$(git rev-parse --show-toplevel)")
BRANCH=$(git branch --show-current 2>/dev/null || echo "detached")
CHANGES=$(git status --short 2>/dev/null | head -20)

# Cache key: changes only if repo/branch/working-tree actually changed
STATE_HASH=$(printf '%s\n%s\n%s' "$REPO" "$BRANCH" "$CHANGES" | md5)
CACHE_FILE="/tmp/claude-briefing-${STATE_HASH}.cache"

# Already briefed for this exact state — skip
[ -f "$CACHE_FILE" ] && exit 0

# Mark as briefed
touch "$CACHE_FILE"

# Clean up old briefing caches (keep last 20)
find /tmp -maxdepth 1 -name "claude-briefing-*.cache" 2>/dev/null | \
  sort -t- -k3 | head -n -20 | xargs -r python3 -c "import sys,os; [os.remove(f) for f in sys.argv[1:]]" 2>/dev/null || true

BRIEFING="${REPO} | ${BRANCH}
${CHANGES:-(clean)}"

if command -v jq &>/dev/null; then
  jq -n --arg msg "$BRIEFING" '{"systemMessage": $msg}'
else
  ESCAPED=$(printf '%s' "$BRIEFING" | sed 's/\\/\\\\/g; s/"/\\"/g; s/$/\\n/' | tr -d '\n')
  printf '{"systemMessage": "%s"}\n' "$ESCAPED"
fi
