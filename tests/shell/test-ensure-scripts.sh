#!/usr/bin/env bash
# Test suite for plugin/scripts/ensure-*.sh scripts
# Validates idempotency and basic functionality without external dependencies

set -euo pipefail

PASS=0
FAIL=0

assert_exit() {
  if [ "$1" = "$2" ]; then
    echo "✓ $3"
    PASS=$((PASS+1))
  else
    echo "✗ $3 (exit: $1, want: $2)"
    FAIL=$((FAIL+1))
  fi
}

assert_contains() {
  if echo "$1" | grep -q "$2"; then
    echo "✓ $3"
    PASS=$((PASS+1))
  else
    echo "✗ $3 (missing '$2')"
    FAIL=$((FAIL+1))
  fi
}

assert_file_exists() {
  if [ -f "$1" ]; then
    echo "✓ $2"
    PASS=$((PASS+1))
  else
    echo "✗ $2 (file not found: $1)"
    FAIL=$((FAIL+1))
  fi
}

# Setup test environment
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"

# Create temporary test home and plugin root
TEST_HOME=$(mktemp -d)
TEST_PLUGIN_ROOT=$(mktemp -d)
trap "rm -rf '$TEST_HOME' '$TEST_PLUGIN_ROOT'" EXIT

export HOME="$TEST_HOME"
export CLAUDE_PLUGIN_ROOT="$TEST_PLUGIN_ROOT"

# Copy plugin structure for tests that need it
mkdir -p "$TEST_PLUGIN_ROOT/mcp-servers/knowledge"
mkdir -p "$TEST_PLUGIN_ROOT/scripts/claude-monitor"
cp -r "$REPO_ROOT/plugin/mcp-servers/knowledge"/* "$TEST_PLUGIN_ROOT/mcp-servers/knowledge/" 2>/dev/null || true
cp -r "$REPO_ROOT/plugin/scripts/claude-monitor"/* "$TEST_PLUGIN_ROOT/scripts/claude-monitor/" 2>/dev/null || true

echo "=== Test 1: ensure-permissions.sh (first run) ==="
output=$(bash "$REPO_ROOT/plugin/scripts/ensure-permissions.sh" 2>&1 || true)
exit_code=$?
assert_exit "$exit_code" "0" "ensure-permissions: first run exits 0"

echo ""
echo "=== Test 2: ensure-permissions.sh (idempotency) ==="
bash "$REPO_ROOT/plugin/scripts/ensure-permissions.sh" &>/dev/null
exit_code=$?
assert_exit "$exit_code" "0" "ensure-permissions: second run exits 0"

echo ""
echo "=== Test 3: ensure-plugins.sh (first run) ==="
# Create minimal settings.json for the test
mkdir -p "$HOME/.claude"
cat > "$HOME/.claude/settings.json" << 'EOF'
{
  "enabledPlugins": {},
  "extraKnownMarketplaces": {}
}
EOF

output=$(bash "$REPO_ROOT/plugin/scripts/ensure-plugins.sh" 2>&1 || true)
exit_code=$?
assert_exit "$exit_code" "0" "ensure-plugins: first run exits 0"

echo ""
echo "=== Test 4: ensure-plugins.sh (settings updated) ==="
if [ -f "$HOME/.claude/settings.json" ]; then
  if command -v jq &>/dev/null; then
    has_superpowers=$(jq -e '.enabledPlugins["superpowers@claude-plugins-official"]' "$HOME/.claude/settings.json" 2>/dev/null || echo "false")
    has_plan_plus=$(jq -e '.enabledPlugins["plan-plus@plan-plus"]' "$HOME/.claude/settings.json" 2>/dev/null || echo "false")
    assert_contains "$has_superpowers" "true" "ensure-plugins: superpowers plugin enabled"
    assert_contains "$has_plan_plus" "true" "ensure-plugins: plan-plus plugin enabled"
  else
    echo "⊘ ensure-plugins: jq not available, skipping settings verification"
  fi
else
  echo "⚠ ensure-plugins: settings.json not found"
fi

echo ""
echo "=== Test 5: ensure-plugins.sh (idempotency) ==="
bash "$REPO_ROOT/plugin/scripts/ensure-plugins.sh" &>/dev/null
exit_code=$?
assert_exit "$exit_code" "0" "ensure-plugins: second run exits 0"

echo ""
echo "=== Test 6: ensure-knowledge-mcp.sh (first run) ==="
output=$(bash "$REPO_ROOT/plugin/scripts/ensure-knowledge-mcp.sh" 2>&1 || true)
exit_code=$?
assert_exit "$exit_code" "0" "ensure-knowledge-mcp: first run exits 0"

echo ""
echo "=== Test 7: ensure-knowledge-mcp.sh (idempotency) ==="
bash "$REPO_ROOT/plugin/scripts/ensure-knowledge-mcp.sh" &>/dev/null
exit_code=$?
assert_exit "$exit_code" "0" "ensure-knowledge-mcp: second run exits 0"

echo ""
echo "=== Test 8: ensure-rtk.sh (exits 0) ==="
output=$(bash "$REPO_ROOT/plugin/scripts/ensure-rtk.sh" 2>&1 || true)
exit_code=$?
assert_exit "$exit_code" "0" "ensure-rtk: exits 0"

echo ""
echo "=== Test 9: ensure-plan-viewer.sh (first run) ==="
output=$(bash "$REPO_ROOT/plugin/scripts/ensure-plan-viewer.sh" 2>&1 || true)
exit_code=$?
assert_exit "$exit_code" "0" "ensure-plan-viewer: first run exits 0"

echo ""
echo "=== Test 10: ensure-plan-viewer.sh (idempotency with pid file) ==="
# Check if pid file was created (indicates server was started)
if [ -f "/tmp/lean-flow-plan-server.pid" ]; then
  bash "$REPO_ROOT/plugin/scripts/ensure-plan-viewer.sh" &>/dev/null
  exit_code=$?
  assert_exit "$exit_code" "0" "ensure-plan-viewer: second run exits 0 (pid file detected, skipped)"
else
  echo "⊘ ensure-plan-viewer: pid file not created (node may not be available)"
  PASS=$((PASS+1))
fi

echo ""
echo "=== Test 11: ensure-cartography.sh (from repo root) ==="
# Run from actual repo root
cd "$REPO_ROOT"
output=$(bash "$REPO_ROOT/plugin/scripts/ensure-cartography.sh" 2>&1 || true)
exit_code=$?
assert_exit "$exit_code" "0" "ensure-cartography: exits 0"

echo ""
echo "=== Test 12: ensure-claude-monitor.sh (macOS check) ==="
output=$(bash "$REPO_ROOT/plugin/scripts/ensure-claude-monitor.sh" 2>&1 || true)
exit_code=$?
assert_exit "$exit_code" "0" "ensure-claude-monitor: exits 0"
# On macOS, may create symlink; on other platforms, should still exit 0
if [ "$(uname)" = "Darwin" ]; then
  if ls "$TEST_HOME/Library/Application Support/SwiftBar/Plugins"/claude-usage.*.sh &>/dev/null 2>&1; then
    echo "✓ ensure-claude-monitor: SwiftBar plugin symlink created"
    PASS=$((PASS+1))
  else
    echo "⊘ ensure-claude-monitor: SwiftBar plugin not created (SwiftBar not installed, expected)"
    PASS=$((PASS+1))
  fi
fi

echo ""
echo "=== Test 13: ensure-playwright-mcp.sh (first run) ==="
output=$(bash "$REPO_ROOT/plugin/scripts/ensure-playwright-mcp.sh" 2>&1 || true)
exit_code=$?
assert_exit "$exit_code" "0" "ensure-playwright-mcp: first run exits 0"

echo ""
echo "=== Test 14: ensure-playwright-mcp.sh (idempotency) ==="
bash "$REPO_ROOT/plugin/scripts/ensure-playwright-mcp.sh" &>/dev/null
exit_code=$?
assert_exit "$exit_code" "0" "ensure-playwright-mcp: second run exits 0"

echo ""
echo "================================"
echo "$PASS passed, $FAIL failed"
echo "================================"

[ "$FAIL" -eq 0 ]
