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
REFRESH_INTERVAL=30

# Skip if plugin root not set
if [ -z "$CLAUDE_PLUGIN_ROOT" ] || [ ! -d "$SRC_DIR" ]; then
  exit 0
fi

# Skip if already installed (SwiftBar plugin exists)
if ls "$PLUGIN_DIR"/claude-usage.*.sh &>/dev/null 2>&1; then
  exit 0
fi

# --- Detect claude binary across all common install methods ---
detect_claude_bin() {
  # 1. Already in PATH (interactive shell)
  local found
  found=$(command -v claude 2>/dev/null)
  [ -n "$found" ] && echo "$found" && return

  # 2. Common direct locations
  for p in \
    "$HOME/.local/bin/claude" \
    "$HOME/.local/share/claude/claude" \
    "/usr/local/bin/claude" \
    "/opt/homebrew/bin/claude"; do
    [ -x "$p" ] && echo "$p" && return
  done

  # 3. nodenv
  if [ -d "$HOME/.nodenv/versions" ]; then
    for v in $(ls -r "$HOME/.nodenv/versions/" 2>/dev/null); do
      p="$HOME/.nodenv/versions/$v/bin/claude"
      [ -x "$p" ] && echo "$p" && return
    done
  fi

  # 4. nvm
  if [ -d "$HOME/.nvm/versions/node" ]; then
    for v in $(ls -r "$HOME/.nvm/versions/node/" 2>/dev/null); do
      p="$HOME/.nvm/versions/node/$v/bin/claude"
      [ -x "$p" ] && echo "$p" && return
    done
  fi

  # 5. n (tj/n)
  for p in "$HOME/n/bin/claude" "/usr/local/n/bin/claude"; do
    [ -x "$p" ] && echo "$p" && return
  done

  echo ""
}

CLAUDE_BIN=$(detect_claude_bin)
if [ -z "$CLAUDE_BIN" ]; then
  exit 0  # Claude not found — skip silently
fi

# --- Install ---

# 1. Check jq
if ! command -v jq &>/dev/null; then
  if command -v brew &>/dev/null; then
    brew install jq 2>/dev/null
  else
    exit 0
  fi
fi

# 2. Install SwiftBar if needed
SWIFTBAR_APP=""
[ -d "/Applications/SwiftBar.app" ] && SWIFTBAR_APP="/Applications/SwiftBar.app"
[ -d "$HOME/Applications/SwiftBar.app" ] && SWIFTBAR_APP="$HOME/Applications/SwiftBar.app"
if [ -z "$SWIFTBAR_APP" ]; then
  if command -v brew &>/dev/null; then
    brew install --cask swiftbar 2>/dev/null
    [ -d "/Applications/SwiftBar.app" ] && SWIFTBAR_APP="/Applications/SwiftBar.app"
  fi
  [ -z "$SWIFTBAR_APP" ] && exit 0
fi

# 3. Create directories
mkdir -p "$PLUGIN_DIR" "$LOCAL_BIN" "$LAUNCH_AGENTS"

# 4. Install fetcher
cp "$SRC_DIR/claude-usage-fetch.sh" "$LOCAL_BIN/claude-usage-fetch.sh"
chmod +x "$LOCAL_BIN/claude-usage-fetch.sh"

# 5. Install SwiftBar plugin
rm -f "$PLUGIN_DIR"/claude-usage.*.sh 2>/dev/null
cp "$SRC_DIR/claude-usage.30s.sh" "$PLUGIN_DIR/claude-usage.30s.sh"
chmod +x "$PLUGIN_DIR/claude-usage.30s.sh"

# 6. Install launchd agent with detected claude path + sane PATH
launchctl unload "$LAUNCH_AGENTS/$PLIST_NAME.plist" 2>/dev/null || true

LAUNCHD_PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$HOME/.local/bin:$(dirname "$CLAUDE_BIN")"

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
    <key>EnvironmentVariables</key>
    <dict>
        <key>CLAUDE_BIN</key>
        <string>$CLAUDE_BIN</string>
        <key>PATH</key>
        <string>$LAUNCHD_PATH</string>
        <key>HOME</key>
        <string>$HOME</string>
    </dict>
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

# 7. Set SwiftBar plugin directory and launch at login
defaults write com.ameba.SwiftBar PluginDirectory "$PLUGIN_DIR" 2>/dev/null
osascript -e "tell application \"System Events\" to make new login item at end with properties {name:\"SwiftBar\", path:\"$SWIFTBAR_APP\", hidden:false}" 2>/dev/null || true
open -a SwiftBar 2>/dev/null

cat <<'EOF'
{
  "systemMessage": "[lean-flow] Claude Usage Monitor installed: SwiftBar plugin + fetcher daemon (every 30s). Check your menu bar for usage stats."
}
EOF

exit 0
