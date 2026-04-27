#!/bin/bash

# Claude Code Usage Monitor for SwiftBar — direct fetch with last-good cache
# Hits api.anthropic.com/api/oauth/usage on every tick. If the endpoint
# rate-limits us (or the network blips), shows the last successful values
# with a ⚠️ icon instead of going blank.

# SwiftBar runs plugins with a minimal PATH; add Homebrew so jq is findable
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

CACHE_FILE="$HOME/.cache/claude-usage-last-good.json"
SELF_PATH=$(ls "$HOME/Library/Application Support/SwiftBar/Plugins/claude-usage."*.sh 2>/dev/null | head -1)
mkdir -p "$(dirname "$CACHE_FILE")"

[ "$1" = "noop" ] && exit 0

TOKEN=$(security find-generic-password -s 'Claude Code-credentials' -w 2>/dev/null | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null)

if [ -z "$TOKEN" ]; then
  echo "☁️ no-auth | color=#888888"
  echo "---"
  echo "Claude OAuth token not found in keychain"
  exit 0
fi

# Fetch live
RESP=$(curl -sS --max-time 8 \
  "https://api.anthropic.com/api/oauth/usage" \
  -H "authorization: Bearer $TOKEN" \
  -H "anthropic-beta: oauth-2025-04-20" \
  -H "anthropic-version: 2023-06-01" 2>/dev/null)

# Detect API errors (rate_limit, auth, etc.)
api_err=""
if echo "$RESP" | jq -e '.error.type' >/dev/null 2>&1; then
  api_err=$(echo "$RESP" | jq -r '.error.type')
elif [ -z "$RESP" ] || ! echo "$RESP" | jq -e . >/dev/null 2>&1; then
  api_err="network_error"
fi

# On success, persist values; on failure, fall back to last-good cache
if [ -z "$api_err" ]; then
  echo "$RESP" > "$CACHE_FILE"
  source_resp="$RESP"
  status_line=""
elif [ -f "$CACHE_FILE" ]; then
  source_resp=$(cat "$CACHE_FILE")
  cache_age=$(( $(date +%s) - $(stat -f%m "$CACHE_FILE") ))
  status_line="⚠️ ${api_err} — showing cache (${cache_age}s old)"
else
  echo "⚠️ ${api_err} | color=orange"
  echo "---"
  echo "API error: ${api_err}"
  echo "No cached values yet. Try again later."
  echo "Refresh now | bash='$SELF_PATH' terminal=false refresh=true"
  exit 0
fi

# ISO → "3pm" / "1d"
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

session_pct=$(to_pct "$(echo "$source_resp" | jq -r '.five_hour.utilization // empty')")
week_all_pct=$(to_pct "$(echo "$source_resp" | jq -r '.seven_day.utilization // empty')")
week_sonnet_pct=$(to_pct "$(echo "$source_resp" | jq -r '.seven_day_sonnet.utilization // empty')")
week_opus_pct=$(to_pct "$(echo "$source_resp" | jq -r '.seven_day_opus.utilization // empty')")
session_reset=$(_format_reset "$(echo "$source_resp" | jq -r '.five_hour.resets_at // empty')")
week_all_reset=$(_format_reset "$(echo "$source_resp" | jq -r '.seven_day.resets_at // empty')")
week_sonnet_reset=$(_format_reset "$(echo "$source_resp" | jq -r '.seven_day_sonnet.resets_at // empty')")

# Color
max_pct=0
for p in "$session_pct" "$week_all_pct" "$week_sonnet_pct"; do
  [[ "$p" =~ ^[0-9]+$ ]] && [ "$p" -gt "$max_pct" ] && max_pct=$p
done
if [ -n "$api_err" ]; then icon="⚠️"
elif [ "$max_pct" -ge 80 ]; then icon="🔴"
elif [ "$max_pct" -ge 50 ]; then icon="🟡"
else icon="🟢"; fi

# Title bar
display="${session_pct}%(${session_reset})┊${week_all_pct}%(${week_all_reset})┊${week_sonnet_pct}%(${week_sonnet_reset})"
echo "$icon $display | color=white"

# Dropdown
echo "---"
echo "Claude Code Usage | size=14 bash='$SELF_PATH' param1=noop terminal=false"
echo "---"
echo "Session (5h):    ${session_pct}% — resets ${session_reset} | bash='$SELF_PATH' param1=noop terminal=false"
echo "Week (all):      ${week_all_pct}% — resets ${week_all_reset} | bash='$SELF_PATH' param1=noop terminal=false"
echo "Week (sonnet):   ${week_sonnet_pct}% — resets ${week_sonnet_reset} | bash='$SELF_PATH' param1=noop terminal=false"
[ "$week_opus_pct" != "-" ] && echo "Week (opus):     ${week_opus_pct}% | bash='$SELF_PATH' param1=noop terminal=false"
echo "---"
[ -n "$status_line" ] && echo "$status_line | color=orange size=11"
echo "Updated: $(date '+%H:%M:%S') | size=11 color=#888888"
echo "Source: api.anthropic.com/api/oauth/usage | size=10 color=#666666"
echo "Refresh now | bash='$SELF_PATH' terminal=false refresh=true"
