#!/usr/bin/env bash
# Ensure companion plugins (superpowers, caveman) are configured.
# Each plugin is auto-enabled only if its key is ABSENT from enabledPlugins.
# If the user has explicitly set a plugin to false, this script respects that choice.
# Runs on SessionStart — idempotent.
# NOTE: Uses plain jq conditionals, not bash associative arrays (macOS bash 3.2 compat).
#
# plan-plus auto-enable was removed: superpowers:writing-plans + executing-plans
# are now the canonical planning system. Users who still want plan-plus can enable
# it manually via the marketplace.

SETTINGS_FILE="${HOME}/.gemini/settings.json"

if [ ! -f "$SETTINGS_FILE" ] || ! command -v jq &>/dev/null; then
  exit 0
fi

sp_added=false
cav_added=false

# Skip entirely if user opted out of caveman
LEAN_FLOW_ENABLE_CAVEMAN="${LEAN_FLOW_ENABLE_CAVEMAN:-true}"

# Enable superpowers plugin (only if key is absent)
if ! jq -e '.enabledPlugins | has("superpowers@claude-plugins-official")' "$SETTINGS_FILE" &>/dev/null; then
  tmp=$(mktemp)
  jq '.enabledPlugins["superpowers@claude-plugins-official"] = true' "$SETTINGS_FILE" > "$tmp" && mv "$tmp" "$SETTINGS_FILE"
  sp_added=true
fi

# Enable caveman plugin (gated by env, only if key is absent)
if [ "$LEAN_FLOW_ENABLE_CAVEMAN" = "true" ]; then
  if ! jq -e '.enabledPlugins | has("caveman@caveman")' "$SETTINGS_FILE" &>/dev/null; then
    tmp=$(mktemp)
    jq '.enabledPlugins["caveman@caveman"] = true' "$SETTINGS_FILE" > "$tmp" && mv "$tmp" "$SETTINGS_FILE"
    cav_added=true
  fi
fi

# Dynamic message based on which plugins were newly enabled
if [ "$sp_added" = true ] && [ "$cav_added" = true ]; then
  MSG="Companion plugins enabled: superpowers (skills & workflows), caveman (token-compressed mode). Will be active on next session start."
elif [ "$sp_added" = true ]; then
  MSG="Companion plugin enabled: superpowers (skills & workflows). Will be active on next session start."
elif [ "$cav_added" = true ]; then
  MSG="Companion plugin enabled: caveman (token-compressed mode). Will be active on next session start. To disable: set LEAN_FLOW_ENABLE_CAVEMAN=false or set enabledPlugins.\"caveman@caveman\" to false in ~/.gemini/settings.json."
fi

if [ -n "${MSG:-}" ]; then
  cat <<EOF
{
  "systemMessage": "[lean-flow] $MSG"
}
EOF
fi

exit 0
