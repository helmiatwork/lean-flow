#!/bin/bash

# Claude Usage Fetcher — reads OAuth token from keychain, hits API rate limit headers
# Uses the same "CLI Account" flow as Claude Usage Tracker app.

CACHE_FILE="/tmp/claude-usage-cache.json"
LOCK_FILE="/tmp/claude-usage-fetch.lock"

# Prevent concurrent runs
if [ -f "$LOCK_FILE" ]; then
  lock_age=$(( $(date +%s) - $(stat -f%m "$LOCK_FILE") ))
  [ "$lock_age" -lt 30 ] && exit 0
fi
echo $$ > "$LOCK_FILE"
trap "rm -f $LOCK_FILE" EXIT

# --- Get OAuth token from keychain ---
CREDS=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null)
[ -z "$CREDS" ] && exit 1

TOKEN=$(echo "$CREDS" | python3 -c "import sys,json; print(json.load(sys.stdin).get('claudeAiOauth',{}).get('accessToken',''))" 2>/dev/null)
[ -z "$TOKEN" ] && exit 1

# --- Minimal API call to get rate limit headers ---
HEADERS=$(curl -sS -D - -o /dev/null -X POST "https://api.anthropic.com/v1/messages" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -H "anthropic-version: 2023-06-01" \
  -H "anthropic-beta: oauth-2025-04-20" \
  -H "User-Agent: claude-code/2.1.5" \
  -d '{"model":"claude-haiku-4-5-20251001","max_tokens":1,"messages":[{"role":"user","content":"hi"}]}' \
  2>/dev/null)

# --- Parse rate limit headers ---
get_header() {
  echo "$HEADERS" | grep -i "^$1:" | sed 's/^[^:]*:[[:space:]]*//' | tr -d '\r'
}

session_util=$(get_header "anthropic-ratelimit-unified-5h-utilization")
session_reset_ts=$(get_header "anthropic-ratelimit-unified-5h-reset")
week_util=$(get_header "anthropic-ratelimit-unified-7d-utilization")
week_reset_ts=$(get_header "anthropic-ratelimit-unified-7d-reset")

# Convert utilization (0.0-1.0) to percentage
to_pct() {
  local val="$1"
  [ -z "$val" ] && echo "?" && return
  python3 -c "print(int(float('$val') * 100))" 2>/dev/null || echo "?"
}

# Convert epoch timestamp to remaining time
calc_remaining() {
  local ts="$1"
  [ -z "$ts" ] && echo "?" && return
  python3 -c "
from datetime import datetime, timezone
try:
    reset = datetime.fromtimestamp(float('$ts'), tz=timezone.utc)
    secs = int((reset - datetime.now(tz=timezone.utc)).total_seconds())
    if secs <= 0: print('now')
    elif secs < 3600: print(f'{secs // 60}m')
    elif secs < 86400: print(f'{secs // 3600}h{(secs % 3600) // 60}m')
    else: print(f'{secs // 86400}d')
except: print('?')
" 2>/dev/null || echo "?"
}

session_pct=$(to_pct "$session_util")
week_pct=$(to_pct "$week_util")
session_reset=$(calc_remaining "$session_reset_ts")
week_reset=$(calc_remaining "$week_reset_ts")

[ "$session_pct" = "0" ] && [ "$session_reset" = "?" ] && session_reset="-"
[ "$week_pct" = "0" ] && [ "$week_reset" = "?" ] && week_reset="-"

if [[ "$session_pct" =~ ^[0-9]+$ ]]; then
  cat > "$CACHE_FILE" << JSON
{"session":"$session_pct","week_all":"${week_pct:-?}","session_reset":"${session_reset:-?}","week_all_reset":"${week_reset:-?}","updated":"$(date '+%H:%M')"}
JSON
  touch /tmp/claude-usage-blink
  open -g "swiftbar://refreshplugin?name=claude-usage" 2>/dev/null
  ( sleep 11 && open -g "swiftbar://refreshplugin?name=claude-usage" 2>/dev/null ) &
fi
