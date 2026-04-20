#!/usr/bin/env bash
# Uninstall lean-flow — reverses everything the ensure-*.sh scripts install.
# Idempotent: skips items that don't exist.

set -euo pipefail

removed=()
skipped=()

_remove_file() {
  local label="$1" path="$2"
  if [ -e "$path" ]; then
    rm -f "$path"
    removed+=("$label: $path")
  else
    skipped+=("$label (not found)")
  fi
}

_remove_dir() {
  local label="$1" path="$2"
  if [ -d "$path" ]; then
    rm -rf "$path"
    removed+=("$label: $path")
  else
    skipped+=("$label (not found)")
  fi
}

echo "lean-flow uninstaller"
echo "====================="
echo ""

# 1. Remove knowledge MCP server files
_remove_dir "Knowledge MCP server files" "${HOME}/.claude/mcp-servers/knowledge"

# 2. Deregister MCP servers
if command -v claude &>/dev/null; then
  if claude mcp list 2>/dev/null | grep -q "^knowledge:"; then
    claude mcp remove knowledge 2>/dev/null && removed+=("MCP: knowledge deregistered") || true
  else
    skipped+=("MCP knowledge (not registered)")
  fi

  if claude mcp list 2>/dev/null | grep -q "^playwright:"; then
    claude mcp remove playwright 2>/dev/null && removed+=("MCP: playwright deregistered") || true
  else
    skipped+=("MCP playwright (not registered)")
  fi
else
  skipped+=("MCP deregistration (claude CLI not found)")
fi

# 3. Remove SwiftBar plugin
SWIFTBAR_PLUGIN_PATTERN="$HOME/Library/Application Support/SwiftBar/Plugins/claude-usage.*.sh"
# Use eval to expand glob safely
shopt -s nullglob
swiftbar_files=("$HOME/Library/Application Support/SwiftBar/Plugins"/claude-usage.*.sh)
shopt -u nullglob

if [ ${#swiftbar_files[@]} -gt 0 ]; then
  for f in "${swiftbar_files[@]}"; do
    rm -f "$f"
    removed+=("SwiftBar plugin: $f")
  done
else
  skipped+=("SwiftBar plugin (not found)")
fi

# 4. Unload and remove launchd agent (both current and legacy names)
for _plist_name in "com.claude.usage-fetch" "com.${USER}.claude-usage-fetch"; do
  _plist_path="$HOME/Library/LaunchAgents/${_plist_name}.plist"
  if [ -f "$_plist_path" ]; then
    launchctl unload "$_plist_path" 2>/dev/null || true
    rm -f "$_plist_path"
    removed+=("launchd agent: $_plist_path")
  fi
done

# 5. Remove fetcher scripts
_remove_file "Usage fetcher" "${HOME}/.local/bin/claude-usage-fetch.sh"
_remove_file "Usage fetcher (real)" "${HOME}/.local/bin/claude-usage-fetch-real.sh"

# 6. Remove dream state
_remove_dir "Dream state" "${HOME}/.claude/dream-state"

# 7. Remove config
_remove_file "Config file" "${HOME}/.claude/lean-flow.json"

# 8. Print summary so far
echo "Removed:"
if [ ${#removed[@]} -eq 0 ]; then
  echo "  (nothing)"
else
  for item in "${removed[@]}"; do
    echo "  - $item"
  done
fi

echo ""
echo "Skipped (already absent):"
if [ ${#skipped[@]} -eq 0 ]; then
  echo "  (nothing)"
else
  for item in "${skipped[@]}"; do
    echo "  - $item"
  done
fi

echo ""

# 9. Prompt for knowledge DB deletion
DB_PATH="${HOME}/.claude/knowledge/patterns.db"
if [ -f "$DB_PATH" ]; then
  printf "Delete pattern database? This cannot be undone. [y/N] "
  read -r answer </dev/tty
  case "$answer" in
    [yY]|[yY][eE][sS])
      rm -f "$DB_PATH"
      # Remove parent dir if empty
      rmdir "${HOME}/.claude/knowledge" 2>/dev/null || true
      echo "Pattern database deleted."
      ;;
    *)
      echo "Pattern database kept at: $DB_PATH"
      ;;
  esac
else
  echo "Pattern database not found — nothing to delete."
fi

echo ""
echo "Note: settings.json permissions were not modified. Remove manually if needed."
echo "lean-flow uninstall complete."
