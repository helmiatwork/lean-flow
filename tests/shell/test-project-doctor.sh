#!/usr/bin/env bash
# Smoke tests for project-doctor scanner.
set -euo pipefail

# Resolve repo root so tests are portable across machines/CI
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="${CLAUDE_PLUGIN_ROOT:-$REPO_ROOT/plugin}/scripts/project-doctor/score.sh"
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

# Test 6: default mode emits 27 rows (25 scored + 2 advisory)
TMPDIR=$(mktemp -d)
cd "$TMPDIR"
git init -q
OUT=$("$SCRIPT" 2>/dev/null)
ROW_COUNT=$(echo "$OUT" | grep -E '^\| [0-9]' | wc -l | tr -d ' ')
assert "default emits 27 total rows (25+2 advisory)" "27" "$ROW_COUNT"
cd /
rm -rf "$TMPDIR"

# Test 7: check 21 detects STAR PROTOCOL
TEST_TMPDIR=$(mktemp -d)
cd "$TEST_TMPDIR"
git init -q
echo "## STAR PROTOCOL" > CLAUDE.md
OUT=$("$SCRIPT" 2>/dev/null)
echo "$OUT" | grep -qE '^\| 21 \|.*\[OK\]' && OK21=1 || OK21=0
assert "check 21 detects STAR PROTOCOL" "1" "$OK21"
cd /
rm -rf "$TEST_TMPDIR"

# Test 8: check 21 MISSING without STAR
TEST_TMPDIR=$(mktemp -d)
cd "$TEST_TMPDIR"
git init -q
echo "# Test" > CLAUDE.md
HOME=/nonexistent OUT=$("$SCRIPT" 2>/dev/null)
echo "$OUT" | grep -qE '^\| 21 \|.*\[MISSING\]' && MISS21=1 || MISS21=0
assert "check 21 MISSING without STAR" "1" "$MISS21"
cd /
rm -rf "$TEST_TMPDIR"

# Test 9: check 22 detects orchestrator binding
TEST_TMPDIR=$(mktemp -d)
cd "$TEST_TMPDIR"
git init -q
echo "Orchestrator never edits code for medium/heavy tasks." > CLAUDE.md
OUT=$("$SCRIPT" 2>/dev/null)
echo "$OUT" | grep -qE '^\| 22 \|.*\[OK\]' && OK22=1 || OK22=0
assert "check 22 detects orchestrator binding" "1" "$OK22"
cd /
rm -rf "$TEST_TMPDIR"

# Test 10: check 22 MISSING without binding
TEST_TMPDIR=$(mktemp -d)
cd "$TEST_TMPDIR"
git init -q
echo "# Test" > CLAUDE.md
HOME=/nonexistent OUT=$("$SCRIPT" 2>/dev/null)
echo "$OUT" | grep -qE '^\| 22 \|.*\[MISSING\]' && MISS22=1 || MISS22=0
assert "check 22 MISSING without binding" "1" "$MISS22"
cd /
rm -rf "$TEST_TMPDIR"

# Test 11: advisory rows show [OK] or [ADVISORY], not [MISSING]
TEST_TMPDIR=$(mktemp -d)
cd "$TEST_TMPDIR"
git init -q
OUT=$("$SCRIPT" 2>/dev/null)
echo "$OUT" | grep -qE '^\| (26|27) \|.*\[(OK|ADVISORY)\]' && ADVISORY_OK=1 || ADVISORY_OK=0
assert "advisory rows show [OK] or [ADVISORY]" "1" "$ADVISORY_OK"
cd /
rm -rf "$TEST_TMPDIR"

# Test 12: advisory rows EXCLUDED from --missing-only output
TEST_TMPDIR=$(mktemp -d)
cd "$TEST_TMPDIR"
git init -q
MISSING=$("$SCRIPT" --missing-only 2>/dev/null)
# Check if advisory items (26|...) or (27|...) appear in --missing-only output
# They should NOT appear, so grep should fail (return 1)
if echo "$MISSING" | grep -q '^26|' 2>/dev/null || echo "$MISSING" | grep -q '^27|' 2>/dev/null; then
  ADVISORY_EXCLUDED=0
else
  ADVISORY_EXCLUDED=1
fi
assert "advisory rows excluded from --missing-only" "1" "$ADVISORY_EXCLUDED"
cd /
rm -rf "$TEST_TMPDIR"

echo "---"
echo "PASS: $PASS, FAIL: $FAIL"
[ "$FAIL" -eq 0 ]
