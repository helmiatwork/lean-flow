#!/bin/bash

# Claude Usage Monitor — One-Click Installer
# Double-click this file to install everything.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_DIR="$HOME/Library/Application Support/SwiftBar/Plugins"
LOCAL_BIN="$HOME/.local/bin"
LAUNCH_AGENTS="$HOME/Library/LaunchAgents"
LEGACY_FETCH_PLIST="com.claude.usage-fetch"
SWIFTBAR_PLIST_NAME="com.ameba.SwiftBar"
SWIFTBAR_INTERVAL="3m"

echo "=== Claude Usage Monitor Installer ==="
echo ""

# 1. Check dependencies
echo "[1/8] Checking dependencies..."

if ! command -v jq &>/dev/null; then
  echo "  jq not found. Installing via Homebrew..."
  if command -v brew &>/dev/null; then
    brew install jq
  else
    echo "  ERROR: jq is required but Homebrew is not installed."
    echo "  Install Homebrew first: https://brew.sh"
    exit 1
  fi
else
  echo "  jq: OK"
fi

if ! command -v claude &>/dev/null && [ ! -f "$LOCAL_BIN/claude" ]; then
  echo "  ERROR: Claude Code CLI not found. Install it first."
  exit 1
else
  echo "  claude: OK"
fi

# 2. Install SwiftBar if needed
echo "[2/8] Checking SwiftBar..."
if [ ! -d "/Applications/SwiftBar.app" ] && [ ! -d "$HOME/Applications/SwiftBar.app" ]; then
  echo "  SwiftBar not found. Installing via Homebrew..."
  if command -v brew &>/dev/null; then
    brew install --cask swiftbar
  else
    echo "  ERROR: SwiftBar is required but Homebrew is not installed."
    exit 1
  fi
else
  echo "  SwiftBar: OK"
fi

# 3. Create directories
echo "[3/8] Creating directories..."
mkdir -p "$PLUGIN_DIR"
mkdir -p "$LOCAL_BIN"
mkdir -p "$LAUNCH_AGENTS"
echo "  Done"

# 4. Remove legacy fetcher daemon + cache (no longer needed; plugin fetches directly)
echo "[4/6] Removing legacy fetcher daemon..."
launchctl unload "$LAUNCH_AGENTS/$LEGACY_FETCH_PLIST.plist" 2>/dev/null || true
rm -f "$LAUNCH_AGENTS/$LEGACY_FETCH_PLIST.plist"
rm -f "$LOCAL_BIN/claude-usage-fetch-real.sh" "$LOCAL_BIN/claude-usage-fetch.sh"
rm -f /tmp/claude-usage-cache.json /tmp/claude-usage-fetch.lock /tmp/claude-usage-blink
echo "  Done"

# 5. Install SwiftBar plugin (fetches /api/oauth/usage directly every 3 minutes)
echo "[5/6] Installing SwiftBar plugin..."
rm -f "$PLUGIN_DIR"/claude-usage.*.sh
ln -sf "$SCRIPT_DIR/claude-usage.3m.sh" "$PLUGIN_DIR/claude-usage.${SWIFTBAR_INTERVAL}.sh"
echo "  Symlinked as claude-usage.${SWIFTBAR_INTERVAL}.sh"

# 6. Harden SwiftBar against URL-restore crash (macOS 26.x Tahoe)
echo "[6/6] Hardening SwiftBar (disable state restore, install KeepAlive agent)..."
# Kill any running instance so the LaunchAgent owns the process
pkill -9 SwiftBar 2>/dev/null || true
# Disable AppKit state restoration — crash root cause is _handleAEGetURLEvent
# replaying a stale URL from saved state.
defaults write com.ameba.SwiftBar NSQuitAlwaysKeepsWindows -bool false
rm -rf "$HOME/Library/Saved Application State/com.ameba.SwiftBar.savedState"
# Pin plugin directory before first launch
defaults write com.ameba.SwiftBar PluginDirectory "$PLUGIN_DIR"

# Unload existing SwiftBar LaunchAgent if present
launchctl unload "$LAUNCH_AGENTS/$SWIFTBAR_PLIST_NAME.plist" 2>/dev/null || true

SWIFTBAR_BIN=""
if [ -x "/Applications/SwiftBar.app/Contents/MacOS/SwiftBar" ]; then
  SWIFTBAR_BIN="/Applications/SwiftBar.app/Contents/MacOS/SwiftBar"
elif [ -x "$HOME/Applications/SwiftBar.app/Contents/MacOS/SwiftBar" ]; then
  SWIFTBAR_BIN="$HOME/Applications/SwiftBar.app/Contents/MacOS/SwiftBar"
fi

cat > "$LAUNCH_AGENTS/$SWIFTBAR_PLIST_NAME.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$SWIFTBAR_PLIST_NAME</string>
    <key>ProgramArguments</key>
    <array>
        <string>$SWIFTBAR_BIN</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>ProcessType</key>
    <string>Interactive</string>
    <key>ThrottleInterval</key>
    <integer>10</integer>
    <key>StandardOutPath</key>
    <string>/tmp/swiftbar.out.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/swiftbar.err.log</string>
</dict>
</plist>
PLIST
echo "  Installed $SWIFTBAR_PLIST_NAME (KeepAlive, throttle 10s)"

launchctl load "$LAUNCH_AGENTS/$SWIFTBAR_PLIST_NAME.plist"
echo "  SwiftBar started (managed by launchd)"

echo ""
echo "=== Installation Complete ==="
echo ""
echo "  Menu bar plugin: claude-usage.${SWIFTBAR_INTERVAL}.sh"
echo "  Source:          api.anthropic.com/api/oauth/usage (live, no cache)"
echo "  Refresh:         every 3 minutes (set by filename suffix)"
echo ""
echo "First data appears within seconds. Press any key to close..."
read -n 1
