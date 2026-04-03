#!/usr/bin/env bash
# Generate HTML plan viewer from plan-plus files and open in browser

PLANS_DIR="${HOME}/.claude/plans"
OUTPUT="/tmp/lean-flow-plans.html"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

node "${CLAUDE_PLUGIN_ROOT:-${SCRIPT_DIR}/..}/scripts/plan-viewer.mjs" "$PLANS_DIR" "$OUTPUT"

# Open in browser
if [ "$(uname)" = "Darwin" ]; then
  open "$OUTPUT"
else
  xdg-open "$OUTPUT" 2>/dev/null || echo "Open $OUTPUT in your browser"
fi
