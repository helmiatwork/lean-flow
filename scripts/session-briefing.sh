#!/usr/bin/env bash
# Session briefing — show git state on session start

if ! git rev-parse --is-inside-work-tree &>/dev/null; then
  exit 0
fi

REPO=$(basename "$(git rev-parse --show-toplevel)")
BRANCH=$(git branch --show-current 2>/dev/null || echo "detached")
CHANGES=$(git status --short 2>/dev/null | head -20)

BRIEFING="${REPO} | ${BRANCH}
${CHANGES:-(clean)}"

# Use jq to safely encode into JSON
if command -v jq &>/dev/null; then
  jq -n --arg msg "$BRIEFING" '{"systemMessage": $msg}'
else
  # Fallback: escape newlines and quotes manually
  ESCAPED=$(printf '%s' "$BRIEFING" | sed 's/\\/\\\\/g; s/"/\\"/g; s/$/\\n/' | tr -d '\n')
  printf '{"systemMessage": "%s"}\n' "$ESCAPED"
fi
