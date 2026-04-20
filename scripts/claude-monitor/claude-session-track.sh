#!/bin/bash
# claude-session-track.sh <EVENT_TYPE>
# Hook: writes state file + appends history log per session (including subagents)

EVENT="${1:-unknown}"
SESSION_DIR="/tmp/claude-sessions"
mkdir -p "$SESSION_DIR"

INPUT=$(cat)
[ -z "$INPUT" ] && exit 0

session_id=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)
[ -z "$session_id" ] && exit 0

cwd=$(echo "$INPUT" | jq -r '.cwd // ""' 2>/dev/null)
project=$(basename "$cwd")
ts=$(date +%s)
session_file="$SESSION_DIR/${session_id}.json"
log_file="$SESSION_DIR/${session_id}.log"

log_entry() {
  # Append one JSON line to the history log
  jq -cn \
    --argjson ts "$ts" --arg event "$EVENT" \
    --arg tool "$1" --arg summary "$2" \
    '{ts:$ts,event:$event,tool:$tool,summary:$summary}' \
    >> "$log_file"
}

case "$EVENT" in
  UserPromptSubmit)
    prompt=$(echo "$INPUT" | jq -r '.prompt // ""' 2>/dev/null | cut -c1-100)
    jq -cn \
      --arg sid "$session_id" --arg cwd "$cwd" --arg proj "$project" \
      --arg status "thinking" --arg tool "" --arg summary "$prompt" \
      --argjson ts "$ts" \
      '{session_id:$sid,status:$status,tool:$tool,summary:$summary,cwd:$cwd,project:$proj,ts:$ts}' \
      > "$session_file"
    log_entry "" "$prompt"
    ;;

  PreToolUse)
    tool=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null)
    case "$tool" in
      Bash)
        summary=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null | cut -c1-120)
        ;;
      Write|Edit|MultiEdit|Read)
        summary=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // ""' 2>/dev/null)
        ;;
      WebSearch|WebFetch)
        summary=$(echo "$INPUT" | jq -r '.tool_input.query // .tool_input.url // ""' 2>/dev/null | cut -c1-80)
        ;;
      Agent)
        summary=$(echo "$INPUT" | jq -r '.tool_input.description // "spawning subagent"' 2>/dev/null | cut -c1-80)
        ;;
      Glob)
        summary=$(echo "$INPUT" | jq -r '.tool_input.pattern // ""' 2>/dev/null)
        ;;
      Grep)
        summary=$(echo "$INPUT" | jq -r '.tool_input.pattern // ""' 2>/dev/null)
        ;;
      *)
        summary=""
        ;;
    esac
    jq -cn \
      --arg sid "$session_id" --arg cwd "$cwd" --arg proj "$project" \
      --arg status "running" --arg tool "$tool" --arg summary "$summary" \
      --argjson ts "$ts" \
      '{session_id:$sid,status:$status,tool:$tool,summary:$summary,cwd:$cwd,project:$proj,ts:$ts}' \
      > "$session_file"
    log_entry "$tool" "$summary"
    ;;

  PostToolUse)
    tool=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null)
    if [ -f "$session_file" ]; then
      tmp=$(mktemp)
      jq --argjson ts "$ts" --arg tool "$tool" \
        '.status = "idle" | .tool = $tool | .summary = "" | .ts = $ts' \
        "$session_file" > "$tmp" && mv "$tmp" "$session_file"
    fi
    log_entry "$tool" ""
    ;;

  Stop)
    if [ -f "$session_file" ]; then
      tmp=$(mktemp)
      jq --argjson ts "$ts" '.status = "stopped" | .ts = $ts' \
        "$session_file" > "$tmp" && mv "$tmp" "$session_file"
    fi
    log_entry "" ""
    # Clean up sessions stopped more than 10 minutes ago
    find "$SESSION_DIR" -name "*.json" 2>/dev/null | while read -r f; do
      file_status=$(jq -r '.status // ""' "$f" 2>/dev/null)
      file_ts=$(jq -r '.ts // 0' "$f" 2>/dev/null)
      age=$(( ts - file_ts ))
      if [ "$file_status" = "stopped" ] && [ "$age" -gt 600 ]; then
        base="${f%.json}"
        rm -f "$f" "${base}.log"
      fi
    done
    ;;
esac

exit 0
