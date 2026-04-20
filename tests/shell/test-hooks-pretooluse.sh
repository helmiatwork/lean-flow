#!/usr/bin/env bash
# Test suite for PreToolUse blocking hooks
# Tests: block-protected-push, block-no-verify, block-secret-commits,
#        block-claude-identity, warn-secret-files, block-wrong-plan-dir

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
echo "=== Test block-protected-push.sh ==="
# ============================================================

echo ""
echo "Block direct push to main"
output=$(echo '{"tool_input":{"command":"git push origin main"}}' | bash plugin/scripts/block-protected-push.sh 2>&1 || true)
assert_contains "$output" "block" "Push to main is blocked"
assert_contains "$output" "decision" "Output is valid JSON"

echo ""
echo "Block direct push to master"
output=$(echo '{"tool_input":{"command":"git push origin master"}}' | bash plugin/scripts/block-protected-push.sh 2>&1 || true)
assert_contains "$output" "block" "Push to master is blocked"

echo ""
echo "Block direct push to staging"
output=$(echo '{"tool_input":{"command":"git push origin staging"}}' | bash plugin/scripts/block-protected-push.sh 2>&1 || true)
assert_contains "$output" "block" "Push to staging is blocked"

echo ""
echo "Allow push to feature branch"
output=$(echo '{"tool_input":{"command":"git push origin feature/my-feature"}}' | bash plugin/scripts/block-protected-push.sh 2>&1 || true)
assert_not_contains "$output" "block" "Push to feature branch is allowed"

echo ""
echo "Allow push when main is substring of branch name"
output=$(echo '{"tool_input":{"command":"git push origin feature/main-thing"}}' | bash plugin/scripts/block-protected-push.sh 2>&1 || true)
assert_not_contains "$output" "block" "Push to feature/main-thing is allowed (main is substring)"

echo ""
echo "Allow push when master is substring of branch name"
output=$(echo '{"tool_input":{"command":"git push origin bugfix/master-key-fix"}}' | bash plugin/scripts/block-protected-push.sh 2>&1 || true)
assert_not_contains "$output" "block" "Push to bugfix/master-key-fix is allowed (master is substring)"

echo ""
echo "Allow normal git push without protected branch"
output=$(echo '{"tool_input":{"command":"git push origin develop"}}' | bash plugin/scripts/block-protected-push.sh 2>&1 || true)
assert_not_contains "$output" "block" "Push to develop is allowed"

# ============================================================
echo ""
echo "=== Test block-no-verify.sh ==="
# ============================================================

echo ""
echo "Block git commit with --no-verify"
exit_code=0
output=$(echo '{"tool_input":{"command":"git commit -m \"msg\" --no-verify"}}' | bash plugin/scripts/block-no-verify.sh 2>&1) || exit_code=$?
assert_exit "$exit_code" "2" "Exit code 2 for --no-verify on commit"
assert_contains "$output" "Blocked" "Error message shown"

echo ""
echo "Block git push with --no-verify"
exit_code=0
output=$(echo '{"tool_input":{"command":"git push --no-verify"}}' | bash plugin/scripts/block-no-verify.sh 2>&1) || exit_code=$?
assert_exit "$exit_code" "2" "Exit code 2 for --no-verify on push"

echo ""
echo "Block git merge with --no-verify"
exit_code=0
output=$(echo '{"tool_input":{"command":"git merge --no-verify branch"}}' | bash plugin/scripts/block-no-verify.sh 2>&1) || exit_code=$?
assert_exit "$exit_code" "2" "Exit code 2 for --no-verify on merge"

echo ""
echo "Block git rebase with --no-verify"
exit_code=0
output=$(echo '{"tool_input":{"command":"git rebase --no-verify main"}}' | bash plugin/scripts/block-no-verify.sh 2>&1) || exit_code=$?
assert_exit "$exit_code" "2" "Exit code 2 for --no-verify on rebase"

echo ""
echo "Block git commit with --no-gpg-sign"
exit_code=0
output=$(echo '{"tool_input":{"command":"git commit -m \"normal message\" --no-gpg-sign"}}' | bash plugin/scripts/block-no-verify.sh 2>&1) || exit_code=$?
assert_exit "$exit_code" "2" "Exit code 2 for --no-gpg-sign on commit"
assert_contains "$output" "Blocked" "Error message shown"

echo ""
echo "Allow normal git commit"
exit_code=0
output=$(echo '{"tool_input":{"command":"git commit -m \"normal message\""}}' | bash plugin/scripts/block-no-verify.sh 2>&1) || exit_code=$?
assert_exit "$exit_code" "0" "Exit code 0 for normal commit"
assert_not_contains "$output" "Blocked" "No error message"

echo ""
echo "Allow normal git status"
exit_code=0
output=$(echo '{"tool_input":{"command":"git status"}}' | bash plugin/scripts/block-no-verify.sh 2>&1) || exit_code=$?
assert_exit "$exit_code" "0" "Exit code 0 for git status"

# ============================================================
echo ""
echo "=== Test block-secret-commits.sh ==="
# ============================================================

echo ""
echo "Block explicit git add of .env"
exit_code=0
output=$(echo '{"tool_input":{"command":"git add .env"}}' | bash plugin/scripts/block-secret-commits.sh 2>&1) || exit_code=$?
assert_exit "$exit_code" "2" "Exit code 2 for git add .env"
assert_contains "$output" "Blocked" "Error message shown"

echo ""
echo "Block explicit git add of .env.local"
exit_code=0
output=$(echo '{"tool_input":{"command":"git add src/.env.local"}}' | bash plugin/scripts/block-secret-commits.sh 2>&1) || exit_code=$?
assert_exit "$exit_code" "2" "Exit code 2 for git add .env.local"

echo ""
echo "Block explicit git add of credentials"
exit_code=0
output=$(echo '{"tool_input":{"command":"git add credentials.json"}}' | bash plugin/scripts/block-secret-commits.sh 2>&1) || exit_code=$?
assert_exit "$exit_code" "2" "Exit code 2 for git add credentials"

echo ""
echo "Block explicit git add of .secret file"
exit_code=0
output=$(echo '{"tool_input":{"command":"git add config.secret"}}' | bash plugin/scripts/block-secret-commits.sh 2>&1) || exit_code=$?
assert_exit "$exit_code" "2" "Exit code 2 for git add .secret"

echo ""
echo "Warn on git add -A (may include secrets)"
exit_code=0
output=$(echo '{"tool_input":{"command":"git add -A"}}' | bash plugin/scripts/block-secret-commits.sh 2>&1) || exit_code=$?
assert_exit "$exit_code" "0" "Exit code 0 for git add -A (warning only)"
assert_contains "$output" "ask" "Warning decision is 'ask'"
assert_contains "$output" "may stage" "Warning message mentions secrets"

echo ""
echo "Warn on git add . (current directory, may include secrets)"
exit_code=0
output=$(echo '{"tool_input":{"command":"git add ."}}' | bash plugin/scripts/block-secret-commits.sh 2>&1) || exit_code=$?
assert_exit "$exit_code" "0" "Exit code 0 for git add . (warning only)"
assert_contains "$output" "ask" "Warning decision is 'ask'"

echo ""
echo "Allow git add of regular source file"
exit_code=0
output=$(echo '{"tool_input":{"command":"git add src/main.ts"}}' | bash plugin/scripts/block-secret-commits.sh 2>&1) || exit_code=$?
assert_exit "$exit_code" "0" "Exit code 0 for git add src/main.ts"
assert_not_contains "$output" "Blocked" "No error message"

echo ""
echo "Allow git add of multiple source files"
exit_code=0
output=$(echo '{"tool_input":{"command":"git add src/main.ts src/utils.ts"}}' | bash plugin/scripts/block-secret-commits.sh 2>&1) || exit_code=$?
assert_exit "$exit_code" "0" "Exit code 0 for git add of multiple source files"

# ============================================================
echo ""
echo "=== Test block-claude-identity.sh ==="
# ============================================================

echo ""
echo "Block commit with Co-Authored-By: Claude"
exit_code=0
output=$(echo '{"tool_input":{"command":"git commit -m \"fix: thing with Co-Authored-By: Claude Sonnet\""}}' | bash plugin/scripts/block-claude-identity.sh 2>&1) || exit_code=$?
assert_exit "$exit_code" "2" "Exit code 2 for Co-Authored-By Claude"
assert_contains "$output" "Blocked" "Error message shown"

echo ""
echo "Block commit with Generated by Claude"
exit_code=0
output=$(echo '{"tool_input":{"command":"git commit -m \"Generated by Claude Code\""}}' | bash plugin/scripts/block-claude-identity.sh 2>&1) || exit_code=$?
assert_exit "$exit_code" "2" "Exit code 2 for Generated by Claude"

echo ""
echo "Block commit with AI generated attribution"
exit_code=0
output=$(echo '{"tool_input":{"command":"git commit -m \"AI generated: fix pattern\""}}' | bash plugin/scripts/block-claude-identity.sh 2>&1) || exit_code=$?
assert_exit "$exit_code" "2" "Exit code 2 for AI generated attribution"

echo ""
echo "Block PR creation with Claude identity in body"
exit_code=0
output=$(echo '{"tool_input":{"command":"gh pr create --title fix --body Generated with Claude Code"}}' | bash plugin/scripts/block-claude-identity.sh 2>&1) || exit_code=$?
assert_exit "$exit_code" "2" "Exit code 2 for PR with Claude Code attribution"
assert_contains "$output" "Blocked" "Error message shown"

echo ""
echo "Block PR with Co-Authored-By Claude in body"
exit_code=0
output=$(echo '{"tool_input":{"command":"gh pr create --title fix --body Co-Authored-By: Claude Sonnet"}}' | bash plugin/scripts/block-claude-identity.sh 2>&1) || exit_code=$?
assert_exit "$exit_code" "2" "Exit code 2 for PR with Co-Authored-By"

echo ""
echo "Allow normal commit message"
exit_code=0
output=$(echo '{"tool_input":{"command":"git commit -m \"fix: normal message\""}}' | bash plugin/scripts/block-claude-identity.sh 2>&1) || exit_code=$?
assert_exit "$exit_code" "0" "Exit code 0 for normal commit"
assert_not_contains "$output" "Blocked" "No error message"

echo ""
echo "Allow normal PR creation"
exit_code=0
output=$(echo '{"tool_input":{"command":"gh pr create --title fix --body Regular PR body"}}' | bash plugin/scripts/block-claude-identity.sh 2>&1) || exit_code=$?
assert_exit "$exit_code" "0" "Exit code 0 for normal PR"
assert_not_contains "$output" "Blocked" "No error message"

# ============================================================
echo ""
echo "=== Test warn-secret-files.sh ==="
# ============================================================

echo ""
echo "Block write to .env file"
output=$(echo '{"tool_input":{"file_path":"/project/.env"}}' | bash plugin/scripts/warn-secret-files.sh 2>&1 || true)
assert_contains "$output" "block" "Write to .env is blocked"
assert_contains "$output" "decision" "Output is valid JSON"

echo ""
echo "Block write to files matching secret patterns"
output=$(echo '{"tool_input":{"file_path":"/project/config.env"}}' | bash plugin/scripts/warn-secret-files.sh 2>&1 || true)
assert_contains "$output" "block" "Write to config.env is blocked (ends in .env)"

echo ""
echo "Block write to .pem file"
output=$(echo '{"tool_input":{"file_path":"/project/secret.pem"}}' | bash plugin/scripts/warn-secret-files.sh 2>&1 || true)
assert_contains "$output" "block" "Write to .pem is blocked"

echo ""
echo "Block write to .key file"
output=$(echo '{"tool_input":{"file_path":"/project/private.key"}}' | bash plugin/scripts/warn-secret-files.sh 2>&1 || true)
assert_contains "$output" "block" "Write to .key is blocked"

echo ""
echo "Block write to credentials file"
output=$(echo '{"tool_input":{"file_path":"/project/credentials"}}' | bash plugin/scripts/warn-secret-files.sh 2>&1 || true)
assert_contains "$output" "block" "Write to credentials is blocked"

echo ""
echo "Block write to credentials.json"
output=$(echo '{"tool_input":{"file_path":"/project/credentials.json"}}' | bash plugin/scripts/warn-secret-files.sh 2>&1 || true)
assert_contains "$output" "block" "Write to credentials.json is blocked"

echo ""
echo "Block write to .secret file"
output=$(echo '{"tool_input":{"file_path":"/project/config.secret"}}' | bash plugin/scripts/warn-secret-files.sh 2>&1 || true)
assert_contains "$output" "block" "Write to .secret is blocked"

echo ""
echo "Block write to secrets directory"
output=$(echo '{"tool_input":{"file_path":"/project/secrets/api-key"}}' | bash plugin/scripts/warn-secret-files.sh 2>&1 || true)
assert_contains "$output" "block" "Write to secrets/ is blocked"

echo ""
echo "Allow write to regular source file"
output=$(echo '{"tool_input":{"file_path":"/project/src/main.ts"}}' | bash plugin/scripts/warn-secret-files.sh 2>&1 || true)
assert_not_contains "$output" "block" "Write to src/main.ts is allowed"

echo ""
echo "Allow write to regular .json file"
output=$(echo '{"tool_input":{"file_path":"/project/package.json"}}' | bash plugin/scripts/warn-secret-files.sh 2>&1 || true)
assert_not_contains "$output" "block" "Write to package.json is allowed"

echo ""
echo "Allow write with empty file path"
output=$(echo '{"tool_input":{"file_path":""}}' | bash plugin/scripts/warn-secret-files.sh 2>&1 || true)
assert_not_contains "$output" "block" "Empty file path is allowed"

echo ""
echo "Allow write with missing file_path field"
output=$(echo '{"tool_input":{}}' | bash plugin/scripts/warn-secret-files.sh 2>&1 || true)
assert_not_contains "$output" "block" "Missing file_path field is allowed"

# ============================================================
echo ""
echo "=== Test block-wrong-plan-dir.sh ==="
# ============================================================

echo ""
echo "Block save to docs/superpowers/plans/"
exit_code=0
output=$(echo '{"tool_input":{"file_path":"docs/superpowers/plans/my-plan.md"}}' | bash plugin/scripts/block-wrong-plan-dir.sh 2>&1) || exit_code=$?
assert_exit "$exit_code" "2" "Exit code 2 for docs/superpowers/plans/"
assert_contains "$output" "Blocked" "Error message shown"

echo ""
echo "Block save to docs/superpowers/plans/ (absolute path)"
exit_code=0
output=$(echo '{"tool_input":{"file_path":"/Users/x/project/docs/superpowers/plans/plan.md"}}' | bash plugin/scripts/block-wrong-plan-dir.sh 2>&1) || exit_code=$?
assert_exit "$exit_code" "2" "Exit code 2 for absolute path to docs/superpowers/plans/"

echo ""
echo "Allow save to ~/.claude/plans/"
exit_code=0
output=$(echo '{"tool_input":{"file_path":"/Users/x/.claude/plans/my-plan.md"}}' | bash plugin/scripts/block-wrong-plan-dir.sh 2>&1 || exit_code=$?)
assert_exit "$exit_code" "0" "Exit code 0 for ~/.claude/plans/"
assert_not_contains "$output" "Blocked" "No error message"

echo ""
echo "Allow save to regular source file"
exit_code=0
output=$(echo '{"tool_input":{"file_path":"src/utils.ts"}}' | bash plugin/scripts/block-wrong-plan-dir.sh 2>&1) || exit_code=$?
assert_exit "$exit_code" "0" "Exit code 0 for src/utils.ts"

echo ""
echo "Allow save to home directory file"
exit_code=0
output=$(echo '{"tool_input":{"file_path":"/Users/x/.bashrc"}}' | bash plugin/scripts/block-wrong-plan-dir.sh 2>&1) || exit_code=$?
assert_exit "$exit_code" "0" "Exit code 0 for home directory file"

# ============================================================
echo ""
echo "=== Additional edge case tests ==="
# ============================================================

echo ""
echo "block-protected-push: uppercase branch name handling"
output=$(echo '{"tool_input":{"command":"git push origin MAIN"}}' | bash plugin/scripts/block-protected-push.sh 2>&1 || true)
assert_not_contains "$output" "block" "Uppercase MAIN is not protected (case sensitive)"

echo ""
echo "block-no-verify: --no-verify in middle of command"
exit_code=0
output=$(echo '{"tool_input":{"command":"git commit --no-verify -m test"}}' | bash plugin/scripts/block-no-verify.sh 2>&1) || exit_code=$?
assert_exit "$exit_code" "2" "Block --no-verify even when not at end"

echo ""
echo "block-secret-commits: .env in middle of filename"
exit_code=0
output=$(echo '{"tool_input":{"command":"git add config.env.backup"}}' | bash plugin/scripts/block-secret-commits.sh 2>&1) || exit_code=$?
assert_exit "$exit_code" "0" "Allow .env in middle of filename (not exact match)"

echo ""
echo "block-claude-identity: case-insensitive Claude matching"
exit_code=0
output=$(echo '{"tool_input":{"command":"git commit -m \"generated by claude code\""}}' | bash plugin/scripts/block-claude-identity.sh 2>&1) || exit_code=$?
assert_exit "$exit_code" "2" "Case-insensitive matching of claude identity"

echo ""
echo "warn-secret-files: .p12 file detection"
output=$(echo '{"tool_input":{"file_path":"/project/certificate.p12"}}' | bash plugin/scripts/warn-secret-files.sh 2>&1 || true)
assert_contains "$output" "block" "Block .p12 files"

echo ""
echo "warn-secret-files: .pfx file detection"
output=$(echo '{"tool_input":{"file_path":"/project/cert.pfx"}}' | bash plugin/scripts/warn-secret-files.sh 2>&1 || true)
assert_contains "$output" "block" "Block .pfx files"

echo ""
echo "warn-secret-files: .jks keystore detection"
output=$(echo '{"tool_input":{"file_path":"/project/keystore.jks"}}' | bash plugin/scripts/warn-secret-files.sh 2>&1 || true)
assert_contains "$output" "block" "Block .jks files"

echo ""
echo "block-secret-commits: git add with multiple secret files"
exit_code=0
output=$(echo '{"tool_input":{"command":"git add .env credentials.json"}}' | bash plugin/scripts/block-secret-commits.sh 2>&1) || exit_code=$?
assert_exit "$exit_code" "2" "Block when adding multiple secret files"

echo ""
echo "block-protected-push: empty command"
output=$(echo '{"tool_input":{"command":""}}' | bash plugin/scripts/block-protected-push.sh 2>&1 || true)
assert_not_contains "$output" "block" "Empty command is allowed"

echo ""
echo "block-no-verify: empty command"
exit_code=0
output=$(echo '{"tool_input":{"command":""}}' | bash plugin/scripts/block-no-verify.sh 2>&1) || exit_code=$?
assert_exit "$exit_code" "0" "Empty command passes (no flags)"

# ============================================================
echo ""
echo "================================"
echo "$PASS passed, $FAIL failed"
echo "================================"

[ "$FAIL" -eq 0 ]
