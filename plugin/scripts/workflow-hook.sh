#!/usr/bin/env bash
# workflow-hook.sh — single entry point for all lean-flow workflow hooks
#
# Usage: workflow-hook.sh <EVENT> [MATCHER]
# Called by hooks.json for each event. Routes to relevant script logic.
#
# Consolidated events:
#   SessionStart        → session-briefing
#   UserPromptSubmit    → pattern-recall + load-workflow + star-clarify (merged)
#   PostToolUse Write|Edit  → enforce-tdd
#   PostToolUse EnterPlanMode → knowledge-prefilter
#   PostToolUse ExitPlanMode  → generate-plan-viewer
#   SubagentStop        → remind-check-step
#   Stop                → auto-dream + auto-observe + session-summary (bg)
#   PostCompact         → session-summary (bg)
#
# NOT consolidated (stay separate): ensure-*, block-*, claude-session-track,
#   restructure-plan.py, auto-compress-output, track-test-failures, auto-update-codemaps

EVENT="${1:-}"
MATCHER="${2:-}"
INPUT=$(cat)
P="${CLAUDE_PLUGIN_ROOT}"

# Run a hook script, extract additionalContext text only
_ctx() {
  printf '%s' "$INPUT" | bash "$1" 2>/dev/null \
    | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null
}

# Run a hook script, extract systemMessage text only
_sys() {
  printf '%s' "$INPUT" | bash "$1" 2>/dev/null \
    | jq -r '.systemMessage // empty' 2>/dev/null
}

# Emit merged JSON output
_emit() {
  local event="$1" sys="$2"
  shift 2
  # Merge non-empty context strings
  local merged=""
  for ctx in "$@"; do
    [ -n "$ctx" ] && merged="${merged:+$merged$'\n\n'}$ctx"
  done

  if [ -n "$merged" ] && [ -n "$sys" ]; then
    jq -n --arg e "$event" --arg c "$merged" --arg s "$sys" \
      '{"systemMessage":$s,"hookSpecificOutput":{"hookEventName":$e,"additionalContext":$c}}' 2>/dev/null
  elif [ -n "$merged" ]; then
    jq -n --arg e "$event" --arg c "$merged" \
      '{"hookSpecificOutput":{"hookEventName":$e,"additionalContext":$c}}' 2>/dev/null
  elif [ -n "$sys" ]; then
    jq -n --arg s "$sys" '{"systemMessage":$s}' 2>/dev/null
  fi
}

# ─────────────────────────────────────────────
case "$EVENT" in

  SessionStart)
    # session-briefing outputs systemMessage — pass through directly
    printf '%s' "$INPUT" | bash "$P/scripts/session-briefing.sh" 2>/dev/null
    ;;

  UserPromptSubmit)
    c1=$(_ctx "$P/scripts/pattern-recall.sh")
    c2=$(_ctx "$P/scripts/load-workflow.sh")
    c3=$(_ctx "$P/scripts/star-clarify.sh")
    _emit "UserPromptSubmit" "" "$c1" "$c2" "$c3"
    ;;

  PostToolUse)
    case "$MATCHER" in
      "Write|Edit")
        c1=$(_ctx "$P/scripts/enforce-tdd.sh")
        _emit "PostToolUse" "" "$c1"
        ;;
      EnterPlanMode)
        c1=$(_ctx "$P/scripts/knowledge-prefilter.sh")
        _emit "PostToolUse" "" "$c1"
        ;;
      ExitPlanMode)
        # generate-plan-viewer outputs systemMessage + opens browser
        printf '%s' "$INPUT" | bash "$P/scripts/generate-plan-viewer.sh" 2>/dev/null
        ;;
      Bash)
        # PR created → notify oracle
        PR=$(printf '%s' "$INPUT" | jq -r '.tool_response.stdout // ""' 2>/dev/null \
          | grep -o 'pull/[0-9]*' | grep -o '[0-9]*' | head -1)
        if [ -n "$PR" ]; then
          _emit "PostToolUse" "" "PR #${PR} created. Dispatch lean-flow:code-reviewer to review the diff, then lean-flow:fixer to fix any Critical/Important issues."
        fi
        ;;
    esac
    ;;

  SubagentStop)
    c1=$(_ctx "$P/scripts/remind-check-step.sh")
    _emit "SubagentStop" "" "$c1"
    ;;

  Stop)
    # Run all in background — non-blocking
    printf '%s' "$INPUT" | bash "$P/scripts/auto-dream.sh"    > /dev/null 2>&1 &
    printf '%s' "$INPUT" | bash "$P/scripts/auto-observe.sh"  > /dev/null 2>&1 &
    printf '%s' "$INPUT" | bash "$P/scripts/session-summary.sh" > /dev/null 2>&1 &
    ;;

  PostCompact)
    printf '%s' "$INPUT" | bash "$P/scripts/session-summary.sh" > /dev/null 2>&1 &
    ;;

esac
