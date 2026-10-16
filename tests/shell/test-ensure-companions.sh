#!/usr/bin/env bash
# Tests for the new companion-plugin bootstrap scripts:
#   - plugin/scripts/ensure-omni.sh
#   - plugin/scripts/ensure-gitnexus.sh
#
# Each script must:
#   1. Exit 0 in all states (installed, uninstalled, hooks present, hooks absent)
#   2. Be idempotent — re-running with hooks already registered is a no-op
#   3. Honor the LEAN_FLOW_ENABLE_<NAME>=false opt-out from lean-flow.json
#   4. Skip cleanly when prerequisites (jq, npx, brew) are unavailable

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
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
    echo "✗ $3 (missing '$2')"
    FAIL=$((FAIL+1))
  fi
}

# Build a minimal fake settings.json/.claude.json + fake $PATH where needed
make_fake_home() {
  local home
  home=$(mktemp -d)
  mkdir -p "$home/.claude"
  cat > "$home/.claude/settings.json" <<'EOF'
{ "env": {}, "permissions": {}, "hooks": {}, "enabledPlugins": {} }
EOF
  cat > "$home/.claude.json" <<'EOF'
{ "mcpServers": {} }
EOF
  echo "$home"
}

# ─────────────────────────────────────────────────────────────────
echo "=== ensure-omni: opt-out via LEAN_FLOW_ENABLE_OMNI=false ==="
TEST_HOME=$(make_fake_home)
output=$(LEAN_FLOW_ENABLE_OMNI=false HOME="$TEST_HOME" \
  bash "${REPO_ROOT}/plugin/scripts/ensure-omni.sh" 2>&1)
exit_code=$?
assert_eq "$exit_code" "0" "opt-out exits 0"
assert_eq "$output" "" "opt-out produces no output"
rm -rf "$TEST_HOME"

echo ""
echo "=== ensure-omni: skip when omni hooks already registered in settings.json ==="
TEST_HOME=$(make_fake_home)
# Inject a fake omni hook entry
cat > "$TEST_HOME/.claude/settings.json" <<'EOF'
{
  "env": {},
  "hooks": { "PreToolUse": [ { "hooks": [ { "type": "command", "command": "/usr/bin/omni --pre-hook" } ] } ] },
  "enabledPlugins": {}
}
EOF
# Make omni discoverable on PATH so the install-check passes
fake_bin=$(mktemp -d)
cat > "$fake_bin/omni" <<'EOF'
#!/bin/sh
exit 0
EOF
chmod +x "$fake_bin/omni"
output=$(PATH="$fake_bin:$PATH" HOME="$TEST_HOME" \
  bash "${REPO_ROOT}/plugin/scripts/ensure-omni.sh" 2>&1)
exit_code=$?
assert_eq "$exit_code" "0" "registered-hook detection exits 0"
assert_eq "$output" "" "registered-hook detection is silent (idempotent)"
rm -rf "$TEST_HOME" "$fake_bin"

echo ""
echo "=== ensure-omni: graceful skip when omni missing AND brew missing ==="
TEST_HOME=$(make_fake_home)
# Simulate no omni AND no brew on PATH
restricted_path="/usr/bin:/bin"
output=$(PATH="$restricted_path" HOME="$TEST_HOME" \
  bash "${REPO_ROOT}/plugin/scripts/ensure-omni.sh" 2>&1)
exit_code=$?
assert_eq "$exit_code" "0" "missing-omni-no-brew exits 0"
assert_contains "$output" "OMNI not installed" "graceful skip message"
rm -rf "$TEST_HOME"

# ─────────────────────────────────────────────────────────────────
echo ""
echo "=== ensure-gitnexus: opt-out via LEAN_FLOW_ENABLE_GITNEXUS=false ==="
TEST_HOME=$(make_fake_home)
output=$(LEAN_FLOW_ENABLE_GITNEXUS=false HOME="$TEST_HOME" \
  bash "${REPO_ROOT}/plugin/scripts/ensure-gitnexus.sh" 2>&1)
exit_code=$?
assert_eq "$exit_code" "0" "opt-out exits 0"
assert_eq "$output" "" "opt-out is silent"
rm -rf "$TEST_HOME"

echo ""
echo "=== ensure-gitnexus: skip when MCP already registered ==="
TEST_HOME=$(make_fake_home)
cat > "$TEST_HOME/.claude.json" <<'EOF'
{ "mcpServers": { "gitnexus": { "command": "npx", "args": ["-y","gitnexus","mcp"] } } }
EOF
output=$(HOME="$TEST_HOME" bash "${REPO_ROOT}/plugin/scripts/ensure-gitnexus.sh" 2>&1)
exit_code=$?
assert_eq "$exit_code" "0" "already-registered exits 0"
assert_eq "$output" "" "already-registered is silent (idempotent)"
rm -rf "$TEST_HOME"

echo ""
echo "=== ensure-gitnexus: skip when user has gitnexus hook in settings.json ==="
TEST_HOME=$(make_fake_home)
# User has wired GitNexus their own way via settings.json hooks
cat > "$TEST_HOME/.claude/settings.json" <<'EOF'
{ "hooks": { "PreToolUse": [ { "hooks": [ { "type": "command", "command": "node ~/.claude/hooks/gitnexus/gitnexus-hook.cjs" } ] } ] } }
EOF
output=$(HOME="$TEST_HOME" bash "${REPO_ROOT}/plugin/scripts/ensure-gitnexus.sh" 2>&1)
exit_code=$?
assert_eq "$exit_code" "0" "user-wired-hook exits 0"
assert_eq "$output" "" "user-wired-hook is silent (don't double-register)"
rm -rf "$TEST_HOME"

echo ""
echo "=== ensure-gitnexus: registers MCP in fresh ~/.claude.json ==="
TEST_HOME=$(make_fake_home)
output=$(HOME="$TEST_HOME" bash "${REPO_ROOT}/plugin/scripts/ensure-gitnexus.sh" 2>&1)
exit_code=$?
assert_eq "$exit_code" "0" "fresh registration exits 0"
# Verify the MCP entry was actually written
if jq -e '.mcpServers["gitnexus"].command == "npx"' "$TEST_HOME/.claude.json" >/dev/null 2>&1; then
  registered=yes
else
  registered=no
fi
assert_eq "$registered" "yes" "gitnexus MCP entry written to ~/.claude.json"
assert_contains "$output" "GitNexus MCP registered" "systemMessage emitted"
rm -rf "$TEST_HOME"

echo ""
echo "=== ensure-gitnexus: re-run after registration is a no-op ==="
TEST_HOME=$(make_fake_home)
HOME="$TEST_HOME" bash "${REPO_ROOT}/plugin/scripts/ensure-gitnexus.sh" > /dev/null 2>&1
output=$(HOME="$TEST_HOME" bash "${REPO_ROOT}/plugin/scripts/ensure-gitnexus.sh" 2>&1)
assert_eq "$output" "" "second run is silent"
rm -rf "$TEST_HOME"

echo ""
echo "=== ensure-gitnexus: graceful skip when npx missing ==="
TEST_HOME=$(make_fake_home)
output=$(PATH="/usr/bin:/bin" HOME="$TEST_HOME" \
  bash "${REPO_ROOT}/plugin/scripts/ensure-gitnexus.sh" 2>&1)
exit_code=$?
assert_eq "$exit_code" "0" "missing-npx exits 0"
assert_eq "$output" "" "missing-npx is silent (no noise for users without node)"
rm -rf "$TEST_HOME"

# ─────────────────────────────────────────────────────────────────
echo ""
echo "=== hooks.json registers both ensure-* scripts ==="
HOOKS_JSON="${REPO_ROOT}/plugin/hooks/hooks.json"
assert_contains "$(cat $HOOKS_JSON)" "ensure-omni.sh" "ensure-omni wired into SessionStart"
assert_contains "$(cat $HOOKS_JSON)" "ensure-gitnexus.sh" "ensure-gitnexus wired into SessionStart"

echo ""
echo "================================"
echo "$PASS passed, $FAIL failed"
echo "================================"
[ "$FAIL" -eq 0 ]
