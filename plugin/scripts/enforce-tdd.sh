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

# Check if a test file already exists for this implementation file
BASENAME_NO_EXT="${BASENAME%.*}"
EXT="${FILE##*.}"
DIR=$(dirname "$FILE")
EXISTING_TEST=$(find "$DIR" -maxdepth 2 \( -name "${BASENAME_NO_EXT}.test.*" -o -name "${BASENAME_NO_EXT}.spec.*" -o -name "${BASENAME_NO_EXT}_test.*" \) 2>/dev/null | head -1)

if [ -n "$EXISTING_TEST" ]; then
  MSG="[TDD] Test exists: $(basename "$EXISTING_TEST") — run it now. FAIL x3 → oracle."
else
  MSG="[TDD] $(basename "$FILE") written. ASK USER (one message, no sub-agent):
'Test type? a=unit  b=E2E  c=regression  d=unit+E2E  e=skip'
Then follow: a→RED(unit)→GREEN→REFACTOR→cov≥80% | b→RED(E2E)→GREEN | c→RED(repro bug)→GREEN | d→unit+E2E | e→confirm skip
FAIL x3 → oracle."
fi

jq -n --arg msg "$MSG" \
  '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":$msg}}' 2>/dev/null
