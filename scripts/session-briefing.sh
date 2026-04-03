#!/bin/bash
# Session briefing — show git state on session start

if ! git rev-parse --is-inside-work-tree &>/dev/null; then
  exit 0
fi

REPO=$(basename "$(git rev-parse --show-toplevel)")
BRANCH=$(git branch --show-current 2>/dev/null || echo "detached")
MAIN=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main")

COMMITS=$(git log --oneline -10 2>/dev/null)
CHANGES=$(git status --short 2>/dev/null | head -20)
STASHES=$(git stash list 2>/dev/null | head -5)

# Check for planning state
PLAN_STATE=""
if [ -f "docs/superpowers/specs/project-state.md" ]; then
  PLAN_STATE=$(head -40 docs/superpowers/specs/project-state.md 2>/dev/null)
fi

cat <<EOF
{
  "systemMessage": "=== SESSION BRIEFING ===\nRepo: ${REPO} | Branch: ${BRANCH}\n\n--- Recent commits on ${BRANCH} ---\n${COMMITS}\n\n--- Uncommitted changes ---\n${CHANGES}\n${STASHES:+\n--- Stashes ---\n${STASHES}}\n${PLAN_STATE:+\n--- Planning state ---\n${PLAN_STATE}}\n\n=== BRIEFING: Show this summary to the user and ask what to work on next ==="
}
EOF
