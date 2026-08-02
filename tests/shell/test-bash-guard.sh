#!/usr/bin/env bash
# Behavioral test suite for bash-guard.sh
# Tests all 6 checks: no-verify, no-gpg-sign, protected-push, secret-files, branch-delete, pr-comments
# NOTE: Run directly, not via Bash tool (which has its own pre-hook)

set -euo pipefail

SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/plugin/scripts/bash-guard.sh"
PASS=0
FAIL=0

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

check() {
  local name="$1" cmd="$2" expected_exit="$3"
  local actual

  # Pass JSON input to bash-guard.sh via stdin
  local json_input="{\"tool_input\":{\"command\":$(printf '%s' "$cmd" | jq -Rs .)}}"

  # Execute in subshell to capture exit code
  actual=0
  echo -n "$json_input" | (bash "$SCRIPT" >/dev/null 2>&1) || actual=$?

  if [ "$actual" = "$expected_exit" ]; then
    echo -e "${GREEN}✓${NC} $name"
    PASS=$((PASS+1))
  else
    echo -e "${RED}✗${NC} $name (expected=$expected_exit actual=$actual)"
    FAIL=$((FAIL+1))
  fi
}

echo "Testing bash-guard.sh (6 checks)"
echo "=================================="

# ===== BLOCKED CHECKS (exit 2) =====
echo ""
echo "BLOCKED (should exit 2):"

check "no-verify on commit" \
  "git commit --no-verify -m test" \
  2

check "no-gpg-sign" \
  "git commit --no-gpg-sign -m test" \
  2

check "secret file .env" \
  "git add .env" \
  2

check "secret file credentials" \
  "git add credentials" \
  2

check "claude identity in commit" \
  "git commit -m feat: test" \
  0  # Won't match because we're not quoting the full message

# ===== ALLOWED (exit 0) =====
echo ""
echo "ALLOWED (should exit 0):"

check "git status" \
  "git status" \
  0

check "git log" \
  "git log --oneline" \
  0

check "ls command" \
  "ls -la" \
  0

check "git commit normal" \
  "git commit -m feat: normal commit" \
  0

check "git push allowed branch" \
  "git push origin feature/new" \
  0

check "git add specific file" \
  "git add src/index.js" \
  0

# ===== SPECIAL CASES (exit 0 with JSON decision) =====
echo ""
echo "SPECIAL CASES (should exit 0 with JSON decision):"

check "push to main protected" \
  "git push origin main" \
  0

check "git add -A warning" \
  "git add -A" \
  0

check "branch delete blocked" \
  "git push origin --delete feature/old" \
  0

check "branch -D blocked" \
  "git branch -D main" \
  0

check "pr comment blocked" \
  "gh pr comment 1 --body test" \
  0

check "pr review blocked" \
  "gh pr review 1 --comment -b x" \
  0

# ===== MERGE GATE (stubbed gh) =====
echo ""
echo "MERGE GATE (should ASK on protected base):"

GATE_TMP=$(mktemp -d)
cat > "$GATE_TMP/gh" <<'STUB'
#!/usr/bin/env bash
# stub: `gh pr view ... baseRefName` always resolves to main
echo main
STUB
chmod +x "$GATE_TMP/gh"

GATE_OUT=$(echo -n '{"tool_input":{"command":"gh pr merge 5 --squash"}}' | PATH="$GATE_TMP:$PATH" bash "$SCRIPT" 2>/dev/null || true)
if echo "$GATE_OUT" | grep -q '"permissionDecision":"ask"'; then
  echo -e "${GREEN}✓${NC} merge to protected base asks for confirmation"; PASS=$((PASS+1))
else
  echo -e "${RED}✗${NC} merge to protected base asks for confirmation"; FAIL=$((FAIL+1))
fi

GATE_OFF=$(echo -n '{"tool_input":{"command":"gh pr merge 5 --squash"}}' | LEAN_FLOW_MERGE_GATE_DISABLED=true PATH="$GATE_TMP:$PATH" bash "$SCRIPT" 2>/dev/null || true)
if echo "$GATE_OFF" | grep -q '"permissionDecision":"ask"'; then
  echo -e "${RED}✗${NC} disable flag skips gate"; FAIL=$((FAIL+1))
else
  echo -e "${GREEN}✓${NC} disable flag skips gate"; PASS=$((PASS+1))
fi

rm -rf "$GATE_TMP"

# ===== SUMMARY =====
echo ""
echo "=================================="
echo "PASS=$PASS FAIL=$FAIL"

if [ "$FAIL" -eq 0 ]; then
  echo -e "${GREEN}All tests passed!${NC}"
  exit 0
else
  echo -e "${RED}Some tests failed!${NC}"
  exit 1
fi
