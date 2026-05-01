#!/usr/bin/env bash
# lean-preset.sh — switch lean-flow model preset.
#
# Adapted (concept only) from oh-my-opencode-slim's runtime preset system.
# Swaps the ANTHROPIC_DEFAULT_HAIKU_MODEL / ANTHROPIC_DEFAULT_SONNET_MODEL /
# ANTHROPIC_DEFAULT_OPUS_MODEL env vars in ~/.claude/settings.json based on
# named profiles, without rewriting agent frontmatter.
#
# Built-in profiles:
#   balanced (default) — haiku 4.5 + sonnet 4.6 + opus 4.7
#   cheap              — haiku 4.5 everywhere (fixer + sonnet roles drop to haiku)
#   powerful           — sonnet 4.6 + opus 4.7 (no haiku)
#   thinking           — opus 4.7 across all roles (max quality, max cost)
#
# Usage:
#   lean-preset.sh                   # show current preset + available
#   lean-preset.sh <profile-name>    # switch to a profile
#   lean-preset.sh --custom-file <path-to-preset.json>
#
# Custom presets live at ~/.claude/lean-flow-presets.json:
#   {
#     "myteam": {
#       "haiku":  "claude-haiku-4-5-20251001",
#       "sonnet": "claude-sonnet-4-6",
#       "opus":   "claude-opus-4-7"
#     }
#   }

set -uo pipefail

SETTINGS="${HOME}/.claude/settings.json"
CUSTOM_PRESETS="${HOME}/.claude/lean-flow-presets.json"

if [ ! -f "$SETTINGS" ] || ! command -v jq &>/dev/null; then
  echo "[lean-preset] requires ~/.claude/settings.json and jq" >&2
  exit 1
fi

# ── Built-in presets ─────────────────────────────────────────────────────
profile_resolve() {
  local name="$1"
  case "$name" in
    balanced)
      echo 'claude-haiku-4-5-20251001|claude-sonnet-4-6|claude-opus-4-7' ;;
    cheap)
      echo 'claude-haiku-4-5-20251001|claude-haiku-4-5-20251001|claude-haiku-4-5-20251001' ;;
    powerful)
      echo 'claude-sonnet-4-6|claude-sonnet-4-6|claude-opus-4-7' ;;
    thinking)
      echo 'claude-opus-4-7|claude-opus-4-7|claude-opus-4-7' ;;
    *)
      # Fall back to custom-presets file
      if [ -f "$CUSTOM_PRESETS" ]; then
        jq -r --arg n "$name" '.[$n] // empty | "\(.haiku)|\(.sonnet)|\(.opus)"' "$CUSTOM_PRESETS"
      else
        echo ""
      fi
      ;;
  esac
}

# ── No-arg form: show status ────────────────────────────────────────────
if [ "$#" -eq 0 ]; then
  current_haiku=$(jq -r '.env.ANTHROPIC_DEFAULT_HAIKU_MODEL // "(unset)"' "$SETTINGS")
  current_sonnet=$(jq -r '.env.ANTHROPIC_DEFAULT_SONNET_MODEL // "(unset)"' "$SETTINGS")
  current_opus=$(jq -r '.env.ANTHROPIC_DEFAULT_OPUS_MODEL // "(unset)"' "$SETTINGS")
  echo "[lean-preset] current settings:"
  echo "  haiku  → $current_haiku"
  echo "  sonnet → $current_sonnet"
  echo "  opus   → $current_opus"
  echo ""
  echo "Built-in presets: balanced | cheap | powerful | thinking"
  if [ -f "$CUSTOM_PRESETS" ]; then
    echo "Custom presets:"
    jq -r 'keys[]' "$CUSTOM_PRESETS" 2>/dev/null | sed 's/^/  - /'
  fi
  echo ""
  echo "Switch:  lean-preset.sh <profile>"
  exit 0
fi

PROFILE="$1"
RESOLVED=$(profile_resolve "$PROFILE")

if [ -z "$RESOLVED" ] || [ "$RESOLVED" = "||" ]; then
  echo "[lean-preset] unknown profile: $PROFILE" >&2
  echo "Built-in: balanced, cheap, powerful, thinking" >&2
  exit 1
fi

IFS='|' read -r haiku_model sonnet_model opus_model <<< "$RESOLVED"

# ── Update settings.json atomically ─────────────────────────────────────
tmp=$(mktemp)
jq --arg h "$haiku_model" --arg s "$sonnet_model" --arg o "$opus_model" '
  .env.ANTHROPIC_DEFAULT_HAIKU_MODEL  = $h
  | .env.ANTHROPIC_DEFAULT_SONNET_MODEL = $s
  | .env.ANTHROPIC_DEFAULT_OPUS_MODEL   = $o
' "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"

echo "[lean-preset] switched to '$PROFILE':"
echo "  haiku  → $haiku_model"
echo "  sonnet → $sonnet_model"
echo "  opus   → $opus_model"
echo ""
echo "Restart Claude Code session to apply (env is read at startup)."
