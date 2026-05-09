#!/usr/bin/env bash
# Lightweight project-doctor reminder on session start.
# Prints a 1-line warning if score < 70. Silent otherwise.
set -euo pipefail
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
SCORE=$("$PLUGIN_ROOT/scripts/project-doctor/score.sh" --score-only 2>/dev/null || echo "0")

if [ "$SCORE" -lt 70 ]; then
  echo "⚠️  Project-doctor score: ${SCORE}/100 — run /project-doctor (20-item audit)"
fi
exit 0
