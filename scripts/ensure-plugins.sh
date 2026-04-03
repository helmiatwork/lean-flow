#!/usr/bin/env bash
# Ensure companion plugins (superpowers, plan-plus) are configured.
# Runs on SessionStart — idempotent.

SETTINGS_FILE="${HOME}/.claude/settings.json"

if [ ! -f "$SETTINGS_FILE" ] || ! command -v jq &>/dev/null; then
  exit 0
fi

changed=false

# Required plugins
declare -A PLUGINS=(
  ["superpowers@claude-plugins-official"]="true"
  ["plan-plus@plan-plus"]="true"
)

# Required marketplaces
declare -A MARKETPLACES=(
  ["plan-plus"]='{"source":{"source":"github","repo":"RandyHaylor/plan-plus"}}'
)

# Enable plugins
for plugin in "${!PLUGINS[@]}"; do
  if ! jq -e --arg p "$plugin" '.enabledPlugins[$p]' "$SETTINGS_FILE" &>/dev/null; then
    tmp=$(mktemp)
    jq --arg p "$plugin" '.enabledPlugins[$p] = true' "$SETTINGS_FILE" > "$tmp" && mv "$tmp" "$SETTINGS_FILE"
    changed=true
  fi
done

# Add marketplaces
for name in "${!MARKETPLACES[@]}"; do
  if ! jq -e --arg n "$name" '.extraKnownMarketplaces[$n]' "$SETTINGS_FILE" &>/dev/null; then
    tmp=$(mktemp)
    jq --arg n "$name" --argjson v "${MARKETPLACES[$name]}" '.extraKnownMarketplaces[$n] = $v' "$SETTINGS_FILE" > "$tmp" && mv "$tmp" "$SETTINGS_FILE"
    changed=true
  fi
done

if [ "$changed" = true ]; then
  cat <<'EOF'
{
  "systemMessage": "[lean-flow] Companion plugins configured: superpowers (skills & workflows) + plan-plus (structured planning). Restart session to activate newly added plugins."
}
EOF
fi

exit 0
