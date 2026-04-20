#!/bin/bash

# Claude Code Usage Monitor for SwiftBar
# Reads cached usage data from OAuth rate limit headers

CACHE_FILE="/tmp/claude-usage-cache.json"
BLINK_FLAG="/tmp/claude-usage-blink"
CONFIG_FILE="$HOME/.config/claude-usage/config"
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0" 2>/dev/null || echo "$0")")" && pwd)"
FETCHER="$SCRIPT_DIR/claude-usage-fetch.sh"

# Read refresh interval from config (default 30 seconds)
if [ -f "$CONFIG_FILE" ]; then
  _secs=$(grep -oE '^refresh_seconds=[0-9]+' "$CONFIG_FILE" | cut -d= -f2)
fi
FETCH_INTERVAL=${_secs:-30}

# --- Handle commands from menu actions ---
if [ "$1" = "set_interval" ] && [[ "$2" =~ ^[0-9]+$ ]]; then
  mkdir -p "$(dirname "$CONFIG_FILE")"
  if grep -q '^refresh_seconds=' "$CONFIG_FILE" 2>/dev/null; then
    sed -i '' "s/^refresh_seconds=.*/refresh_seconds=$2/" "$CONFIG_FILE"
  else
    echo "refresh_seconds=$2" >> "$CONFIG_FILE"
  fi
  exit 0
fi

if [ "$1" = "refresh_now" ]; then
  touch "$BLINK_FLAG"
  open -g "swiftbar://refreshplugin?name=claude-usage"
  "$FETCHER" &>/dev/null &
  exit 0
fi

# --- Read cache ---
if [ -f "$CACHE_FILE" ]; then
  session_pct=$(jq -r '.session // "?"' "$CACHE_FILE" 2>/dev/null)
  week_pct=$(jq -r '.week_all // "?"' "$CACHE_FILE" 2>/dev/null)
  session_reset=$(jq -r '.session_reset // "?"' "$CACHE_FILE" 2>/dev/null)
  week_reset=$(jq -r '.week_all_reset // "?"' "$CACHE_FILE" 2>/dev/null)
else
  session_pct="?"
  week_pct="?"
  session_reset="?"
  week_reset="?"
fi

# --- Read active sessions ---
SESSION_DIR="/tmp/claude-sessions"
active_count=0
session_lines=""

if [ -d "$SESSION_DIR" ] && ls "$SESSION_DIR"/*.json 2>/dev/null | head -1 > /dev/null; then
  VIEWER="$SCRIPT_DIR/claude-session-view.sh"
  session_data=$(python3 - "$SESSION_DIR" <<'PYEOF'
import json, sys, os, time

session_dir = sys.argv[1]
now = time.time()
sessions = []

for f in os.listdir(session_dir):
    if not f.endswith('.json'):
        continue
    try:
        with open(os.path.join(session_dir, f)) as fp:
            s = json.load(fp)
        s['_file'] = f[:-5]   # session_id = filename without .json
        sessions.append(s)
    except Exception:
        pass

sessions.sort(key=lambda x: x.get('ts', 0), reverse=True)

def elapsed(ts):
    age = int(now - ts)
    if age < 60: return f"{age}s"
    if age < 3600: return f"{age//60}m"
    return f"{age//3600}h"

active = []
recent = []
for s in sessions:
    status = s.get('status', '')
    age = now - s.get('ts', now)
    if status in ('running', 'thinking') or (status == 'idle' and age < 300):
        active.append(s)
    elif status == 'stopped' and age < 600:
        recent.append(s)

icons = {'running': '🔄', 'thinking': '💭', 'idle': '⏸', 'stopped': '✅'}

print(f"ACTIVE:{len(active)}")
for s in active + recent:
    status = s.get('status', '')
    icon = icons.get(status, '·')
    proj = (s.get('project') or s.get('cwd', '').split('/')[-1] or 'unknown')[:20]
    tool = s.get('tool', '')
    summary = s.get('summary', '')
    age_str = elapsed(s.get('ts', now))
    sid = s.get('_file', s.get('session_id', ''))
    display = f"{icon} {proj}"
    if tool:
        display += f"  {tool}"
    if summary:
        short = summary[:45] + ('…' if len(summary) > 45 else '')
        display += f": {short}"
    display += f"  ({age_str})"
    print(f"LINE:{sid}|{display}")
PYEOF
  )
  active_count=$(echo "$session_data" | grep "^ACTIVE:" | cut -d: -f2)
  session_lines=$(echo "$session_data" | grep "^LINE:" | sed 's/^LINE://')
fi

# --- Color based on highest usage ---
max_pct=0
for p in "$session_pct" "$week_pct"; do
  if [[ "$p" =~ ^[0-9]+$ ]] && [ "$p" -gt "$max_pct" ]; then
    max_pct=$p
  fi
done

if [ "$max_pct" -ge 80 ]; then
  icon="🔴"
elif [ "$max_pct" -ge 50 ]; then
  icon="🟡"
else
  icon="🟢"
fi

# --- Blink detection (10s after refresh) ---
blink=false
if [ -f "$BLINK_FLAG" ]; then
  flag_age=$(( $(date +%s) - $(stat -f%m "$BLINK_FLAG") ))
  if [ "$flag_age" -lt 10 ]; then
    blink=true
  else
    rm -f "$BLINK_FLAG"
  fi
fi

# --- Title bar ---
display="${session_pct}%(${session_reset})┊${week_pct}%(${week_reset})"
[ "${active_count:-0}" -gt 0 ] && display="$display · ${active_count}⚡"

if [ "$session_pct" = "?" ]; then
  echo "☁️ --% | color=#888888"
elif [ "$blink" = true ]; then
  echo "⚡ $display | color=#00ffcc"
else
  echo "$icon $display | color=white"
fi

# --- Dropdown ---
echo "---"
echo "Claude Code Usage | size=14"
echo "---"
echo "Session (5h):  ${session_pct}%  ↻ ${session_reset}"
echo "Weekly (7d):   ${week_pct}%  ↻ ${week_reset}"
echo "---"
if [ -f "$CACHE_FILE" ]; then
  updated=$(jq -r '.updated // "?"' "$CACHE_FILE" 2>/dev/null)
  updated_epoch=$(stat -f%m "$CACHE_FILE")
  now_epoch=$(date +%s)
  elapsed=$(( now_epoch - updated_epoch ))
  remaining=$(( FETCH_INTERVAL - elapsed ))
  if [ "$remaining" -le 0 ]; then
    remaining=0
    touch "$BLINK_FLAG"
    "$FETCHER" &>/dev/null &
  fi
  mins=$(( remaining / 60 ))
  secs=$(( remaining % 60 ))
  countdown=$(printf "%d:%02d" "$mins" "$secs")
  echo "Updated: $updated | size=11 color=#888888"
  echo "Next refresh: $countdown | size=11 color=#888888"
fi
# --- Sessions section ---
echo "---"
if [ "${active_count:-0}" -gt 0 ]; then
  echo "Sessions — ${active_count} active | size=11 color=#888888"
elif [ -n "$session_lines" ]; then
  echo "Sessions — all done | size=11 color=#888888"
else
  echo "Sessions — none | size=11 color=#888888"
fi
if [ -n "$session_lines" ]; then
  echo "$session_lines" | while IFS= read -r entry; do
    sid="${entry%%|*}"
    display="${entry#*|}"
    echo "$display | bash='$VIEWER' param1='$sid' terminal=true refresh=false size=12"
  done
fi

SELF_PATH="$0"
echo "Refresh | bash='$SELF_PATH' param1=refresh_now terminal=false refresh=true"
echo "---"
echo "Refresh every: ${FETCH_INTERVAL}s | size=11 color=#888888"
for s in 30 60 120 180 300; do
  label=$( [ "$s" -lt 60 ] && echo "${s}s" || echo "$(( s / 60 ))m" )
  if [ "$s" -eq "$FETCH_INTERVAL" ]; then
    echo "-- ✓ ${label} | disabled=true"
  else
    echo "-- ${label} | bash='$SELF_PATH' param1=set_interval param2=$s terminal=false refresh=true"
  fi
done
