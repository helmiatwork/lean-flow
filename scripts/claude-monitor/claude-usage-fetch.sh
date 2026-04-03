#!/bin/bash

# Claude Usage Fetcher — runs with a real TTY via script command

CACHE_FILE="/tmp/claude-usage-cache.json"
SESSION_FILE="/tmp/claude-usage-session.txt"
CLAUDE_BIN="${CLAUDE_BIN:-$(command -v claude || echo "$HOME/.local/bin/claude")}"
LOCK_FILE="/tmp/claude-usage-fetch.lock"

# Run from home dir (safe default)
cd "$HOME"

# Prevent concurrent runs
if [ -f "$LOCK_FILE" ]; then
  lock_age=$(( $(date +%s) - $(stat -f%m "$LOCK_FILE" 2>/dev/null || stat -c%Y "$LOCK_FILE" 2>/dev/null || echo 0) ))
  if [ "$lock_age" -lt 60 ]; then
    exit 0
  fi
fi
echo $$ > "$LOCK_FILE"
trap "rm -f $LOCK_FILE" EXIT

# Fetch usage via script + piped commands
{
  sleep 12
  printf "/usage\r"
  sleep 8
  printf "\033"
  sleep 2
  printf "/exit\r"
  sleep 2
} | script -q "$SESSION_FILE" "$CLAUDE_BIN" --no-chrome --disallowedTools "Bash,Edit,Write,Read,Grep,Glob,Agent" 2>/dev/null

# Strip ANSI codes
clean=$(perl -pe '
  s/\e\[\d*C/ /g;
  s/\e\[[^a-zA-Z]*[a-zA-Z]//g;
  s/\e\][^\a]*(\a|\e\\)//g;
  s/\e\([A-Z]//g;
  s/[\x00-\x08\x0b\x0c\x0e-\x1f]//g;
' "$SESSION_FILE" 2>/dev/null)

# Parse percentages
pct_output=$(echo "$clean" | grep -oE '[0-9]+%[[:space:]]*used' | sed 's/% *used//' | head -3)
session_pct=$(echo "$pct_output" | sed -n '1p')
week_all_pct=$(echo "$pct_output" | sed -n '2p')
week_sonnet_pct=$(echo "$pct_output" | sed -n '3p')

# Parse reset times
now_epoch=$(date +%s)

resets=$(echo "$clean" | perl -ne 'while (/(\d+)%\s*used\s*(.*?)(?:\(|Cur|Esc|$)/g) { my $r=$2; $r=~s/^\s+|\s+$//g; print "$r\n" }' | head -3)
session_raw=$(echo "$resets" | sed -n '1p')
week_all_raw=$(echo "$resets" | sed -n '2p')
week_sonnet_raw=$(echo "$resets" | sed -n '3p')

calc_remaining() {
  local raw="$1"
  [ -z "$raw" ] && echo "?" && return

  local stripped=$(echo "$raw" | perl -pe 's/^Rese[a-z]*\s*//')
  local month=$(echo "$stripped" | perl -ne 'print $1 if /^([A-Z][a-z]{2})/i')
  local day=$(echo "$stripped" | perl -ne 'print $1 if /^[A-Za-z]{3}\s*(\d+)/')

  if [ -n "$month" ] && [ -n "$day" ]; then
    month=$(echo "$month" | perl -pe '$_ = ucfirst(lc($_))')
    local target=$(date -j -f "%b %d %Y %H%M" "$month $day $(date +%Y) 0000" +%s 2>/dev/null)
    local today_midnight=$(date -j -f "%Y%m%d %H%M" "$(date +%Y%m%d) 0000" +%s 2>/dev/null)
    if [ -n "$target" ] && [ -n "$today_midnight" ]; then
      local days=$(( (target - today_midnight) / 86400 ))
      if [ "$days" -le 0 ]; then echo "today"; else echo "${days}d"; fi
    else
      echo "?"
    fi
  else
    local time=$(echo "$stripped" | grep -oiE '[0-9]+(:[0-9]+)?\s*[ap]?\s*m')
    if [ -n "$time" ]; then
      time=$(echo "$time" | perl -pe 's/\s+//g')
      time=$(echo "$time" | perl -pe 'if (/^(\d+)(:\d+)?m$/i) { my $h=$1; my $s=$2//""; $h<=6 ? s/m$/am/i : s/m$/pm/i }')
      echo "$time"
    else
      echo "?"
    fi
  fi
}

session_reset=$(calc_remaining "$session_raw")
week_all_reset=$(calc_remaining "$week_all_raw")
week_sonnet_reset=$(calc_remaining "$week_sonnet_raw")

[ "$week_sonnet_pct" = "0" ] && [ "$week_sonnet_reset" = "?" ] && week_sonnet_reset="-"
[ "$week_all_pct" = "0" ] && [ "$week_all_reset" = "?" ] && week_all_reset="-"
[ "$session_pct" = "0" ] && [ "$session_reset" = "?" ] && session_reset="-"

if [[ "$session_pct" =~ ^[0-9]+$ ]]; then
  cat > "$CACHE_FILE" << JSON
{"session": "$session_pct", "week_all": "${week_all_pct:-?}", "week_sonnet": "${week_sonnet_pct:-?}", "session_reset": "${session_reset:-?}", "week_all_reset": "${week_all_reset:-?}", "week_sonnet_reset": "${week_sonnet_reset:-?}", "updated": "$(date '+%H:%M')"}
JSON
  touch /tmp/claude-usage-blink
  open -g "swiftbar://refreshplugin?name=claude-usage" 2>/dev/null
  ( sleep 11 && open -g "swiftbar://refreshplugin?name=claude-usage" 2>/dev/null ) &>/dev/null &
fi
