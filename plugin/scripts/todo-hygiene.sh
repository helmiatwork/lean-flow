#!/usr/bin/env bash
# todo-hygiene.sh — Stop + UserPromptSubmit hook duo.
#
# Adapted from oh-my-opencode-slim's todo-continuation. The full opencode
# implementation auto-continues idle orchestrators when incomplete todos
# remain. Claude Code's plugin API does not expose mid-session continuation,
# so this is the *portable subset*: when Stop fires with incomplete plan
# steps in ~/.claude/plans/, drop a marker; on next UserPromptSubmit, inject
# a hygiene reminder that points at the unfinished work.
#
# Mode is selected by argv[1]: "stop" or "user-prompt-submit".

set -uo pipefail

MODE="${1:-stop}"
MARKER="${HOME}/.claude/.todo-hygiene-pending"
INPUT=$(cat 2>/dev/null || true)

count_open_steps() {
  # Walk ~/.claude/plans/<plan>/skeleton.md and count "- [ ]" / "[x]" entries.
  local plans_dir="${HOME}/.claude/plans"
  [ -d "$plans_dir" ] || { echo "0 0"; return; }

  local open=0
  local total=0
  local most_recent_plan=""
  local most_recent_mtime=0

  while IFS= read -r skel; do
    [ -f "$skel" ] || continue
    # grep -c always prints the count (including 0) but exits 1 when count is 0.
    # We must NOT use `|| echo 0` here because that appends a literal "0" to the
    # already-printed "0", producing the multi-line value "0\n0" and breaking
    # the arithmetic on the next line. Capture grep's stdout and ignore its
    # non-zero exit via a separate fallback.
    local plan_open=0
    local plan_total=0
    plan_open=$(grep -cE '^- \[ \]' "$skel" 2>/dev/null) || plan_open=0
    plan_total=$(grep -cE '^- \[[ x]\]' "$skel" 2>/dev/null) || plan_total=0
    open=$((open + plan_open))
    total=$((total + plan_total))

    if [ "$plan_open" -gt 0 ]; then
      local mtime
      mtime=$(stat -f %m "$skel" 2>/dev/null || stat -c %Y "$skel" 2>/dev/null || echo 0)
      if [ "$mtime" -gt "$most_recent_mtime" ]; then
        most_recent_mtime="$mtime"
        most_recent_plan=$(dirname "$skel" | xargs basename 2>/dev/null)
      fi
    fi
  done < <(find "$plans_dir" -maxdepth 3 -name 'skeleton.md' 2>/dev/null)

  printf '%s %s %s\n' "$open" "$total" "$most_recent_plan"
}

case "$MODE" in
  stop)
    # On Stop: if any plan has open steps, write a marker for next prompt
    read -r open_count total_count plan_name <<< "$(count_open_steps)"
    if [ "${open_count:-0}" -gt 0 ]; then
      printf '%s|%s|%s' "$open_count" "$total_count" "$plan_name" > "$MARKER"
    else
      rm -f "$MARKER" 2>/dev/null || true
    fi
    exit 0
    ;;

  user-prompt-submit)
    # On next user prompt: if marker exists, inject hygiene reminder, then clear
    [ -f "$MARKER" ] || exit 0

    IFS='|' read -r open_count total_count plan_name < "$MARKER"
    rm -f "$MARKER" 2>/dev/null || true

    [ -z "${open_count:-}" ] || [ "$open_count" -eq 0 ] && exit 0

    # Skip injection if user prompt looks like a clear topic-switch
    PROMPT=$(printf '%s' "$INPUT" | jq -r '.prompt // empty' 2>/dev/null)
    LOWER=$(printf '%s' "$PROMPT" | tr '[:upper:]' '[:lower:]')
    case "$LOWER" in
      *"new project"*|*"different topic"*|*"forget"*|*"switch to"*|*"unrelated"*)
        exit 0 ;;
    esac

    REMINDER="[todo-hygiene] Previous session stopped with ${open_count} open step(s) in plan \"${plan_name}\". If the user's current prompt continues that work, resume from the next \`[ ]\` item; otherwise acknowledge the open steps and confirm the new direction."

    jq -n --arg ctx "$REMINDER" \
      '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":$ctx}}' 2>/dev/null
    ;;

  *)
    exit 0
    ;;
esac
