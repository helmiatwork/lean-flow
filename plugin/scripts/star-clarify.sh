#!/usr/bin/env bash
# star-clarify.sh
# UserPromptSubmit: inject STAR protocol instruction — no API call, zero latency.
# The orchestrator (main model) handles classification and STAR generation.

INPUT=$(cat)
PROMPT=$(printf '%s' "$INPUT" | jq -r '.prompt // empty' 2>/dev/null)

[ -z "$PROMPT" ] || [ "${#PROMPT}" -lt 50 ] && exit 0

LOWER=$(printf '%s' "$PROMPT" | tr '[:upper:]' '[:lower:]' | sed 's/^[[:space:]]*//')
case "$LOWER" in
  yes*|no*|ok*|sure*|nope*|correct*|exactly*|proceed*|go\ ahead*|done*|thanks*|thank\ you*|got\ it*)
    exit 0 ;;
esac

MSG="[STAR PROTOCOL]
Before responding, classify this prompt as simple, medium, or heavy:
- simple: 1-2 file changes, bug fix, quick config, short factual answer → respond directly, skip STAR
- medium: multi-file feature, refactor, new script, multi-step plan → STAR required
- heavy: new system, major architecture, multi-phase, multi-component → STAR required

If medium or heavy: generate a STAR breakdown and show it to the user BEFORE doing any work.
Format:
**S — Situation:** <context in 1 sentence>
**T — Task:** <goal in 1 sentence>
**A — Action:** <approach in 1 sentence>
**R — Result:** <expected outcome in 1 sentence>

Then invoke the \`lean-flow:discuss\` skill to gather scope and clarify requirements through structured discussion.
Wait for the discussion to complete before starting any work."

jq -n --arg msg "$MSG" \
  '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":$msg}}' 2>/dev/null
