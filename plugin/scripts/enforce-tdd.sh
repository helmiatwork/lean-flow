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
  # Test file already exists — just remind to run cycle
  MSG="[TDD ENFORCEMENT] Test file exists: $(basename "$EXISTING_TEST")
Run the test cycle now:
- RUN tests → PASS: check coverage ≥80% → proceed
- FAIL x3: STOP, invoke lean-flow:oracle with error + what you tried"
else
  # No test file yet — ask user which type of test to write
  MSG="[TDD ENFORCEMENT] You just wrote implementation code in: $(basename "$FILE")

ASK THE USER before writing tests:
'Tipe test apa yang ingin dibuat untuk $(basename "$FILE")?
  a. Unit test          — logic/function isolation (default)
  b. E2E test           — user flow via browser (Playwright)
  c. Regression test    — reproduksi bug dulu, lalu fix
  d. Unit + E2E         — full TDD cycle (recommended for user-facing features)
  e. Skip test          — throwaway prototype only (requires user confirmation)

Jawab a/b/c/d/e:'

Wait for user answer, then follow the chosen path:
- a/default → RED(unit) → GREEN → REFACTOR → coverage ≥80%
- b → RED(E2E via Playwright) → GREEN → REFACTOR
- c → RED(regression reproducing bug) → GREEN → REFACTOR → unit coverage ≥80%
- d → RED(unit) → GREEN → REFACTOR → RED(E2E) → GREEN → coverage ≥80%
- e → confirm with user explicitly, then skip

RETRY RULE (all paths):
- FAIL attempt 1 → diagnose + fix → run again
- FAIL attempt 2 → diagnose + fix → run again
- FAIL attempt 3 → STOP. Invoke lean-flow:oracle. Never retry past 3 failures."
fi

jq -n --arg msg "$MSG" \
  '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":$msg}}' 2>/dev/null
