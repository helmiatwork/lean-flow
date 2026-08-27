#!/usr/bin/env bash
# Ensure OMNI (CLI output distiller) is installed and initialized.
# Runs on SessionStart — idempotent.
#
# OMNI sits in front of Bash tool calls and trims noisy output before it
# reaches the model. Validated savings: ~93% on common dev commands.
# https://github.com/fajarhide/omni
#
# Mirrors the ensure-rtk.sh pattern: detect → auto-install via brew →
# initialize hooks via `omni init` → record outcome.

source "$(dirname "$0")/load-config.sh" 2>/dev/null

# Honor LEAN_FLOW_ENABLE_OMNI=false in ~/.gemini/lean-flow.json to opt out.
LEAN_FLOW_ENABLE_OMNI="${LEAN_FLOW_ENABLE_OMNI:-true}"
[ "$LEAN_FLOW_ENABLE_OMNI" = "false" ] && exit 0

# Install OMNI if not present (brew is the official channel on macOS).
if ! command -v omni &>/dev/null; then
  if command -v brew &>/dev/null; then
    brew install omni &>/dev/null
  else
    cat <<'EOF'
{
  "systemMessage": "[lean-flow] OMNI not installed and brew unavailable. Install manually: visit https://github.com/fajarhide/omni"
}
EOF
    exit 0
  fi

  if ! command -v omni &>/dev/null; then
    cat <<'EOF'
{
  "systemMessage": "[lean-flow] OMNI auto-install via brew failed. Install manually: brew install omni"
}
EOF
    exit 0
  fi
fi

# If OMNI's hooks are already registered in user settings, nothing to do.
SETTINGS_FILE="${HOME}/.gemini/settings.json"
if [ -f "$SETTINGS_FILE" ] && command -v jq &>/dev/null; then
  if jq -e '.. | objects | select(.command? // "" | test("omni"))' "$SETTINGS_FILE" &>/dev/null; then
    exit 0
  fi
fi

# Run `omni init` non-interactively to register PreToolUse, PostToolUse,
# SessionStart, and PreCompact hooks plus MCP server in ~/.gemini.json.
yes 2>/dev/null | omni init --all &>/dev/null

cat <<'EOF'
{
  "systemMessage": "[lean-flow] OMNI initialized — Bash tool output will be distilled (~93% token savings on noisy commands). Run `omni stats` to see savings."
}
EOF

exit 0
