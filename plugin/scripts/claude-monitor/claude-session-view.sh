#!/bin/bash
# claude-session-view.sh <SESSION_ID>
# Live viewer for a Claude session / subagent — opens from SwiftBar click

SESSION_ID="$1"
SESSION_DIR="/tmp/claude-sessions"
STATE_FILE="$SESSION_DIR/${SESSION_ID}.json"
LOG_FILE="$SESSION_DIR/${SESSION_ID}.log"

BOLD=$'\033[1m'
DIM=$'\033[2m'
CYAN=$'\033[36m'
GREEN=$'\033[32m'
YELLOW=$'\033[33m'
BLUE=$'\033[34m'
RESET=$'\033[0m'

if [ -z "$SESSION_ID" ] || [ ! -f "$STATE_FILE" ]; then
  echo "Session not found: $SESSION_ID"
  exit 1
fi

render() {
  local project status tool summary cwd ts_val now age elapsed_str

  project=$(jq -r '.project // "unknown"' "$STATE_FILE" 2>/dev/null)
  status=$(jq -r '.status // "?"' "$STATE_FILE" 2>/dev/null)
  tool=$(jq -r '.tool // ""' "$STATE_FILE" 2>/dev/null)
  summary=$(jq -r '.summary // ""' "$STATE_FILE" 2>/dev/null)
  cwd=$(jq -r '.cwd // ""' "$STATE_FILE" 2>/dev/null)
  ts_val=$(jq -r '.ts // 0' "$STATE_FILE" 2>/dev/null)
  now=$(date +%s)
  age=$(( now - ts_val ))
  elapsed_str=$( [ "$age" -lt 60 ] && echo "${age}s ago" || echo "$(( age / 60 ))m ago" )

  clear
  echo ""
  printf "${BOLD}  %-50s${RESET}\n" "Claude Session — $project"
  printf "  ${DIM}%s${RESET}\n" "$cwd"
  printf "  ${DIM}Session: %.8s  │  Last activity: %s${RESET}\n" "$SESSION_ID" "$elapsed_str"
  echo ""

  printf "  Status: "
  case "$status" in
    running)  printf "${CYAN}🔄 running${RESET}" ; [ -n "$tool" ] && printf "  ${CYAN}%s${RESET}" "$tool" ; [ -n "$summary" ] && printf ": ${DIM}%.60s${RESET}" "$summary" ;;
    thinking) printf "${YELLOW}💭 thinking${RESET}" ;;
    idle)     printf "${GREEN}⏸  idle${RESET}" ;;
    stopped)  printf "${DIM}✅ stopped${RESET}" ;;
  esac
  echo ""
  echo ""

  printf "  ${DIM}%-8s  %-4s  %-14s  %s${RESET}\n" "TIME" " " "TOOL/EVENT" "DETAIL"
  echo "  ──────────────────────────────────────────────────────────────"

  if [ -f "$LOG_FILE" ]; then
    python3 - "$LOG_FILE" <<'PYEOF'
import json, sys, time

CYAN  = '\033[36m'
GREEN = '\033[32m'
YELLOW= '\033[33m'
DIM   = '\033[2m'
RESET = '\033[0m'

event_style = {
    'UserPromptSubmit': (YELLOW, '💬', ''),
    'PreToolUse':       (CYAN,   '▶ ', ''),
    'PostToolUse':      (GREEN,  '✓ ', DIM),
    'Stop':             (DIM,    '■ ', DIM),
}

with open(sys.argv[1]) as f:
    lines = f.readlines()

for raw in lines[-60:]:          # show last 60 events to avoid scroll flood
    try:
        e = json.loads(raw)
        ts   = time.strftime('%H:%M:%S', time.localtime(e.get('ts', 0)))
        evt  = e.get('event', '')
        tool = e.get('tool', '')
        summ = e.get('summary', '')

        color, icon, row_color = event_style.get(evt, (DIM, '· ', DIM))
        label = tool if tool else (evt.replace('UserPromptSubmit', 'prompt').replace('PostToolUse','done').replace('Stop','end'))
        detail = (summ[:70] + '…') if len(summ) > 70 else summ

        print(f"  {row_color}{ts}  {color}{icon}{RESET}{row_color}{label:<14}  {detail}{RESET}")
    except Exception:
        pass
PYEOF
  fi
  echo ""
}

trap 'echo ""; exit 0' INT TERM

# Initial render
render

# Live-refresh while session is active
while true; do
  sleep 2
  [ ! -f "$STATE_FILE" ] && break
  current_status=$(jq -r '.status // "stopped"' "$STATE_FILE" 2>/dev/null)
  render
  [ "$current_status" = "stopped" ] && {
    printf "  ${DIM}Session ended. Press Enter to close.${RESET}\n"
    read -r
    break
  }
done
