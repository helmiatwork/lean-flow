#!/usr/bin/env bash
# Test suite for plugin/scripts/load-config.sh
# Uses lightweight inline test framework

set -e

PASS=0
FAIL=0

assert_eq() {
  if [ "$1" = "$2" ]; then
    echo "✓ $3"
    PASS=$((PASS+1))
  else
    echo "✗ $3 (got '$1', want '$2')"
    FAIL=$((FAIL+1))
  fi
}

assert_contains() {
  if echo "$1" | grep -q "$2"; then
    echo "✓ $3"
    PASS=$((PASS+1))
  else
    echo "✗ $3 (output: '$1')"
    FAIL=$((FAIL+1))
  fi
}

# Helper to source load-config in isolated environment
source_config() {
  local test_home="$1"
  (
    export HOME="$test_home"
    unset LEAN_FLOW_PROTECTED_BRANCHES LEAN_FLOW_FIXER_MODEL LEAN_FLOW_ORACLE_MODEL
    unset LEAN_FLOW_EXPLORER_MODEL LEAN_FLOW_DREAM_SESSIONS LEAN_FLOW_DREAM_HOURS
    unset LEAN_FLOW_ENABLE_PLAYWRIGHT LEAN_FLOW_ENABLE_MONITOR LEAN_FLOW_ENABLE_KNOWLEDGE
    unset LEAN_FLOW_ENABLE_RTK LEAN_FLOW_BRANCH_PREFIXES
    source /Users/theresiaputri/repo/lean-flow/plugin/scripts/load-config.sh
    echo "PROTECTED_BRANCHES=$LEAN_FLOW_PROTECTED_BRANCHES"
    echo "FIXER_MODEL=$LEAN_FLOW_FIXER_MODEL"
    echo "ORACLE_MODEL=$LEAN_FLOW_ORACLE_MODEL"
    echo "EXPLORER_MODEL=$LEAN_FLOW_EXPLORER_MODEL"
    echo "DREAM_SESSIONS=$LEAN_FLOW_DREAM_SESSIONS"
    echo "DREAM_HOURS=$LEAN_FLOW_DREAM_HOURS"
    echo "ENABLE_PLAYWRIGHT=$LEAN_FLOW_ENABLE_PLAYWRIGHT"
    echo "ENABLE_MONITOR=$LEAN_FLOW_ENABLE_MONITOR"
    echo "ENABLE_KNOWLEDGE=$LEAN_FLOW_ENABLE_KNOWLEDGE"
    echo "ENABLE_RTK=$LEAN_FLOW_ENABLE_RTK"
    echo "BRANCH_PREFIXES=$LEAN_FLOW_BRANCH_PREFIXES"
  )
}

echo "=== Test 1: Defaults (no config file) ==="
test_home=$(mktemp -d)
output=$(source_config "$test_home")
rm -rf "$test_home"

assert_eq "$(echo "$output" | grep '^PROTECTED_BRANCHES=' | cut -d= -f2)" "main master staging" "default PROTECTED_BRANCHES"
assert_eq "$(echo "$output" | grep '^FIXER_MODEL=' | cut -d= -f2)" "sonnet" "default FIXER_MODEL"
assert_eq "$(echo "$output" | grep '^ORACLE_MODEL=' | cut -d= -f2)" "opus" "default ORACLE_MODEL"
assert_eq "$(echo "$output" | grep '^EXPLORER_MODEL=' | cut -d= -f2)" "haiku" "default EXPLORER_MODEL"
assert_eq "$(echo "$output" | grep '^DREAM_SESSIONS=' | cut -d= -f2)" "5" "default DREAM_SESSIONS"
assert_eq "$(echo "$output" | grep '^DREAM_HOURS=' | cut -d= -f2)" "24" "default DREAM_HOURS"
assert_eq "$(echo "$output" | grep '^ENABLE_PLAYWRIGHT=' | cut -d= -f2)" "true" "default ENABLE_PLAYWRIGHT"
assert_eq "$(echo "$output" | grep '^ENABLE_MONITOR=' | cut -d= -f2)" "true" "default ENABLE_MONITOR"
assert_eq "$(echo "$output" | grep '^ENABLE_KNOWLEDGE=' | cut -d= -f2)" "true" "default ENABLE_KNOWLEDGE"
assert_eq "$(echo "$output" | grep '^ENABLE_RTK=' | cut -d= -f2)" "true" "default ENABLE_RTK"
assert_contains "$(echo "$output" | grep '^BRANCH_PREFIXES=' | cut -d= -f2)" "feature fix improvement" "default BRANCH_PREFIXES includes expected values"

echo ""
echo "=== Test 2: Override via config file ==="
test_home=$(mktemp -d)
mkdir -p "$test_home/.claude"
cat > "$test_home/.claude/lean-flow.json" << 'EOF'
{
  "models": {
    "fixer": "opus",
    "oracle": "sonnet"
  },
  "enable": {
    "monitor": "false",
    "playwright": "disabled"
  }
}
EOF
output=$(source_config "$test_home")
rm -rf "$test_home"

assert_eq "$(echo "$output" | grep '^FIXER_MODEL=' | cut -d= -f2)" "opus" "override FIXER_MODEL from config"
assert_eq "$(echo "$output" | grep '^ORACLE_MODEL=' | cut -d= -f2)" "sonnet" "override ORACLE_MODEL from config"
assert_eq "$(echo "$output" | grep '^ENABLE_MONITOR=' | cut -d= -f2)" "false" "override ENABLE_MONITOR from config (must be string)"
assert_eq "$(echo "$output" | grep '^ENABLE_PLAYWRIGHT=' | cut -d= -f2)" "disabled" "override ENABLE_PLAYWRIGHT from config (must be string)"
assert_eq "$(echo "$output" | grep '^EXPLORER_MODEL=' | cut -d= -f2)" "haiku" "non-overridden EXPLORER_MODEL remains default"

echo ""
echo "=== Test 3: Array protectedBranches ==="
test_home=$(mktemp -d)
mkdir -p "$test_home/.claude"
cat > "$test_home/.claude/lean-flow.json" << 'EOF'
{
  "protectedBranches": ["main", "production", "staging"]
}
EOF
output=$(source_config "$test_home")
rm -rf "$test_home"

assert_eq "$(echo "$output" | grep '^PROTECTED_BRANCHES=' | cut -d= -f2)" "main production staging" "array protectedBranches joined with spaces"

echo ""
echo "=== Test 4: String protectedBranches ==="
test_home=$(mktemp -d)
mkdir -p "$test_home/.claude"
cat > "$test_home/.claude/lean-flow.json" << 'EOF'
{
  "protectedBranches": "main production release"
}
EOF
output=$(source_config "$test_home")
rm -rf "$test_home"

assert_eq "$(echo "$output" | grep '^PROTECTED_BRANCHES=' | cut -d= -f2)" "main production release" "string protectedBranches passed through"

echo ""
echo "=== Test 5: Partial config file (missing keys use defaults) ==="
test_home=$(mktemp -d)
mkdir -p "$test_home/.claude"
cat > "$test_home/.claude/lean-flow.json" << 'EOF'
{
  "models": {
    "fixer": "haiku"
  }
}
EOF
output=$(source_config "$test_home")
rm -rf "$test_home"

assert_eq "$(echo "$output" | grep '^FIXER_MODEL=' | cut -d= -f2)" "haiku" "partial config overrides only fixer"
assert_eq "$(echo "$output" | grep '^ORACLE_MODEL=' | cut -d= -f2)" "opus" "partial config preserves oracle default"
assert_eq "$(echo "$output" | grep '^EXPLORER_MODEL=' | cut -d= -f2)" "haiku" "partial config preserves explorer default"
assert_eq "$(echo "$output" | grep '^PROTECTED_BRANCHES=' | cut -d= -f2)" "main master staging" "partial config preserves protected branches default"

echo ""
echo "=== Test 6: Array branchPrefixes ==="
test_home=$(mktemp -d)
mkdir -p "$test_home/.claude"
cat > "$test_home/.claude/lean-flow.json" << 'EOF'
{
  "branchPrefixes": ["feature", "bug", "hotfix"]
}
EOF
output=$(source_config "$test_home")
rm -rf "$test_home"

assert_eq "$(echo "$output" | grep '^BRANCH_PREFIXES=' | cut -d= -f2)" "feature bug hotfix" "array branchPrefixes joined with spaces"

echo ""
echo "=== Test 7: jq not available (graceful fallback) ==="
test_home=$(mktemp -d)
mkdir -p "$test_home/.claude"
cat > "$test_home/.claude/lean-flow.json" << 'EOF'
{
  "models": {
    "fixer": "opus"
  }
}
EOF
# Source config with jq hidden by creating a fake jq that returns error
fake_bin=$(mktemp -d)
cat > "$fake_bin/jq" << 'FAKEJQ'
#!/bin/bash
exit 1
FAKEJQ
chmod +x "$fake_bin/jq"
output=$(
  export HOME="$test_home"
  export PATH="$fake_bin:/usr/bin:/bin"
  unset LEAN_FLOW_PROTECTED_BRANCHES LEAN_FLOW_FIXER_MODEL LEAN_FLOW_ORACLE_MODEL
  unset LEAN_FLOW_EXPLORER_MODEL LEAN_FLOW_DREAM_SESSIONS LEAN_FLOW_DREAM_HOURS
  unset LEAN_FLOW_ENABLE_PLAYWRIGHT LEAN_FLOW_ENABLE_MONITOR LEAN_FLOW_ENABLE_KNOWLEDGE
  unset LEAN_FLOW_ENABLE_RTK LEAN_FLOW_BRANCH_PREFIXES
  source /Users/theresiaputri/repo/lean-flow/plugin/scripts/load-config.sh
  echo "FIXER_MODEL=$LEAN_FLOW_FIXER_MODEL"
  echo "ORACLE_MODEL=$LEAN_FLOW_ORACLE_MODEL"
)
rm -rf "$test_home" "$fake_bin"

# Should use defaults when jq is not available or fails
assert_eq "$(echo "$output" | grep '^FIXER_MODEL=' | cut -d= -f2)" "sonnet" "without jq, fixer uses default"
assert_eq "$(echo "$output" | grep '^ORACLE_MODEL=' | cut -d= -f2)" "opus" "without jq, oracle uses default"

echo ""
echo "=== Test 8: Dream settings override ==="
test_home=$(mktemp -d)
mkdir -p "$test_home/.claude"
cat > "$test_home/.claude/lean-flow.json" << 'EOF'
{
  "dream": {
    "sessions": 10,
    "hours": 48
  }
}
EOF
output=$(source_config "$test_home")
rm -rf "$test_home"

assert_eq "$(echo "$output" | grep '^DREAM_SESSIONS=' | cut -d= -f2)" "10" "override DREAM_SESSIONS"
assert_eq "$(echo "$output" | grep '^DREAM_HOURS=' | cut -d= -f2)" "48" "override DREAM_HOURS"

echo ""
echo "=== Test 9: All features override ==="
test_home=$(mktemp -d)
mkdir -p "$test_home/.claude"
cat > "$test_home/.claude/lean-flow.json" << 'EOF'
{
  "protectedBranches": ["main"],
  "models": {
    "fixer": "claude-opus",
    "oracle": "claude-sonnet",
    "explorer": "claude-haiku"
  },
  "dream": {
    "sessions": 7,
    "hours": 36
  },
  "enable": {
    "playwright": "no",
    "monitor": "off",
    "knowledge": "disabled",
    "rtk": "false"
  },
  "branchPrefixes": ["feat", "fix", "refactor"]
}
EOF
output=$(source_config "$test_home")
rm -rf "$test_home"

assert_eq "$(echo "$output" | grep '^PROTECTED_BRANCHES=' | cut -d= -f2)" "main" "all overrides: protected branches"
assert_eq "$(echo "$output" | grep '^FIXER_MODEL=' | cut -d= -f2)" "claude-opus" "all overrides: fixer model"
assert_eq "$(echo "$output" | grep '^ORACLE_MODEL=' | cut -d= -f2)" "claude-sonnet" "all overrides: oracle model"
assert_eq "$(echo "$output" | grep '^EXPLORER_MODEL=' | cut -d= -f2)" "claude-haiku" "all overrides: explorer model"
assert_eq "$(echo "$output" | grep '^DREAM_SESSIONS=' | cut -d= -f2)" "7" "all overrides: dream sessions"
assert_eq "$(echo "$output" | grep '^DREAM_HOURS=' | cut -d= -f2)" "36" "all overrides: dream hours"
assert_eq "$(echo "$output" | grep '^ENABLE_PLAYWRIGHT=' | cut -d= -f2)" "no" "all overrides: playwright disabled"
assert_eq "$(echo "$output" | grep '^ENABLE_MONITOR=' | cut -d= -f2)" "off" "all overrides: monitor disabled"
assert_eq "$(echo "$output" | grep '^ENABLE_KNOWLEDGE=' | cut -d= -f2)" "disabled" "all overrides: knowledge disabled"
assert_eq "$(echo "$output" | grep '^ENABLE_RTK=' | cut -d= -f2)" "false" "all overrides: rtk disabled"
assert_eq "$(echo "$output" | grep '^BRANCH_PREFIXES=' | cut -d= -f2)" "feat fix refactor" "all overrides: branch prefixes"

echo ""
echo "================================"
echo "$PASS passed, $FAIL failed"
echo "================================"

[ "$FAIL" -eq 0 ]
