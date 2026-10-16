#!/usr/bin/env bash
# Ensure RTK (Rust Tool Kit) is installed and initialized.
# Runs on SessionStart — idempotent.
# RTK rewrites Bash commands to faster Rust equivalents via a PreToolUse hook.

source "$(dirname "$0")/load-config.sh" 2>/dev/null

# Check if RTK is enabled in config (default: true)
LEAN_FLOW_ENABLE_RTK="${LEAN_FLOW_ENABLE_RTK:-true}"
[ "$LEAN_FLOW_ENABLE_RTK" = "false" ] && exit 0

# Install RTK if not present
if ! command -v rtk &>/dev/null; then
  if command -v brew &>/dev/null; then
    brew install rtk &>/dev/null
  else
    curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh &>/dev/null
  fi

  # Verify installation succeeded
  if ! command -v rtk &>/dev/null; then
    cat <<'EOF'
{
  "systemMessage": "[lean-flow] RTK auto-install failed. Install manually: brew install rtk (or visit https://www.rtk-ai.app/#install)"
}
EOF
    exit 0
  fi
fi

# Check if rtk hook is already configured (look for rtk in settings hooks)
SETTINGS_FILE="${HOME}/.claude/settings.json"
if [ -f "$SETTINGS_FILE" ] && command -v jq &>/dev/null; then
  if jq -e '.hooks.PreToolUse[]?.hooks[]? | select(.command | test("rtk"))' "$SETTINGS_FILE" &>/dev/null; then
    exit 0
  fi
fi

# Initialize RTK globally (adds PreToolUse hook to settings.json)
rtk init --global 2>/dev/null

cat <<'EOF'
{
  "systemMessage": "[lean-flow] RTK initialized — Bash commands will be rewritten to faster Rust equivalents."
}
EOF

exit 0
