#!/bin/bash

# Claude Code Usage Monitor for SwiftBar — direct fetch, no cache
# Reads OAuth token from macOS keychain on every tick and queries
# api.anthropic.com/api/oauth/usage. Output matches claude.ai/settings/usage.

SELF_PATH=$(ls "$HOME/Library/Application Support/SwiftBar/Plugins/claude-usage."*.sh 2>/dev/null | head -1)

# --- Handle commands from menu actions ---
[ "$1" = "noop" ] && exit 0

# Read OAuth access token from keychain
TOKEN=$(security find-generic-password -s 'Claude Code-credentials' -w 2>/dev/null | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null)

if [ -z "$TOKEN" ]; then
  echo "☁️ no-auth | color=#888888"
  echo "---"
  echo "Claude OAuth token not found in keychain"
  exit 0
fi

# Fetch usage live
RESP=$(curl -sS --max-time 8 \
  "https://api.anthropic.com/api/oauth/usage" \
  -H "authorization: Bearer $TOKEN" \
  -H "anthropic-beta: oauth-2025-04-20" \
  -H "anthropic-version: 2023-06-01" 2>/dev/null)

if [ -z "$RESP" ] || ! echo "$RESP" | jq -e . >/dev/null 2>&1; then
  echo "☁️ --% | color=#888888"
  echo "---"
  echo "Fetch failed | color=red"
  echo "Refresh | bash='$SELF_PATH' terminal=false refresh=true"
  exit 0
fi

# ISO timestamp → "3pm" / "11:30am" / "1d"
_format_reset() {
  local iso="$1"
  [ -z "$iso" ] || [ "$iso" = "null" ] && echo "?" && return
  local epoch today_end diff_days
  epoch=$(date -juf "%Y-%m-%dT%H:%M:%S" "${iso%%.*}" +%s 2>/dev/null)
  [ -z "$epoch" ] && echo "?" && return
  today_end=$(date -j -v23H -v59M -v59S +%s)
  diff_days=$(( (epoch - today_end) / 86400 ))
  if [ "$epoch" -le "$today_end" ]; then
    local h m ampm
    h=$(date -jr "$epoch" +%-I)
    m=$(date -jr "$epoch" +%M)
    ampm=$(date -jr "$epoch" +%p | tr '[:upper:]' '[:lower:]')
    if [ "$m" = "00" ]; then echo "${h}${ampm}"; else echo "${h}:${m}${ampm}"; fi
  else
    echo "$(( diff_days + 1 ))d"
  fi
}

to_pct() {
  local v="$1"
  if [ -z "$v" ] || [ "$v" = "null" ]; then echo "-"; return; fi
  awk -v v="$v" 'BEGIN { printf "%d", v + 0.5 }'
}

session_pct=$(to_pct "$(echo "$RESP" | jq -r '.five_hour.utilization // empty')")
week_all_pct=$(to_pct "$(echo "$RESP" | jq -r '.seven_day.utilization // empty')")
week_sonnet_pct=$(to_pct "$(echo "$RESP" | jq -r '.seven_day_sonnet.utilization // empty')")
week_opus_pct=$(to_pct "$(echo "$RESP" | jq -r '.seven_day_opus.utilization // empty')")
session_reset=$(_format_reset "$(echo "$RESP" | jq -r '.five_hour.resets_at // empty')")
week_all_reset=$(_format_reset "$(echo "$RESP" | jq -r '.seven_day.resets_at // empty')")
week_sonnet_reset=$(_format_reset "$(echo "$RESP" | jq -r '.seven_day_sonnet.resets_at // empty')")

# Color based on highest numeric usage
max_pct=0
for p in "$session_pct" "$week_all_pct" "$week_sonnet_pct"; do
  [[ "$p" =~ ^[0-9]+$ ]] && [ "$p" -gt "$max_pct" ] && max_pct=$p
done
if   [ "$max_pct" -ge 80 ]; then icon="🔴"
elif [ "$max_pct" -ge 50 ]; then icon="🟡"
else icon="🟢"; fi

# --- Title bar ---
display="${session_pct}%(${session_reset})┊${week_all_pct}%(${week_all_reset})┊${week_sonnet_pct}%(${week_sonnet_reset})"
echo "$icon $display | color=white"

# --- Dropdown ---
echo "---"
echo "Claude Code Usage | size=14 bash='$SELF_PATH' param1=noop terminal=false"
echo "---"
echo "Session (5h):    ${session_pct}% — resets ${session_reset} | bash='$SELF_PATH' param1=noop terminal=false"
echo "Week (all):      ${week_all_pct}% — resets ${week_all_reset} | bash='$SELF_PATH' param1=noop terminal=false"
echo "Week (sonnet):   ${week_sonnet_pct}% — resets ${week_sonnet_reset} | bash='$SELF_PATH' param1=noop terminal=false"
[ "$week_opus_pct" != "-" ] && echo "Week (opus):     ${week_opus_pct}% | bash='$SELF_PATH' param1=noop terminal=false"
echo "---"
echo "Updated: $(date '+%H:%M:%S') | size=11 color=#888888"
echo "Source: api.anthropic.com/api/oauth/usage | size=10 color=#666666"
echo "Refresh now | bash='$SELF_PATH' terminal=false refresh=true"
