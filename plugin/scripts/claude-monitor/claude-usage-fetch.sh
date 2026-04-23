#!/bin/bash

# Claude Usage Fetcher — direct API rate-limit headers (no TTY, no subprocess)
# Reads OAuth token from macOS keychain, POSTs minimal request to api.anthropic.com,
# parses anthropic-ratelimit-unified-* response headers.

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

# Epoch → "3pm" / "Apr 29" style, local TZ
_format_reset() {
  local epoch="$1"
  [ -z "$epoch" ] || [ "$epoch" = "null" ] && echo "?" && return
  local now today_end reset_day diff_days
  now=$(date +%s)
  today_end=$(date -j -v23H -v59M -v59S +%s)
  diff_days=$(( (epoch - today_end) / 86400 ))
  if [ "$epoch" -le "$today_end" ]; then
    # Same day — show time like "3pm" or "11:30am"
    local h m ampm
    h=$(date -jr "$epoch" +%-I)
    m=$(date -jr "$epoch" +%M)
    ampm=$(date -jr "$epoch" +%p | tr '[:upper:]' '[:lower:]')
    if [ "$m" = "00" ]; then
      echo "${h}${ampm}"
    else
      echo "${h}:${m}${ampm}"
    fi
  else
    echo "$(( diff_days + 1 ))d"
  fi
}

# Hit API with minimal payload — only headers matter
HEADERS_FILE=$(mktemp)
http_code=$(curl -sS -o /dev/null -D "$HEADERS_FILE" -w '%{http_code}' -X POST https://api.anthropic.com/v1/messages \
  -H "authorization: Bearer $TOKEN" \
  -H "anthropic-beta: oauth-2025-04-20" \
  -H "anthropic-version: 2023-06-01" \
  -H "content-type: application/json" \
  --max-time 15 \
  -d '{"model":"claude-haiku-4-5-20251001","max_tokens":1,"messages":[{"role":"user","content":"."}]}' 2>>"$LOG_FILE")

if [ "$http_code" != "200" ] && [ "$http_code" != "429" ]; then
  _log "API returned $http_code"
  rm -f "$HEADERS_FILE"
  _merge_token_stats
  exit 0
fi

# Parse headers (case-insensitive)
get_header() { grep -i "^$1:" "$HEADERS_FILE" | tail -1 | sed "s/^[^:]*:[[:space:]]*//" | tr -d '\r'; }

util_5h=$(get_header "anthropic-ratelimit-unified-5h-utilization")
util_7d=$(get_header "anthropic-ratelimit-unified-7d-utilization")
reset_5h=$(get_header "anthropic-ratelimit-unified-5h-reset")
reset_7d=$(get_header "anthropic-ratelimit-unified-7d-reset")
rm -f "$HEADERS_FILE"

# Convert 0.28 → 28
to_pct() {
  local v="$1"
  [ -z "$v" ] && echo "?" && return
  awk -v v="$v" 'BEGIN { printf "%d", v * 100 + 0.5 }'
}

session_pct=$(to_pct "$util_5h")
week_all_pct=$(to_pct "$util_7d")
week_sonnet_pct="-"
session_reset=$(_format_reset "$reset_5h")
week_all_reset=$(_format_reset "$reset_7d")
week_sonnet_reset="-"

# Only write cache if we got numeric session + week
if [[ "$session_pct" =~ ^[0-9]+$ ]] && [[ "$week_all_pct" =~ ^[0-9]+$ ]]; then
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
