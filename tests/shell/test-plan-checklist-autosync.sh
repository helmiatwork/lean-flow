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

# Test 1: opt-in disabled by default (LEAN_FLOW_AUTOSYNC unset)
echo "Test 1: hook disabled when LEAN_FLOW_AUTOSYNC unset"
TEST_DIR=$(mktemp -d)
cd "$TEST_DIR"
git init -q
git config user.email "t@t"; git config user.name "t"
mkdir -p .plans/p
cat > .plans/p/plan-full.md <<EOF
- [ ] Step one task
EOF
echo "x" > f.txt
git add -A
git commit -q -m "feat: step one task [step:1]"
unset LEAN_FLOW_AUTOSYNC || true
"$SCRIPT" 2>/dev/null
if grep -q "^- \[ \] Step one task" .plans/p/plan-full.md; then
  STAYED=1
else
  STAYED=0
fi
assert "checkbox stays unchecked without opt-in" "1" "$STAYED"
cd /; rm -rf "$TEST_DIR"

# Test 2: opt-in enabled via LEAN_FLOW_AUTOSYNC=1
echo "Test 2: hook works with LEAN_FLOW_AUTOSYNC=1"
TEST_DIR=$(mktemp -d)
cd "$TEST_DIR"
git init -q
git config user.email "t@t"; git config user.name "t"
mkdir -p .plans/p
cat > .plans/p/plan-full.md <<EOF
- [ ] Step one task
EOF
echo "x" > f.txt
git add -A
git commit -q -m "feat: step one task [step:1]"
LEAN_FLOW_AUTOSYNC=1 "$SCRIPT" 2>/dev/null
if grep -q "^- \[x\] Step one task" .plans/p/plan-full.md; then
  MARKED=1
else
  MARKED=0
fi
assert "checkbox marked with opt-in and [step:1] marker" "1" "$MARKED"
cd /; rm -rf "$TEST_DIR"

# Test 3: strict marker — no [step:N] = no-op
echo "Test 3: hook is no-op when commit msg has no [step:N] marker"
TEST_DIR=$(mktemp -d)
cd "$TEST_DIR"
git init -q
git config user.email "t@t"; git config user.name "t"
mkdir -p .plans/p
cat > .plans/p/plan-full.md <<EOF
- [ ] Step one task
EOF
echo "x" > f.txt
git add -A
git commit -q -m "feat: step one task done"
LEAN_FLOW_AUTOSYNC=1 "$SCRIPT" 2>/dev/null
if grep -q "^- \[ \] Step one task" .plans/p/plan-full.md; then
  STAYED=1
else
  STAYED=0
fi
assert "checkbox stays unchecked without structured marker" "1" "$STAYED"
cd /; rm -rf "$TEST_DIR"

# Test 4: marks Nth checkbox when commit msg has [step:N]
echo "Test 4: marks Nth checkbox with [step:N] marker"
TEST_DIR=$(mktemp -d)
cd "$TEST_DIR"
git init -q
git config user.email "t@t"; git config user.name "t"
mkdir -p .plans/p
cat > .plans/p/plan-full.md <<EOF
- [ ] Step one
- [ ] Step two
- [ ] Step three
EOF
echo "x" > f.txt
git add -A
git commit -q -m "feat: step two implementation [step:2]"
LEAN_FLOW_AUTOSYNC=1 "$SCRIPT" 2>/dev/null
if grep -q "^- \[x\] Step two" .plans/p/plan-full.md && \
   grep -q "^- \[ \] Step one" .plans/p/plan-full.md && \
   grep -q "^- \[ \] Step three" .plans/p/plan-full.md; then
  OK=1
else
  OK=0
fi
assert "marks exactly the Nth unchecked checkbox" "1" "$OK"
cd /; rm -rf "$TEST_DIR"

# Test 5: idempotency — running script twice on same SHA only marks once
echo "Test 5: idempotency via SHA cache"
TEST_DIR=$(mktemp -d)
cd "$TEST_DIR"
git init -q
git config user.email "t@t"; git config user.name "t"
mkdir -p .plans/p
cat > .plans/p/plan-full.md <<EOF
- [ ] Task one
- [ ] Task two
EOF
echo "x" > f.txt
git add -A
git commit -q -m "feat: task one done [step:1]"
LEAN_FLOW_AUTOSYNC=1 "$SCRIPT" 2>/dev/null
# Verify first mark
AFTER_FIRST=$(grep '^- \[' .plans/p/plan-full.md | head -1)
# Run again on same SHA
LEAN_FLOW_AUTOSYNC=1 "$SCRIPT" 2>/dev/null
AFTER_SECOND=$(grep '^- \[' .plans/p/plan-full.md | head -1)
if [ "$AFTER_FIRST" = "$AFTER_SECOND" ] && grep -q "^- \[x\] Task one" .plans/p/plan-full.md; then
  IDEMPOTENT=1
else
  IDEMPOTENT=0
fi
assert "cache prevents double-marking on same SHA" "1" "$IDEMPOTENT"
cd /; rm -rf "$TEST_DIR"

# Test 6: handles .planning/ convention
echo "Test 6: handles .planning/ convention"
TEST_DIR=$(mktemp -d)
cd "$TEST_DIR"
git init -q
git config user.email "t@t"; git config user.name "t"
mkdir -p .planning/phase-01
cat > .planning/phase-01/PLAN.md <<EOF
- [ ] Database setup
EOF
echo "x" > f.txt
git add -A
git commit -q -m "feat: db [step:1]"
LEAN_FLOW_AUTOSYNC=1 "$SCRIPT" 2>/dev/null
if grep -q "^- \[x\] Database setup" .planning/phase-01/PLAN.md; then
  OK=1
else
  OK=0
fi
assert ".planning/ convention works" "1" "$OK"
cd /; rm -rf "$TEST_DIR"

# Test 7: handles .planning/phases/ convention
echo "Test 7: handles .planning/phases/ convention"
TEST_DIR=$(mktemp -d)
cd "$TEST_DIR"
git init -q
git config user.email "t@t"; git config user.name "t"
mkdir -p .planning/phases/01
cat > .planning/phases/01/PLAN.md <<EOF
- [ ] Auth implementation
EOF
echo "x" > f.txt
git add -A
git commit -q -m "auth [step:1]"
LEAN_FLOW_AUTOSYNC=1 "$SCRIPT" 2>/dev/null
if grep -q "^- \[x\] Auth implementation" .planning/phases/01/PLAN.md; then
  OK=1
else
  OK=0
fi
assert ".planning/phases/ convention works" "1" "$OK"
cd /; rm -rf "$TEST_DIR"

# Test 8: closes step-N marker variant
echo "Test 8: 'closes step-N' marker variant"
TEST_DIR=$(mktemp -d)
cd "$TEST_DIR"
git init -q
git config user.email "t@t"; git config user.name "t"
mkdir -p .plans/p
cat > .plans/p/plan-full.md <<EOF
- [ ] Work item
EOF
echo "x" > f.txt
git add -A
git commit -q -m "implement feature, closes step-1"
LEAN_FLOW_AUTOSYNC=1 "$SCRIPT" 2>/dev/null
if grep -q "^- \[x\] Work item" .plans/p/plan-full.md; then
  MARKED=1
else
  MARKED=0
fi
assert "'closes step-N' variant works" "1" "$MARKED"
cd /; rm -rf "$TEST_DIR"

# Test 9: preserves already-checked items
echo "Test 9: preserves already-checked items"
TEST_DIR=$(mktemp -d)
cd "$TEST_DIR"
git init -q
git config user.email "t@t"; git config user.name "t"
mkdir -p .plans/p
cat > .plans/p/plan-full.md <<EOF
- [x] Step one done
- [ ] Step two todo
- [ ] Step three todo
EOF
echo "x" > f.txt
git add -A
git commit -q -m "step two [step:1]"
LEAN_FLOW_AUTOSYNC=1 "$SCRIPT" 2>/dev/null
if grep -q "^- \[x\] Step one done" .plans/p/plan-full.md && \
   grep -q "^- \[x\] Step two todo" .plans/p/plan-full.md && \
   grep -q "^- \[ \] Step three todo" .plans/p/plan-full.md; then
  OK=1
else
  OK=0
fi
assert "checked items preserved, new item marked" "1" "$OK"
cd /; rm -rf "$TEST_DIR"

# Test 10: multiple plan files updated independently
echo "Test 10: multiple plan files updated independently"
TEST_DIR=$(mktemp -d)
cd "$TEST_DIR"
git init -q
git config user.email "t@t"; git config user.name "t"
mkdir -p .plans/plan1 .plans/plan2
cat > .plans/plan1/plan-full.md <<EOF
- [ ] Frontend task one
- [ ] Frontend task two
EOF
cat > .plans/plan2/plan-full.md <<EOF
- [ ] Backend task one
- [ ] Backend task two
EOF
echo "x" > f.txt
git add -A
git commit -q -m "frontend [step:1]"
LEAN_FLOW_AUTOSYNC=1 "$SCRIPT" 2>/dev/null
if grep -q "^- \[x\] Frontend task one"  .plans/plan1/plan-full.md && \
   grep -q "^- \[ \] Frontend task two"  .plans/plan1/plan-full.md && \
   grep -q "^- \[x\] Backend task one"   .plans/plan2/plan-full.md && \
   grep -q "^- \[ \] Backend task two"   .plans/plan2/plan-full.md; then
  OK=1
else
  OK=0
fi
assert "step:1 marks first checkbox in every plan file (documented cross-plan behavior)" "1" "$OK"
cd /; rm -rf "$TEST_DIR"

echo "---"
echo "PASS: $PASS, FAIL: $FAIL"
[ "$FAIL" -eq 0 ]
