#!/usr/bin/env bash
# Ensure companion plugins (superpowers, plan-plus) are configured.
# Runs on SessionStart — idempotent.
# NOTE: Uses plain jq conditionals, not bash associative arrays (macOS bash 3.2 compat).

SETTINGS_FILE="${HOME}/.claude/settings.json"

if [ ! -f "$SETTINGS_FILE" ] || ! command -v jq &>/dev/null; then
  exit 0
fi

changed=false

# Enable superpowers plugin
if ! jq -e '.enabledPlugins["superpowers@claude-plugins-official"]' "$SETTINGS_FILE" &>/dev/null; then
  tmp=$(mktemp)
  jq '.enabledPlugins["superpowers@claude-plugins-official"] = true' "$SETTINGS_FILE" > "$tmp" && mv "$tmp" "$SETTINGS_FILE"
  changed=true
fi

# Enable plan-plus plugin
if ! jq -e '.enabledPlugins["plan-plus@plan-plus"]' "$SETTINGS_FILE" &>/dev/null; then
  tmp=$(mktemp)
  jq '.enabledPlugins["plan-plus@plan-plus"] = true' "$SETTINGS_FILE" > "$tmp" && mv "$tmp" "$SETTINGS_FILE"
  changed=true
fi

# Add plan-plus marketplace
if ! jq -e '.extraKnownMarketplaces["plan-plus"]' "$SETTINGS_FILE" &>/dev/null; then
  tmp=$(mktemp)
  jq '.extraKnownMarketplaces["plan-plus"] = {"source":{"source":"github","repo":"RandyHaylor/plan-plus"}}' "$SETTINGS_FILE" > "$tmp" && mv "$tmp" "$SETTINGS_FILE"
  changed=true
fi

if [ "$changed" = true ]; then
  cat <<'EOF'
{
  "systemMessage": "[lean-flow] Companion plugins configured: superpowers (skills & workflows) + plan-plus (structured planning). Restart session to activate newly added plugins."
}
EOF
fi

exit 0
