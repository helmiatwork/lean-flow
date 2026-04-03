#!/usr/bin/env bash
# Ensure Claude Usage Monitor is installed (SwiftBar + fetcher + launchd).
# macOS only. Runs on SessionStart — idempotent.

# Load config (sets LEAN_FLOW_ENABLE_MONITOR)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=load-config.sh
source "${SCRIPT_DIR}/load-config.sh" 2>/dev/null || true

# Skip if disabled via config
if [ "${LEAN_FLOW_ENABLE_MONITOR}" = "false" ]; then
  exit 0
fi

# Skip on non-macOS
if [ "$(uname)" != "Darwin" ]; then
  exit 0
fi

PLUGIN_DIR="$HOME/Library/Application Support/SwiftBar/Plugins"
LOCAL_BIN="$HOME/.local/bin"
LAUNCH_AGENTS="$HOME/Library/LaunchAgents"
PLIST_NAME="com.claude.usage-fetch"
SRC_DIR="${CLAUDE_PLUGIN_ROOT}/scripts/claude-monitor"
REFRESH_INTERVAL=180

# Skip if plugin root not set
if [ -z "$CLAUDE_PLUGIN_ROOT" ] || [ ! -d "$SRC_DIR" ]; then
  exit 0
fi

# Skip if already installed (SwiftBar plugin exists)
if ls "$PLUGIN_DIR"/claude-usage.*.sh &>/dev/null 2>&1; then
  exit 0
fi

# --- Install ---

# 1. Check jq
if ! command -v jq &>/dev/null; then
  if command -v brew &>/dev/null; then
    brew install jq 2>/dev/null
  else
    exit 0  # Can't install without brew, skip silently
  fi
fi

# 2. Install SwiftBar if needed
if [ ! -d "/Applications/SwiftBar.app" ] && [ ! -d "$HOME/Applications/SwiftBar.app" ]; then
  if command -v brew &>/dev/null; then
    brew install --cask swiftbar 2>/dev/null
  else
    exit 0
  fi
fi

# 3. Create directories
mkdir -p "$PLUGIN_DIR" "$LOCAL_BIN" "$LAUNCH_AGENTS"

# 4. Install fetcher
cp "$SRC_DIR/claude-usage-fetch.sh" "$LOCAL_BIN/claude-usage-fetch.sh"
chmod +x "$LOCAL_BIN/claude-usage-fetch.sh"

# 5. Install SwiftBar plugin
rm -f "$PLUGIN_DIR"/claude-usage.*.sh 2>/dev/null
cp "$SRC_DIR/claude-usage.3m.sh" "$PLUGIN_DIR/claude-usage.5s.sh"
chmod +x "$PLUGIN_DIR/claude-usage.5s.sh"

# 6. Install launchd agent
launchctl unload "$LAUNCH_AGENTS/$PLIST_NAME.plist" 2>/dev/null || true

cat > "$LAUNCH_AGENTS/$PLIST_NAME.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$PLIST_NAME</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>$LOCAL_BIN/claude-usage-fetch.sh</string>
    </array>
    <key>StartInterval</key>
    <integer>$REFRESH_INTERVAL</integer>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/claude-usage-fetch.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/claude-usage-fetch.log</string>
</dict>
</plist>
PLIST

launchctl load "$LAUNCH_AGENTS/$PLIST_NAME.plist" 2>/dev/null

# 7. Start SwiftBar
defaults write com.ameba.SwiftBar PluginDirectory "$PLUGIN_DIR" 2>/dev/null
open -a SwiftBar 2>/dev/null

cat <<'EOF'
{
  "systemMessage": "[lean-flow] Claude Usage Monitor installed: SwiftBar plugin + fetcher daemon (every 3min). Check your menu bar for usage stats."
}
EOF

exit 0
