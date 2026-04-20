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

# It's an implementation file — enforce TDD
MSG="[TDD ENFORCEMENT]
You just wrote implementation code in: $(basename "$FILE")
MANDATORY: Invoke lean-flow:test-driven-development before proceeding.

Steps (non-negotiable):
1. RED — write failing unit test first
2. GREEN — minimal code to pass
3. REFACTOR — clean up
4. E2E — add E2E test for user-facing flows
5. COVERAGE — run coverage report, must be ≥80%

Do NOT mark done until: unit tests pass + E2E tests pass + coverage ≥80%."

jq -n --arg msg "$MSG" \
  '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":$msg}}' 2>/dev/null
