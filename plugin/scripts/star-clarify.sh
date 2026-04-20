#!/usr/bin/env bash
# star-clarify.sh
# UserPromptSubmit: inject STAR protocol instruction — no API call, zero latency.

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

MSG='[STAR PROTOCOL]
Before responding, classify this prompt as simple, medium, or heavy. This applies to ANY task — code or non-code:
- simple: single-step, quick answer, 1-2 changes → respond directly, skip STAR
- medium: multi-step plan, structured output, multiple components or areas → STAR required
- heavy: new system, major initiative, multi-phase, many stakeholders or components → STAR required

If medium or heavy: generate a STAR breakdown and show it to the user BEFORE doing any work.
Format:
**S — Situation:** <context in 1 sentence>
**T — Task:** <goal in 1 sentence>
**A — Action:** <approach in 1 sentence>
**R — Result:** <expected outcome in 1 sentence>

Then use the AskUserQuestion tool to present decision areas as a multi-select checkbox list.
- Question: "Which areas do you want to clarify for [short task description]?"
- Each option: "[Area name] — [one-line description of what needs deciding]"
- Include a "Use recommended defaults for all" option as the last item
After the user selects, present your recommended option for each selected area with a 1-line rationale, then confirm before proceeding.
If the task involves any UI or frontend work, add a final question: "Would you like a quick mockup before we start building? a) Yes — create HTML mockup first  b) No — proceed directly to implementation"
Wait for confirmation before starting any work.'

jq -n --arg msg "$MSG" \
  '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":$msg}}' 2>/dev/null
