#!/usr/bin/env bash
# Ensure GitNexus (codebase knowledge graph) is registered.
# Runs on SessionStart — idempotent.
#
# GitNexus indexes the current repo into a queryable graph and exposes it
# as an MCP server. Lean-flow's @explorer agent benefits when the index is
# fresh — it can ask graph queries instead of grepping every file.
# https://www.npmjs.com/package/gitnexus
#
# This bootstrap only handles MCP registration. Index updates remain a
# manual step (`npx gitnexus analyze`) because they can take minutes on
# large repos and shouldn't block session start.

source "$(dirname "$0")/load-config.sh" 2>/dev/null

LEAN_FLOW_ENABLE_GITNEXUS="${LEAN_FLOW_ENABLE_GITNEXUS:-true}"
[ "$LEAN_FLOW_ENABLE_GITNEXUS" = "false" ] && exit 0

# GitNexus runs via npx, so npm/npx must be available.
if ! command -v npx &>/dev/null; then
  exit 0
fi

CLAUDE_JSON="${HOME}/.gemini.json"
[ -f "$CLAUDE_JSON" ] || exit 0
command -v jq &>/dev/null || exit 0

# Skip if GitNexus MCP is already registered for this user.
if jq -e '.mcpServers // {} | to_entries[] | select(.key | test("gitnexus"; "i"))' "$CLAUDE_JSON" &>/dev/null; then
  exit 0
fi

# Skip if user already has GitNexus hooks wired in settings.json (custom integration).
SETTINGS_FILE="${HOME}/.gemini/settings.json"
if [ -f "$SETTINGS_FILE" ] && jq -e '.. | objects | select(.command? // "" | test("gitnexus"; "i"))' "$SETTINGS_FILE" &>/dev/null; then
  exit 0
fi

# Register GitNexus MCP entry. Atomic write via tmp file.
tmp=$(mktemp)
jq '.mcpServers["gitnexus"] = {
  "command": "npx",
  "args": ["-y", "gitnexus", "mcp"]
}' "$CLAUDE_JSON" > "$tmp" && mv "$tmp" "$CLAUDE_JSON"

cat <<'EOF'
{
  "systemMessage": "[lean-flow] GitNexus MCP registered. Run `npx gitnexus analyze` in your repo to build the index, then @explorer can query the codebase graph."
}
EOF

exit 0
