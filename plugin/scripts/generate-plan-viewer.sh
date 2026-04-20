#!/usr/bin/env bash
# Start or refresh the live plan viewer

PORT=3456
PLUGIN_DIR="${CLAUDE_PLUGIN_ROOT:-$(dirname "$0")/..}"
LOCK="/tmp/lean-flow-plan-server.pid"

# Check if server is already running
if [ -f "$LOCK" ]; then
  pid=$(cat "$LOCK")
  if kill -0 "$pid" 2>/dev/null; then
    # Server running — just open browser
    if [ "$(uname)" = "Darwin" ]; then
      open "http://localhost:${PORT}"
    else
      xdg-open "http://localhost:${PORT}" 2>/dev/null
    fi
    exit 0
  fi
  rm -f "$LOCK"
fi

# Start server in background
node "${PLUGIN_DIR}/scripts/plan-server.mjs" "$PORT" &>/dev/null &
echo $! > "$LOCK"

# Wait for server to start
sleep 1

# Open browser
if [ "$(uname)" = "Darwin" ]; then
  open "http://localhost:${PORT}"
else
  xdg-open "http://localhost:${PORT}" 2>/dev/null
fi

cat <<EOF
{
  "systemMessage": "[lean-flow] Plan viewer running at http://localhost:${PORT} (live reload)"
}
EOF
