#!/usr/bin/env bash
# Tests for plugin/scripts/update-plan-checklist.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$REPO_ROOT/plugin/scripts/update-plan-checklist.sh"
[ -x "$SCRIPT" ] || { echo "FAIL: not executable: $SCRIPT"; exit 1; }

PASS=0; FAIL=0

assert() {
  if [ "$2" = "$3" ]; then
    echo "  ok: $1"
    PASS=$((PASS+1))
  else
    echo "  FAIL: $1 (expected=$2 actual=$3)"
    FAIL=$((FAIL+1))
  fi
}

# Test 1: aborts cleanly outside git repo
echo "Test 1: no-op outside git repo"
TEST_DIR=$(mktemp -d)
cd "$TEST_DIR"
"$SCRIPT" >/dev/null 2>&1
assert "exits cleanly (code 0)" "0" "$?"
cd /; rm -rf "$TEST_DIR"

# Test 2: marks matching checkbox in .plans/
echo "Test 2: marks matching checkbox in .plans/"
TEST_DIR=$(mktemp -d)
cd "$TEST_DIR"
git init -q
git config user.email "t@t"; git config user.name "t"
mkdir -p .plans/myplan
cat > .plans/myplan/plan-full.md <<EOF
# Plan
- [ ] Migration setup database schema
- [ ] Add user authentication endpoint
- [ ] Write integration tests
EOF
echo "x" > file.txt; git add -A; git commit -q -m "feat: migration setup database schema migration"
"$SCRIPT" 2>/dev/null
if grep -q "^- \[x\] Migration setup database schema" .plans/myplan/plan-full.md; then
  OK=1
else
  OK=0
fi
assert "checkbox marked after matching commit" "1" "$OK"
# Other unmatched lines must remain unchecked
if grep -q "^- \[ \] Add user authentication" .plans/myplan/plan-full.md; then
  OK2=1
else
  OK2=0
fi
assert "unmatched checkbox left unchecked" "1" "$OK2"
cd /; rm -rf "$TEST_DIR"

# Test 3: handles .planning/ convention
echo "Test 3: handles .planning/ convention"
TEST_DIR=$(mktemp -d)
cd "$TEST_DIR"
git init -q
git config user.email "t@t"; git config user.name "t"
mkdir -p .planning/phase-01
cat > .planning/phase-01/PLAN.md <<EOF
# Phase Plan
- [ ] Database migration foreign keys
EOF
echo "x" > f.txt; git add -A; git commit -q -m "feat: database migration foreign keys done"
"$SCRIPT" 2>/dev/null
if grep -q "^- \[x\] Database migration" .planning/phase-01/PLAN.md; then
  OK=1
else
  OK=0
fi
assert ".planning/ convention works" "1" "$OK"
cd /; rm -rf "$TEST_DIR"

# Test 4: short keyword (<4 chars) doesn't trigger false match
echo "Test 4: short keywords ignored"
TEST_DIR=$(mktemp -d)
cd "$TEST_DIR"
git init -q
git config user.email "t@t"; git config user.name "t"
mkdir -p .plans/p
cat > .plans/p/plan-full.md <<EOF
- [ ] AB CD
EOF
echo "x" > f; git add -A; git commit -q -m "ab cd"
"$SCRIPT" 2>/dev/null
if grep -q "^- \[ \] AB CD" .plans/p/plan-full.md; then
  STAY=1
else
  STAY=0
fi
assert "short keywords do not mark checkbox" "1" "$STAY"
cd /; rm -rf "$TEST_DIR"

# Test 5: requires 2+ keyword matches (not 1)
echo "Test 5: requires 2+ keyword matches"
TEST_DIR=$(mktemp -d)
cd "$TEST_DIR"
git init -q
git config user.email "t@t"; git config user.name "t"
mkdir -p .plans/p
cat > .plans/p/plan-full.md <<EOF
- [ ] Setup database schema
- [ ] Testing framework integration
EOF
# Commit with only 1 matching keyword ("setup")
echo "x" > f; git add -A; git commit -q -m "feat: setup done"
"$SCRIPT" 2>/dev/null
if grep -q "^- \[ \] Setup database schema" .plans/p/plan-full.md; then
  STAY=1
else
  STAY=0
fi
assert "single keyword match does not mark" "1" "$STAY"
cd /; rm -rf "$TEST_DIR"

# Test 6: correctly marks when 2+ keywords match
echo "Test 6: correctly marks when 2+ keywords match"
TEST_DIR=$(mktemp -d)
cd "$TEST_DIR"
git init -q
git config user.email "t@t"; git config user.name "t"
mkdir -p .plans/p
cat > .plans/p/plan-full.md <<EOF
- [ ] Setup database schema
EOF
# Commit with 2 matching keywords ("setup" and "database")
echo "x" > f; git add -A; git commit -q -m "feat: setup database schema complete"
"$SCRIPT" 2>/dev/null
if grep -q "^- \[x\] Setup database schema" .plans/p/plan-full.md; then
  MARKED=1
else
  MARKED=0
fi
assert "two+ keyword matches mark checkbox" "1" "$MARKED"
cd /; rm -rf "$TEST_DIR"

# Test 7: multiple plan files updated independently
echo "Test 7: multiple plan files updated"
TEST_DIR=$(mktemp -d)
cd "$TEST_DIR"
git init -q
git config user.email "t@t"; git config user.name "t"
mkdir -p .plans/p1 .plans/p2
cat > .plans/p1/plan-full.md <<EOF
- [ ] Frontend design mockups
EOF
cat > .plans/p2/plan-full.md <<EOF
- [ ] Backend authentication service
EOF
echo "x" > f; git add -A; git commit -q -m "feat: frontend design mockups created"
"$SCRIPT" 2>/dev/null
if grep -q "^- \[x\] Frontend design" .plans/p1/plan-full.md; then
  OK1=1
else
  OK1=0
fi
if grep -q "^- \[ \] Backend authentication" .plans/p2/plan-full.md; then
  OK2=1
else
  OK2=0
fi
assert "first plan file marked" "1" "$OK1"
assert "second plan file untouched" "1" "$OK2"
cd /; rm -rf "$TEST_DIR"

# Test 8: case-insensitive matching
echo "Test 8: case-insensitive matching"
TEST_DIR=$(mktemp -d)
cd "$TEST_DIR"
git init -q
git config user.email "t@t"; git config user.name "t"
mkdir -p .plans/p
cat > .plans/p/plan-full.md <<EOF
- [ ] Database Schema Migration
EOF
# Commit with lowercase commit message
echo "x" > f; git add -A; git commit -q -m "feat: database schema migration done"
"$SCRIPT" 2>/dev/null
if grep -q "^- \[x\] Database Schema Migration" .plans/p/plan-full.md; then
  MARKED=1
else
  MARKED=0
fi
assert "case-insensitive match works" "1" "$MARKED"
cd /; rm -rf "$TEST_DIR"

# Test 9: handles special characters in commit messages
echo "Test 9: handles special characters in commit message"
TEST_DIR=$(mktemp -d)
cd "$TEST_DIR"
git init -q
git config user.email "t@t"; git config user.name "t"
mkdir -p .plans/p
cat > .plans/p/plan-full.md <<EOF
- [ ] Auth system setup
EOF
# Commit with special characters
echo "x" > f; git add -A; git commit -q -m "feat(auth): system setup & tests"
"$SCRIPT" 2>/dev/null
if grep -q "^- \[x\] Auth system setup" .plans/p/plan-full.md; then
  MARKED=1
else
  MARKED=0
fi
assert "special chars in commit don't break matching" "1" "$MARKED"
cd /; rm -rf "$TEST_DIR"

# Test 10: preserves already-checked items
echo "Test 10: preserves already-checked items"
TEST_DIR=$(mktemp -d)
cd "$TEST_DIR"
git init -q
git config user.email "t@t"; git config user.name "t"
mkdir -p .plans/p
cat > .plans/p/plan-full.md <<EOF
- [x] Already done step one
- [ ] Setup database schema
EOF
echo "x" > f; git add -A; git commit -q -m "feat: setup database schema done"
"$SCRIPT" 2>/dev/null
if grep -q "^- \[x\] Already done step one" .plans/p/plan-full.md && \
   grep -q "^- \[x\] Setup database schema" .plans/p/plan-full.md; then
  OK=1
else
  OK=0
fi
assert "checked items preserved and new item marked" "1" "$OK"
cd /; rm -rf "$TEST_DIR"

echo "---"
echo "PASS: $PASS, FAIL: $FAIL"
[ "$FAIL" -eq 0 ]
