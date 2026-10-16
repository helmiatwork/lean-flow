#!/usr/bin/env bash
# Behavioral tests for grammar-check.sh and workflow-enforce/{block-ai-attribution,block-no-verify,prepush-rubocop-rspec}.sh
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
S="$ROOT/plugin/scripts"
PASS=0
FAIL=0

# check <name> <script> <command> <expected-exit>
check() {
  local json actual
  json=$(jq -n --arg c "$3" '{tool_input:{command:$c}}')
  actual=0
  printf '%s' "$json" | bash "$2" >/dev/null 2>&1 || actual=$?
  if [ "$actual" = "$4" ]; then
    echo "✓ $1"; PASS=$((PASS+1))
  else
    echo "✗ $1 (got exit $actual, want $4)"; FAIL=$((FAIL+1))
  fi
}

echo "=== grammar-check.sh ==="
out=$(CLAUDE_PROJECT_DIR="$ROOT" bash "$S/grammar-check.sh" </dev/null 2>&1 || true)
if grep -q "grammar-check" <<<"$out"; then echo "✓ grammar-check.sh injects prompt"; PASS=$((PASS+1)); else echo "✗ grammar-check.sh injects prompt"; FAIL=$((FAIL+1)); fi

echo "=== block-ai-attribution.sh ==="
A="$S/workflow-enforce/block-ai-attribution.sh"
check "blocks Co-Authored-By Claude" "$A" 'git commit -m "x

Co-Authored-By: Claude <noreply@anthropic.com>"' 2
check "allows clean commit" "$A" 'git commit -m "fix thing"' 0
check "ignores non-commit commands" "$A" 'echo Co-Authored-By: Claude' 0
check "allows empty command" "$A" '' 0

echo "=== block-no-verify.sh ==="
V="$S/workflow-enforce/block-no-verify.sh"
flag="--no-""verify"
check "blocks hook-skip flag" "$V" "git commit $flag -m x" 2
check "blocks gpg-sign skip flag" "$V" 'git commit --no-gpg-sign -m x' 2
check "allows normal commit" "$V" 'git commit -m x' 0

echo "=== prepush-rubocop-rspec.sh ==="
P="$S/workflow-enforce/prepush-rubocop-rspec.sh"
check "ignores non-push" "$P" 'git status' 0
check "ignores branch delete" "$P" 'git push origin --delete foo' 0
check "no Gemfile -> allow push" "$P" 'git push origin main' 0

echo ""
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
