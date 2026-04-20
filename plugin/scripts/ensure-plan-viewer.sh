#!/usr/bin/env bash
# Ensure the plan viewer server is running in background.
# Starts silently on SessionStart — does NOT open browser (that happens on ExitPlanMode).

PORT=3456
PLUGIN_DIR="${CLAUDE_PLUGIN_ROOT:-$(dirname "$0")/..}"
LOCK="/tmp/lean-flow-plan-server.pid"

# Skip if node not available
if ! command -v node &>/dev/null; then
  exit 0
fi

# Check if already running
if [ -f "$LOCK" ]; then
  pid=$(cat "$LOCK")
  if kill -0 "$pid" 2>/dev/null; then
    exit 0  # Already running, skip silently
  fi
  rm -f "$LOCK"
fi

# Start server in background (no browser open — that's for ExitPlanMode hook)
node "${PLUGIN_DIR}/scripts/plan-server.mjs" "$PORT" &>/dev/null &
echo $! > "$LOCK"

exit 0
