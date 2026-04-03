#!/bin/bash
# Session briefing — show git state on session start

if ! git rev-parse --is-inside-work-tree &>/dev/null; then
  exit 0
fi

REPO=$(basename "$(git rev-parse --show-toplevel)")
BRANCH=$(git branch --show-current 2>/dev/null || echo "detached")

COMMITS=$(git log --oneline -10 2>/dev/null || echo "(no commits)")
CHANGES=$(git status --short 2>/dev/null | head -20)
STASHES=$(git stash list 2>/dev/null | head -5)

# Check for planning state
PLAN_STATE=""
if [ -f "docs/superpowers/specs/project-state.md" ]; then
  PLAN_STATE=$(head -40 docs/superpowers/specs/project-state.md 2>/dev/null)
fi

# Build briefing text (plain, no JSON escaping issues)
BRIEFING="=== SESSION BRIEFING ===
Repo: ${REPO} | Branch: ${BRANCH}

--- Recent commits on ${BRANCH} ---
${COMMITS}

--- Uncommitted changes ---
${CHANGES:-  (clean working tree)}"

[ -n "$STASHES" ] && BRIEFING="${BRIEFING}

--- Stashes ---
${STASHES}"

[ -n "$PLAN_STATE" ] && BRIEFING="${BRIEFING}

--- Planning state ---
${PLAN_STATE}"

BRIEFING="${BRIEFING}

=== BRIEFING: Show this summary to the user and ask what to work on next ==="

# Use jq to safely encode into JSON
if command -v jq &>/dev/null; then
  jq -n --arg msg "$BRIEFING" '{"systemMessage": $msg}'
else
  # Fallback: escape newlines and quotes manually
  ESCAPED=$(printf '%s' "$BRIEFING" | sed 's/\\/\\\\/g; s/"/\\"/g; s/$/\\n/' | tr -d '\n')
  printf '{"systemMessage": "%s"}\n' "$ESCAPED"
fi
