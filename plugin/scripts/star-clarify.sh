#!/usr/bin/env bash
# star-clarify.sh
# UserPromptSubmit: inject the goal brief instruction (Goal / Done when / Constraints / Ask) — no API call, zero latency.

INPUT=$(cat)
PROMPT=$(printf '%s' "$INPUT" | jq -r '.prompt // empty' 2>/dev/null)

[ -z "$PROMPT" ] || [ "${#PROMPT}" -lt 5 ] && exit 0

LOWER=$(printf '%s' "$PROMPT" | tr '[:upper:]' '[:lower:]' | sed 's/^[[:space:]]*//')
case "$LOWER" in
  yes*|no*|ok*|sure*|nope*|correct*|exactly*|proceed*|go\ ahead*|done*|thanks*|thank\ you*|got\ it*|a|b|c|d|e)
    exit 0 ;;
esac

# Detect code creation requests — ask test type BEFORE dispatching fixer
IS_CODE_CREATE=0
case "$LOWER" in
  *create*|*implement*|*add*function*|*add*class*|*add*method*|*build*|*write*a*)
    case "$LOWER" in
      *.ts*|*.tsx*|*.js*|*.jsx*|*.py*|*.go*|*.rb*|*.java*|*.rs*|*function*|*class*|*module*|*service*|*component*|*helper*|*util*)
        IS_CODE_CREATE=1 ;;
    esac ;;
esac

if [ "$IS_CODE_CREATE" = "1" ]; then
  jq -n '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"[TDD PRE-CHECK] Code creation detected. BEFORE dispatching fixer, use AskUserQuestion tool with these EXACT options:\n- Question: \"What type of tests do you want for this implementation?\"\n- Options:\n  1. Unit test — isolate and test logic/functions\n  2. E2E test — test user flow via browser (Playwright)\n  3. Regression test — reproduce the bug first, then fix\n  4. Unit + E2E — full TDD cycle (recommended for user-facing features)\n  5. Skip tests — throwaway prototype only\nWait for user selection, then dispatch fixer with the chosen test strategy."}}' 2>/dev/null
  exit 0
fi

MSG='[GOAL BRIEF]
Before responding, classify this prompt as simple, medium, or heavy. This applies to ANY task — code or non-code.
- simple: single-step, quick answer, 1-2 changes → FIRST state one line — "Interpretation: <what you understood> → Expected result: <concrete outcome>" — then proceed WITHOUT waiting for confirmation.
- medium / heavy: multi-step work, several components or areas, or a new system → show this brief BEFORE doing any work:

Goal: <what this achieves, 1 sentence>
Done when: <verifiable evidence: tests/CI green, measured numbers, files or PRs produced, checks run>
Constraints: <rules that apply: user rules, behaviour that must not change, limits, things not to touch>
Ask: <only decisions that belong to the user, or "-">

If Ask is "-", proceed right after the brief without waiting. If Ask has items, use the AskUserQuestion tool for exactly those decisions (recommended option first) and wait for the answer. Never ask about things you can verify yourself or that have a sensible default.
If the task involves UI or frontend work and the look is not specified, include "mockup first?" in Ask.'

jq -n --arg msg "$MSG" \
  '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":$msg}}' 2>/dev/null
