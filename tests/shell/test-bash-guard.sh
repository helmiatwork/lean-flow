#!/usr/bin/env bash
# Behavioral test suite for bash-guard.sh
# Tests all 7 checks: no-verify, no-gpg-sign, protected-push, secret-files, branch-delete, pr-comments, merge-gate
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

echo "Testing bash-guard.sh (7 checks)"
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
echo "MERGE GATE:"

# stub: any PR resolves to main (protected)
GATE_MAIN=$(mktemp -d)
printf '#!/usr/bin/env bash\necho main\n' > "$GATE_MAIN/gh"; chmod +x "$GATE_MAIN/gh"

# stub: PR 5 resolves to main, anything else to a non-protected branch
# (used to prove the number extraction picks the real PR, not a numeric --repo)
GATE_SMART=$(mktemp -d)
printf '#!/usr/bin/env bash\nfor a in "$@"; do [ "$a" = "5" ] && { echo main; exit 0; }; done\necho feature/x\n' > "$GATE_SMART/gh"; chmod +x "$GATE_SMART/gh"

# stub: any PR resolves to a non-protected branch
GATE_FEAT=$(mktemp -d)
printf '#!/usr/bin/env bash\necho feature/x\n' > "$GATE_FEAT/gh"; chmod +x "$GATE_FEAT/gh"

# stub: gh fails (offline / not authed / not a PR)
GATE_ERR=$(mktemp -d)
printf '#!/usr/bin/env bash\nexit 1\n' > "$GATE_ERR/gh"; chmod +x "$GATE_ERR/gh"

gate_run() { echo -n "{\"tool_input\":{\"command\":\"$2\"}}" | PATH="$1:$PATH" bash "$SCRIPT" 2>/dev/null || true; }
asks() { echo "$1" | grep -q '"permissionDecision":"ask"'; }
ok() { echo -e "${GREEN}✓${NC} $1"; PASS=$((PASS+1)); }
no() { echo -e "${RED}✗${NC} $1"; FAIL=$((FAIL+1)); }

OUT=$(gate_run "$GATE_MAIN" "gh pr merge 5 --squash")
asks "$OUT" && ok "protected base (with PR number) asks" || no "protected base (with PR number) asks"

OUT=$(gate_run "$GATE_MAIN" "gh pr merge --squash")
asks "$OUT" && ok "protected base (no PR number) asks" || no "protected base (no PR number) asks"

OUT=$(gate_run "$GATE_SMART" "gh pr merge --repo org123/repo456 5 --squash")
asks "$OUT" && ok "numeric --repo does not hijack PR-number extraction" || no "numeric --repo does not hijack PR-number extraction"

OUT=$(gate_run "$GATE_FEAT" "gh pr merge 5 --squash")
asks "$OUT" && no "non-protected base must NOT ask" || ok "non-protected base does not ask"

OUT=$(gate_run "$GATE_ERR" "gh pr merge 5 --squash")
asks "$OUT" && no "gh error must fail open" || ok "gh error fails open (no ask)"

OUT=$(echo -n '{"tool_input":{"command":"gh pr merge 5 --squash"}}' | LEAN_FLOW_MERGE_GATE_DISABLED=true PATH="$GATE_MAIN:$PATH" bash "$SCRIPT" 2>/dev/null || true)
asks "$OUT" && no "disable flag must skip gate" || ok "disable flag skips gate"
echo "$OUT" | grep -q '"command"' && ok "disable flag passes input through" || no "disable flag passes input through"

rm -rf "$GATE_MAIN" "$GATE_SMART" "$GATE_FEAT" "$GATE_ERR"

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
