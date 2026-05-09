#!/usr/bin/env bash
# Smoke tests for project-doctor scanner.
set -euo pipefail

SCRIPT="${CLAUDE_PLUGIN_ROOT:-/Users/ichigo/Documents/repo/lean-flow/plugin}/scripts/project-doctor/score.sh"
[ -x "$SCRIPT" ] || { echo "FAIL: scanner not executable: $SCRIPT"; exit 1; }

PASS=0
FAIL=0

assert() {
  local label="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    echo "  ok: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label (expected=$expected actual=$actual)"
    FAIL=$((FAIL + 1))
  fi
}

# Test 1: --help exit 0
"$SCRIPT" --help >/dev/null 2>&1
assert "--help exit 0" "0" "$?"

# Test 2: unknown flag exit 64
set +e
"$SCRIPT" --bogus >/dev/null 2>&1
RET=$?
set -e
assert "--bogus exit 64" "64" "$RET"

# Test 3: --score-only emits a single integer
TMPDIR=$(mktemp -d)
cd "$TMPDIR"
git init -q
SCORE=$("$SCRIPT" --score-only 2>/dev/null)
echo "$SCORE" | grep -qE '^[0-9]+$' && SCORE_VALID=1 || SCORE_VALID=0
assert "--score-only is integer" "1" "$SCORE_VALID"
cd /
rm -rf "$TMPDIR"

# Test 4: --missing-only emits pipe-separated lines (or empty if no missing)
TMPDIR=$(mktemp -d)
cd "$TMPDIR"
git init -q
LINES=$("$SCRIPT" --missing-only 2>/dev/null | head -1)
if [ -z "$LINES" ]; then
  echo "  ok: --missing-only empty on greenfield (unexpected but valid if all checks N/A)"
  PASS=$((PASS + 1))
else
  echo "$LINES" | grep -qE '^[0-9]+\|.+\|.+\|P[0-2]$' && FORMAT_OK=1 || FORMAT_OK=0
  assert "--missing-only pipe format" "1" "$FORMAT_OK"
fi
cd /
rm -rf "$TMPDIR"

# Test 5: default mode emits markdown table
TMPDIR=$(mktemp -d)
cd "$TMPDIR"
git init -q
OUT=$("$SCRIPT" 2>/dev/null)
echo "$OUT" | grep -q '^| #' && HEADER_OK=1 || HEADER_OK=0
assert "default emits md table header" "1" "$HEADER_OK"
echo "$OUT" | grep -q 'Score:' && SCORE_LINE=1 || SCORE_LINE=0
assert "default emits Score: line" "1" "$SCORE_LINE"
cd /
rm -rf "$TMPDIR"

echo "---"
echo "PASS: $PASS, FAIL: $FAIL"
[ "$FAIL" -eq 0 ]
