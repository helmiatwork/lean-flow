#!/usr/bin/env bash
# lean-flow project session start: quick health snapshot
set -uo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$REPO_ROOT" || exit 0

echo "[session-start] lean-flow project — $(git symbolic-ref --short HEAD 2>/dev/null || echo detached)"
echo "[session-start] last 3 commits:"
git log --oneline -3 2>/dev/null | sed "s/^/  /"

if [ -x "$REPO_ROOT/plugin/scripts/project-doctor/score.sh" ]; then
  SCORE=$("$REPO_ROOT/plugin/scripts/project-doctor/score.sh" --score-only 2>/dev/null || echo "?")
  echo "[session-start] project-doctor: $SCORE/25"
fi

exit 0
