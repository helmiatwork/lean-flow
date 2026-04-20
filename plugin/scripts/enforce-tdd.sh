#!/usr/bin/env bash
# enforce-tdd.sh
# PostToolUse Write|Edit: if implementation file written without test, inject TDD reminder.

INPUT=$(cat)
FILE=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // .tool_response.filePath // empty' 2>/dev/null)

[ -z "$FILE" ] && exit 0

# Skip non-code files
case "$FILE" in
  *.md|*.json|*.yaml|*.yml|*.toml|*.env|*.txt|*.sh|*.lock|*.log) exit 0 ;;
  *.png|*.jpg|*.svg|*.ico|*.css|*.html) exit 0 ;;
esac

# Skip if this IS a test/spec file
BASENAME=$(basename "$FILE" | tr '[:upper:]' '[:lower:]')
case "$BASENAME" in
  *test*|*spec*|*_test.*|*.test.*|*.spec.*) exit 0 ;;
esac
case "$FILE" in
  */test/*|*/tests/*|*/__tests__/*|*/spec/*|*/specs/*) exit 0 ;;
esac

# Skip config/setup/migration files
case "$BASENAME" in
  *config*|*setup*|*migration*|*seed*|*fixture*|*factory*) exit 0 ;;
esac

# It's an implementation file — enforce TDD + auto-run cycle
MSG="[TDD ENFORCEMENT]
You just wrote implementation code in: $(basename "$FILE")

MANDATORY cycle (non-negotiable):
1. RED   — write failing unit test first, watch it fail
2. GREEN — minimal code to pass, run tests NOW
3. REFACTOR — clean up, keep green
4. E2E   — add E2E test for user-facing flows
5. COVERAGE — run coverage, must be ≥80%

RUN TESTS NOW. Then follow this retry rule:
- PASS → check coverage ≥80% → proceed
- FAIL attempt 1 → diagnose + fix → run again
- FAIL attempt 2 → diagnose + fix → run again
- FAIL attempt 3 → STOP. Invoke lean-flow:oracle with error + what you tried.
  Never retry past 3 failures — escalate to oracle.

Do NOT mark done until: unit tests pass + E2E pass + coverage ≥80%."

jq -n --arg msg "$MSG" \
  '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":$msg}}' 2>/dev/null
