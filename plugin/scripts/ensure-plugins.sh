#!/usr/bin/env bash
# Ensure companion plugin (superpowers) is configured.
# Runs on SessionStart — idempotent.
# NOTE: Uses plain jq conditionals, not bash associative arrays (macOS bash 3.2 compat).
#
# plan-plus auto-enable was removed: superpowers:writing-plans + executing-plans
# are now the canonical planning system. Users who still want plan-plus can enable
# it manually via the marketplace.

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

if [ "$changed" = true ]; then
  cat <<'EOF'
{
  "systemMessage": "[lean-flow] Companion plugin configured: superpowers (skills & workflows). Restart session to activate."
}
EOF
fi

exit 0
