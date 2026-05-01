#!/usr/bin/env bash
# Tests for the omos-adoption batch:
#   - delegate-task-retry.sh   (PostToolUse Task hook)
#   - todo-hygiene.sh           (Stop + UserPromptSubmit duo)
#   - lean-preset.sh            (model preset switcher)
#   - simplify skill            (drop-in markdown skill)

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PASS=0
FAIL=0

assert_contains() {
  if echo "$1" | grep -q "$2"; then
    echo "✓ $3"
    PASS=$((PASS+1))
  else
    echo "✗ $3 (missing '$2')"
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

# ─────────────────────────────────────────────────────────────────
echo "=== simplify skill present and well-formed ==="
SIMPLIFY="${REPO_ROOT}/plugin/skills/simplify.md"
if [ -f "$SIMPLIFY" ]; then
  echo "✓ plugin/skills/simplify.md exists"
  PASS=$((PASS+1))
  if head -5 "$SIMPLIFY" | grep -q "^name: simplify"; then
    echo "✓ has frontmatter name: simplify"
    PASS=$((PASS+1))
  else
    echo "✗ missing name: simplify frontmatter"
    FAIL=$((FAIL+1))
  fi
  if grep -q "preserving exact behavior" "$SIMPLIFY"; then
    echo "✓ contains expected methodology phrase"
    PASS=$((PASS+1))
  else
    echo "✗ skill content does not match expected"
    FAIL=$((FAIL+1))
  fi
else
  echo "✗ simplify skill missing"
  FAIL=$((FAIL+1))
fi

# ─────────────────────────────────────────────────────────────────
echo ""
echo "=== delegate-task-retry: ignores non-Task tool ==="
INPUT='{"tool_name":"Bash","tool_response":{"stdout":"some error output"}}'
output=$(echo "$INPUT" | bash "${REPO_ROOT}/plugin/scripts/delegate-task-retry.sh" 2>&1)
assert_eq "$output" "" "non-Task tool produces no output"

echo ""
echo "=== delegate-task-retry: ignores healthy Task output ==="
INPUT='{"tool_name":"Task","tool_response":{"stdout":"agent completed normally"}}'
output=$(echo "$INPUT" | bash "${REPO_ROOT}/plugin/scripts/delegate-task-retry.sh" 2>&1)
assert_eq "$output" "" "healthy Task output ignored"

echo ""
echo "=== delegate-task-retry: detects subagent_type missing ==="
INPUT='{"tool_name":"Task","tool_response":{"stderr":"InputValidationError: subagent_type is required"}}'
output=$(echo "$INPUT" | bash "${REPO_ROOT}/plugin/scripts/delegate-task-retry.sh" 2>&1)
assert_contains "$output" "delegate-task retry" "guidance block emitted"
assert_contains "$output" "missing_subagent_type\\|input_validation" "error type detected"
assert_contains "$output" "subagent_type" "fix hint mentions subagent_type"

echo ""
echo "=== delegate-task-retry: detects unknown agent ==="
INPUT='{"tool_name":"Task","tool_response":{"stderr":"Error: Unknown subagent_type \"frobnicator\""}}'
output=$(echo "$INPUT" | bash "${REPO_ROOT}/plugin/scripts/delegate-task-retry.sh" 2>&1)
assert_contains "$output" "delegate-task retry" "guidance for unknown agent"

echo ""
echo "=== delegate-task-retry: generic fallback for unrecognized error ==="
INPUT='{"tool_name":"Task","tool_response":{"error":"some weird error happened"}}'
output=$(echo "$INPUT" | bash "${REPO_ROOT}/plugin/scripts/delegate-task-retry.sh" 2>&1)
assert_contains "$output" "generic_task_error\\|delegate-task retry" "generic fallback fires"

# ─────────────────────────────────────────────────────────────────
echo ""
echo "=== todo-hygiene: stop mode with no plans is a no-op ==="
TEST_HOME=$(mktemp -d)
output=$(HOME="$TEST_HOME" bash "${REPO_ROOT}/plugin/scripts/todo-hygiene.sh" stop 2>&1)
exit_code=$?
assert_eq "$exit_code" "0" "stop mode exits 0"
[ ! -f "$TEST_HOME/.claude/.todo-hygiene-pending" ] \
  && { echo "✓ no marker created when no plans"; PASS=$((PASS+1)); } \
  || { echo "✗ unexpected marker"; FAIL=$((FAIL+1)); }
rm -rf "$TEST_HOME"

echo ""
echo "=== todo-hygiene: stop mode writes marker when open steps exist ==="
TEST_HOME=$(mktemp -d)
mkdir -p "$TEST_HOME/.claude/plans/my-plan"
cat > "$TEST_HOME/.claude/plans/my-plan/skeleton.md" <<'EOF'
# my-plan

- [x] step 1 done
- [ ] step 2 pending
- [ ] step 3 pending
EOF
HOME="$TEST_HOME" bash "${REPO_ROOT}/plugin/scripts/todo-hygiene.sh" stop > /dev/null 2>&1
if [ -f "$TEST_HOME/.claude/.todo-hygiene-pending" ]; then
  marker=$(cat "$TEST_HOME/.claude/.todo-hygiene-pending")
  echo "✓ marker created: $marker"
  PASS=$((PASS+1))
  assert_contains "$marker" "2|" "marker reflects 2 open steps"
  assert_contains "$marker" "my-plan" "marker mentions plan name"
else
  echo "✗ marker not created"
  FAIL=$((FAIL+1))
fi

echo ""
echo "=== todo-hygiene: user-prompt-submit injects reminder when marker present ==="
INPUT='{"prompt":"continue please","session_id":"x"}'
output=$(echo "$INPUT" | HOME="$TEST_HOME" bash "${REPO_ROOT}/plugin/scripts/todo-hygiene.sh" user-prompt-submit 2>&1)
assert_contains "$output" "todo-hygiene" "reminder injected"
assert_contains "$output" "my-plan" "reminder names the plan"
[ ! -f "$TEST_HOME/.claude/.todo-hygiene-pending" ] \
  && { echo "✓ marker cleared after injection"; PASS=$((PASS+1)); } \
  || { echo "✗ marker not cleared"; FAIL=$((FAIL+1)); }
rm -rf "$TEST_HOME"

echo ""
echo "=== todo-hygiene: no marker → no injection ==="
TEST_HOME=$(mktemp -d)
output=$(echo '{"prompt":"hi"}' | HOME="$TEST_HOME" bash "${REPO_ROOT}/plugin/scripts/todo-hygiene.sh" user-prompt-submit 2>&1)
assert_eq "$output" "" "no output when no marker"
rm -rf "$TEST_HOME"

# ─────────────────────────────────────────────────────────────────
echo ""
echo "=== lean-preset: lists profiles when called with no args ==="
TEST_HOME=$(mktemp -d)
mkdir -p "$TEST_HOME/.claude"
cat > "$TEST_HOME/.claude/settings.json" <<'EOF'
{
  "env": { "ANTHROPIC_DEFAULT_HAIKU_MODEL": "claude-haiku-4-5-20251001" },
  "permissions": {}, "hooks": {}, "enabledPlugins": {}
}
EOF
output=$(HOME="$TEST_HOME" bash "${REPO_ROOT}/plugin/scripts/lean-preset.sh" 2>&1)
assert_contains "$output" "Built-in presets" "lists built-in profiles"
assert_contains "$output" "balanced" "balanced profile shown"
assert_contains "$output" "cheap" "cheap profile shown"

echo ""
echo "=== lean-preset: cheap profile sets all 3 envs to haiku ==="
HOME="$TEST_HOME" bash "${REPO_ROOT}/plugin/scripts/lean-preset.sh" cheap > /dev/null 2>&1
haiku=$(jq -r '.env.ANTHROPIC_DEFAULT_HAIKU_MODEL' "$TEST_HOME/.claude/settings.json")
sonnet=$(jq -r '.env.ANTHROPIC_DEFAULT_SONNET_MODEL' "$TEST_HOME/.claude/settings.json")
opus=$(jq -r '.env.ANTHROPIC_DEFAULT_OPUS_MODEL' "$TEST_HOME/.claude/settings.json")
assert_contains "$haiku" "haiku" "haiku env set to haiku model"
assert_contains "$sonnet" "haiku" "sonnet env set to haiku model (cheap)"
assert_contains "$opus" "haiku" "opus env set to haiku model (cheap)"

echo ""
echo "=== lean-preset: powerful profile drops haiku ==="
HOME="$TEST_HOME" bash "${REPO_ROOT}/plugin/scripts/lean-preset.sh" powerful > /dev/null 2>&1
haiku=$(jq -r '.env.ANTHROPIC_DEFAULT_HAIKU_MODEL' "$TEST_HOME/.claude/settings.json")
assert_contains "$haiku" "sonnet" "powerful preset replaces haiku with sonnet"

echo ""
echo "=== lean-preset: unknown profile fails ==="
exit_code=0
HOME="$TEST_HOME" bash "${REPO_ROOT}/plugin/scripts/lean-preset.sh" nonexistent-preset >/dev/null 2>&1 || exit_code=$?
assert_eq "$exit_code" "1" "unknown profile exits non-zero"

rm -rf "$TEST_HOME"

# ─────────────────────────────────────────────────────────────────
echo ""
echo "=== hooks.json registers all new hooks ==="
HOOKS_JSON="${REPO_ROOT}/plugin/hooks/hooks.json"
assert_contains "$(cat $HOOKS_JSON)" "delegate-task-retry.sh" "delegate-task-retry registered"
assert_contains "$(cat $HOOKS_JSON)" "todo-hygiene.sh stop" "todo-hygiene stop registered"
assert_contains "$(cat $HOOKS_JSON)" "todo-hygiene.sh user-prompt-submit" "todo-hygiene UserPromptSubmit registered"

echo ""
echo "================================"
echo "$PASS passed, $FAIL failed"
echo "================================"
[ "$FAIL" -eq 0 ]
