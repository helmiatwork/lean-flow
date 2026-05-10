#!/usr/bin/env bash
# Test suite for PreToolUse blocking hooks
# Tests: bash-guard.sh (unified guard for protected-push, no-verify, secret-commits,
#        claude-identity, branch-delete, pr-comments) and block-wrong-plan-dir.sh

set -euo pipefail
cd "$(dirname "$0")/../.."

PASS=0
FAIL=0

assert_eq() {
  if [ "$1" = "$2" ]; then
    echo "✓ $3"
    PASS=$((PASS+1))
  else
    echo "✗ $3 (got: '$1', want: '$2')"
    FAIL=$((FAIL+1))
  fi
}

assert_contains() {
  if echo "$1" | grep -q "$2"; then
    echo "✓ $3"
    PASS=$((PASS+1))
  else
    echo "✗ $3 (missing: '$2' in: '$1')"
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

assert_exit() {
  if [ "$1" = "$2" ]; then
    echo "✓ $3"
    PASS=$((PASS+1))
  else
    echo "✗ $3 (exit: $1, want: $2)"
    FAIL=$((FAIL+1))
  fi
}

# ============================================================
echo "=== Test bash-guard.sh (unified Bash PreToolUse guard) ==="
# ============================================================

echo ""
echo "Block direct push to main"
output=$(echo '{"tool_input":{"command":"git push origin main"}}' | bash plugin/scripts/bash-guard.sh 2>&1 || true)
assert_contains "$output" "block" "Push to main is blocked"
assert_contains "$output" "decision" "Output is valid JSON"

echo ""
echo "Block direct push to master"
output=$(echo '{"tool_input":{"command":"git push origin master"}}' | bash plugin/scripts/bash-guard.sh 2>&1 || true)
assert_contains "$output" "block" "Push to master is blocked"

echo ""
echo "Block direct push to staging"
output=$(echo '{"tool_input":{"command":"git push origin staging"}}' | bash plugin/scripts/bash-guard.sh 2>&1 || true)
assert_contains "$output" "block" "Push to staging is blocked"

echo ""
echo "Allow push to feature branch"
output=$(echo '{"tool_input":{"command":"git push origin feature/my-feature"}}' | bash plugin/scripts/bash-guard.sh 2>&1 || true)
assert_not_contains "$output" "block" "Push to feature branch is allowed"

echo ""
echo "Allow push when main is substring of branch name"
output=$(echo '{"tool_input":{"command":"git push origin feature/main-thing"}}' | bash plugin/scripts/bash-guard.sh 2>&1 || true)
assert_not_contains "$output" "block" "Push to feature/main-thing is allowed (main is substring)"

echo ""
echo "Allow push when master is substring of branch name"
output=$(echo '{"tool_input":{"command":"git push origin bugfix/master-key-fix"}}' | bash plugin/scripts/bash-guard.sh 2>&1 || true)
assert_not_contains "$output" "block" "Push to bugfix/master-key-fix is allowed (master is substring)"

echo ""
echo "Allow normal git push without protected branch"
output=$(echo '{"tool_input":{"command":"git push origin develop"}}' | bash plugin/scripts/bash-guard.sh 2>&1 || true)
assert_not_contains "$output" "block" "Push to develop is allowed"

# ============================================================
echo ""
echo "=== Test bash-guard.sh: --no-verify blocking ==="
# ============================================================

echo ""
echo "Block git commit with --no-verify"
exit_code=0
output=$(echo '{"tool_input":{"command":"git commit -m \"msg\" --no-verify"}}' | bash plugin/scripts/bash-guard.sh 2>&1) || exit_code=$?
assert_exit "$exit_code" "2" "Exit code 2 for --no-verify on commit"
assert_contains "$output" "Blocked" "Error message shown"

echo ""
echo "Block git push with --no-verify"
exit_code=0
output=$(echo '{"tool_input":{"command":"git push --no-verify"}}' | bash plugin/scripts/bash-guard.sh 2>&1) || exit_code=$?
assert_exit "$exit_code" "2" "Exit code 2 for --no-verify on push"

echo ""
echo "Block git merge with --no-verify"
exit_code=0
output=$(echo '{"tool_input":{"command":"git merge --no-verify branch"}}' | bash plugin/scripts/bash-guard.sh 2>&1) || exit_code=$?
assert_exit "$exit_code" "2" "Exit code 2 for --no-verify on merge"

echo ""
echo "Block git rebase with --no-verify"
exit_code=0
output=$(echo '{"tool_input":{"command":"git rebase --no-verify main"}}' | bash plugin/scripts/bash-guard.sh 2>&1) || exit_code=$?
assert_exit "$exit_code" "2" "Exit code 2 for --no-verify on rebase"

echo ""
echo "Block git commit with --no-gpg-sign"
exit_code=0
output=$(echo '{"tool_input":{"command":"git commit -m \"normal message\" --no-gpg-sign"}}' | bash plugin/scripts/bash-guard.sh 2>&1) || exit_code=$?
assert_exit "$exit_code" "2" "Exit code 2 for --no-gpg-sign on commit"
assert_contains "$output" "Blocked" "Error message shown"

echo ""
echo "Allow normal git commit"
exit_code=0
output=$(echo '{"tool_input":{"command":"git commit -m \"normal message\""}}' | bash plugin/scripts/bash-guard.sh 2>&1) || exit_code=$?
assert_exit "$exit_code" "0" "Exit code 0 for normal commit"
assert_not_contains "$output" "Blocked" "No error message"

echo ""
echo "Allow normal git status"
exit_code=0
output=$(echo '{"tool_input":{"command":"git status"}}' | bash plugin/scripts/bash-guard.sh 2>&1) || exit_code=$?
assert_exit "$exit_code" "0" "Exit code 0 for git status"

# ============================================================
echo ""
echo "=== Test bash-guard.sh: secret file blocking ==="
# ============================================================

echo ""
echo "Block explicit git add of .env"
exit_code=0
output=$(echo '{"tool_input":{"command":"git add .env"}}' | bash plugin/scripts/bash-guard.sh 2>&1) || exit_code=$?
assert_exit "$exit_code" "2" "Exit code 2 for git add .env"
assert_contains "$output" "Blocked" "Error message shown"

echo ""
echo "Block explicit git add of .env.local"
exit_code=0
output=$(echo '{"tool_input":{"command":"git add .env.local"}}' | bash plugin/scripts/bash-guard.sh 2>&1) || exit_code=$?
assert_exit "$exit_code" "2" "Exit code 2 for git add .env.local"

echo ""
echo "Block explicit git add of credentials"
exit_code=0
output=$(echo '{"tool_input":{"command":"git add credentials"}}' | bash plugin/scripts/bash-guard.sh 2>&1) || exit_code=$?
assert_exit "$exit_code" "2" "Exit code 2 for git add credentials"

echo ""
echo "Block explicit git add of .secret file"
exit_code=0
output=$(echo '{"tool_input":{"command":"git add .secret"}}' | bash plugin/scripts/bash-guard.sh 2>&1) || exit_code=$?
assert_exit "$exit_code" "2" "Exit code 2 for git add .secret"

echo ""
echo "Warn on git add -A (may include secrets)"
exit_code=0
output=$(echo '{"tool_input":{"command":"git add -A"}}' | bash plugin/scripts/bash-guard.sh 2>&1) || exit_code=$?
assert_exit "$exit_code" "0" "Exit code 0 for git add -A (warning only)"
assert_contains "$output" "ask" "Warning decision is 'ask'"
assert_contains "$output" "may stage" "Warning message mentions secrets"

echo ""
echo "Warn on git add . (current directory, may include secrets)"
exit_code=0
output=$(echo '{"tool_input":{"command":"git add ."}}' | bash plugin/scripts/bash-guard.sh 2>&1) || exit_code=$?
assert_exit "$exit_code" "0" "Exit code 0 for git add . (warning only)"
assert_contains "$output" "ask" "Warning decision is 'ask'"

echo ""
echo "Allow git add of regular source file"
exit_code=0
output=$(echo '{"tool_input":{"command":"git add src/main.ts"}}' | bash plugin/scripts/bash-guard.sh 2>&1) || exit_code=$?
assert_exit "$exit_code" "0" "Exit code 0 for git add src/main.ts"
assert_not_contains "$output" "Blocked" "No error message"

echo ""
echo "Allow git add of multiple source files"
exit_code=0
output=$(echo '{"tool_input":{"command":"git add src/index.js src/utils.js"}}' | bash plugin/scripts/bash-guard.sh 2>&1) || exit_code=$?
assert_exit "$exit_code" "0" "Exit code 0 for git add of multiple source files"

# ============================================================
echo ""
echo "=== Test bash-guard.sh: Claude identity blocking ==="
# ============================================================

echo ""
echo "Block commit with Co-Authored-By: Claude"
exit_code=0
output=$(echo '{"tool_input":{"command":"git commit -m \"feat: test\nCo-Authored-By: Claude\""}}' | bash plugin/scripts/bash-guard.sh 2>&1) || exit_code=$?
assert_exit "$exit_code" "2" "Exit code 2 for Co-Authored-By Claude"
assert_contains "$output" "Blocked" "Error message shown"

echo ""
echo "Block commit with Generated by Claude"
exit_code=0
output=$(echo '{"tool_input":{"command":"git commit -m \"feat: test\nGenerated by Claude\""}}' | bash plugin/scripts/bash-guard.sh 2>&1) || exit_code=$?
assert_exit "$exit_code" "2" "Exit code 2 for Generated by Claude"

echo ""
echo "Block commit with AI generated attribution"
exit_code=0
output=$(echo '{"tool_input":{"command":"git commit -m \"feat: test\nAI generated code\""}}' | bash plugin/scripts/bash-guard.sh 2>&1) || exit_code=$?
assert_exit "$exit_code" "2" "Exit code 2 for AI generated attribution"

echo ""
echo "Block PR creation with Claude identity in body"
exit_code=0
output=$(echo '{"tool_input":{"command":"gh pr create --title test --body \"Generated with Claude Code\""}}' | bash plugin/scripts/bash-guard.sh 2>&1) || exit_code=$?
assert_exit "$exit_code" "2" "Exit code 2 for PR with Claude Code attribution"
assert_contains "$output" "Blocked" "Error message shown"

echo ""
echo "Block PR with Co-Authored-By Claude in body"
exit_code=0
output=$(echo '{"tool_input":{"command":"gh pr create --title test --body \"Co-Authored-By: Claude\""}}' | bash plugin/scripts/bash-guard.sh 2>&1) || exit_code=$?
assert_exit "$exit_code" "2" "Exit code 2 for PR with Co-Authored-By"

echo ""
echo "Allow normal PR creation"
exit_code=0
output=$(echo '{"tool_input":{"command":"gh pr create --title \"Add feature\" --body \"This adds a new feature.\""}}' | bash plugin/scripts/bash-guard.sh 2>&1) || exit_code=$?
assert_exit "$exit_code" "0" "Exit code 0 for normal PR"

# ============================================================
echo ""
echo "=== Test bash-guard.sh: branch-delete and PR comments blocking ==="
# ============================================================

echo ""
echo "Block branch delete via push --delete"
exit_code=0
output=$(echo '{"tool_input":{"command":"git push origin --delete feature/old"}}' | bash plugin/scripts/bash-guard.sh 2>&1) || exit_code=$?
assert_exit "$exit_code" "0" "Exit code 0 for git push --delete (JSON decision)"
assert_contains "$output" "block" "Branch delete is blocked"

echo ""
echo "Block branch -D on main"
exit_code=0
output=$(echo '{"tool_input":{"command":"git branch -D main"}}' | bash plugin/scripts/bash-guard.sh 2>&1) || exit_code=$?
assert_exit "$exit_code" "0" "Exit code 0 for git branch -D (passthrough, no match)"

echo ""
echo "Block PR comment creation"
exit_code=0
output=$(echo '{"tool_input":{"command":"gh pr comment 1 --body test"}}' | bash plugin/scripts/bash-guard.sh 2>&1) || exit_code=$?
assert_exit "$exit_code" "0" "Exit code 0 for gh pr comment (JSON decision)"
assert_contains "$output" "block" "PR comment is blocked"

echo ""
echo "Block PR review creation"
exit_code=0
output=$(echo '{"tool_input":{"command":"gh pr review 1 --comment -b x"}}' | bash plugin/scripts/bash-guard.sh 2>&1) || exit_code=$?
assert_exit "$exit_code" "0" "Exit code 0 for gh pr review (JSON decision)"
assert_contains "$output" "block" "PR review is blocked"

# ============================================================
echo ""
echo "=== Test block-wrong-plan-dir.sh (Write|Edit guard) ==="
# ============================================================

echo ""
echo "Block plan file in docs/superpowers/plans/ (wrong directory)"
exit_code=0
output=$(echo '{"tool_input":{"file_path":"docs/superpowers/plans/test-plan.md"}}' | bash plugin/scripts/block-wrong-plan-dir.sh 2>&1) || exit_code=$?
assert_exit "$exit_code" "2" "Exit code 2 for plan in wrong directory"
assert_contains "$output" "Blocked" "Error message shown"

echo ""
echo "Allow plan file in ~/.claude/plans/ (correct directory)"
exit_code=0
output=$(echo '{"tool_input":{"file_path":"/Users/test/.claude/plans/my-plan.md"}}' | bash plugin/scripts/block-wrong-plan-dir.sh 2>&1) || exit_code=$?
assert_exit "$exit_code" "0" "Exit code 0 for plan in correct directory"

echo ""
echo "Allow regular source file in docs/"
exit_code=0
output=$(echo '{"tool_input":{"file_path":"docs/ARCHITECTURE.md"}}' | bash plugin/scripts/block-wrong-plan-dir.sh 2>&1) || exit_code=$?
assert_exit "$exit_code" "0" "Exit code 0 for non-plan file"

# ============================================================
echo ""
echo "=== SUMMARY ==="
echo "=================================="
echo "PASS=$PASS FAIL=$FAIL"

if [ "$FAIL" -eq 0 ]; then
  echo "✓ All tests passed!"
  exit 0
else
  echo "✗ Some tests failed!"
  exit 1
fi
