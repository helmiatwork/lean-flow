#!/bin/bash

# Claude Usage Fetcher — OAuth /api/oauth/usage (matches claude.ai dashboard)
# Reads OAuth token from macOS keychain, GETs api.anthropic.com/api/oauth/usage,
# returns the same numbers shown at claude.ai/settings/usage.

CACHE_FILE="/tmp/claude-usage-cache.json"
LOCK_FILE="/tmp/claude-usage-fetch.lock"
LOG_FILE="/tmp/claude-usage-fetch.log"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

_log() { echo "[$(date '+%H:%M:%S')] $*" >> "$LOG_FILE"; }

_merge_token_stats() {
  if command -v python3 &>/dev/null && [ -f "$SCRIPT_DIR/local-tokens.py" ]; then
    local stats tmp
    stats=$(python3 "$SCRIPT_DIR/local-tokens.py" "7d" 2>/tmp/lean-flow-token-debug.log)
    if [ -n "$stats" ] && echo "$stats" | jq . &>/dev/null && [ -f "$CACHE_FILE" ]; then
      tmp=$(mktemp)
      jq --argjson s "$stats" '. + {token_stats: $s}' "$CACHE_FILE" > "$tmp" && mv "$tmp" "$CACHE_FILE"
    fi
  fi
}

# Prevent concurrent runs
if [ -f "$LOCK_FILE" ]; then
  lock_age=$(( $(date +%s) - $(stat -f%m "$LOCK_FILE") ))
  if [ "$lock_age" -lt 30 ]; then
    exit 0
  fi
fi
echo $$ > "$LOCK_FILE"
trap "rm -f $LOCK_FILE" EXIT

# Read OAuth access token from keychain
TOKEN=$(security find-generic-password -s 'Claude Code-credentials' -w 2>/dev/null | jq -r '.claudeAiOauth.accessToken // empty')
if [ -z "$TOKEN" ]; then
  _log "ERROR: no OAuth token in keychain"
  exit 1
fi

# ISO timestamp → "3pm" / "11:30am" / "1d" style, local TZ
_format_reset() {
  local iso="$1"
  [ -z "$iso" ] || [ "$iso" = "null" ] && echo "?" && return
  local epoch
  # Strip fractional seconds and trailing zone suffix variants
  epoch=$(date -juf "%Y-%m-%dT%H:%M:%S" "${iso%%.*}" +%s 2>/dev/null)
  [ -z "$epoch" ] && echo "?" && return
  local today_end diff_days
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

# Hit OAuth usage endpoint — same data as claude.ai/settings/usage
RESP_FILE=$(mktemp)
http_code=$(curl -sS -o "$RESP_FILE" -w '%{http_code}' \
  "https://api.anthropic.com/api/oauth/usage" \
  -H "authorization: Bearer $TOKEN" \
  -H "anthropic-beta: oauth-2025-04-20" \
  -H "anthropic-version: 2023-06-01" \
  --max-time 15 2>>"$LOG_FILE")

if [ "$http_code" != "200" ]; then
  _log "API returned $http_code: $(head -c 200 "$RESP_FILE")"
  rm -f "$RESP_FILE"
  _merge_token_stats
  exit 0
fi

# Round 27.0 → 27, treat null as "-"
to_pct() {
  local v="$1"
  if [ -z "$v" ] || [ "$v" = "null" ]; then echo "-"; return; fi
  awk -v v="$v" 'BEGIN { printf "%d", v + 0.5 }'
}

session_pct=$(to_pct "$(jq -r '.five_hour.utilization // empty' "$RESP_FILE")")
week_all_pct=$(to_pct "$(jq -r '.seven_day.utilization // empty' "$RESP_FILE")")
week_sonnet_pct=$(to_pct "$(jq -r '.seven_day_sonnet.utilization // empty' "$RESP_FILE")")
session_reset=$(_format_reset "$(jq -r '.five_hour.resets_at // empty' "$RESP_FILE")")
week_all_reset=$(_format_reset "$(jq -r '.seven_day.resets_at // empty' "$RESP_FILE")")
week_sonnet_reset=$(_format_reset "$(jq -r '.seven_day_sonnet.resets_at // empty' "$RESP_FILE")")
rm -f "$RESP_FILE"

# Only write cache if we got numeric session + week
if [[ "$session_pct" =~ ^[0-9-]+$ ]] && [[ "$week_all_pct" =~ ^[0-9-]+$ ]]; then
  cat > "$CACHE_FILE" <<JSON
{"session": "$session_pct", "week_all": "$week_all_pct", "week_sonnet": "$week_sonnet_pct", "session_reset": "$session_reset", "week_all_reset": "$week_all_reset", "week_sonnet_reset": "$week_sonnet_reset", "updated": "$(date '+%H:%M')"}
JSON
  _merge_token_stats
  touch /tmp/claude-usage-blink
  open -g "swiftbar://refreshplugin?name=claude-usage" 2>/dev/null
  ( sleep 11 && open -g "swiftbar://refreshplugin?name=claude-usage" 2>/dev/null ) &
else
  _log "parse failed: util_5h=$util_5h util_7d=$util_7d"
  _merge_token_stats
fi
