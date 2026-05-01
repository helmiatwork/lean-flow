#!/usr/bin/env bash
# Tests for check-dependencies.sh
#
# Verifies:
#   - All-green system produces zero output
#   - Missing REQUIRED dep emits a [REQUIRED] section
#   - Missing RECOMMENDED dep emits a [RECOMMENDED] section
#   - DEPRECATED plan-plus enablement emits a [DEPRECATED] section
#   - Cache silences a second run with the unchanged finding set
#   - Cache invalidates and re-warns when finding set changes
#   - Output is well-formed JSON with systemMessage

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="${REPO_ROOT}/plugin/scripts/check-dependencies.sh"

PASS=0
FAIL=0

assert_eq() {
  if [ "$1" = "$2" ]; then echo "✓ $3"; PASS=$((PASS+1))
  else echo "✗ $3 (got '$1', want '$2')"; FAIL=$((FAIL+1)); fi
}

assert_contains() {
  if echo "$1" | grep -q "$2"; then echo "✓ $3"; PASS=$((PASS+1))
  else echo "✗ $3 (missing '$2')"; FAIL=$((FAIL+1)); fi
}

assert_not_contains() {
  if ! echo "$1" | grep -q "$2"; then echo "✓ $3"; PASS=$((PASS+1))
  else echo "✗ $3 (unexpected '$2')"; FAIL=$((FAIL+1)); fi
}

# Build a "happy" home where every dep the script checks is satisfied.
make_happy_home() {
  local home
  home=$(mktemp -d)
  mkdir -p "$home/.claude/plugins/cache/claude-plugins-official/superpowers/5.0.0/skills/writing-plans"
  mkdir -p "$home/.claude/knowledge"
  : > "$home/.claude/knowledge/patterns.db"
  cat > "$home/.claude/settings.json" <<'EOF'
{ "env": {}, "hooks": { "PreToolUse": [ { "hooks": [ { "command": "/usr/bin/omni --pre" } ] } ] }, "enabledPlugins": {} }
EOF
  cat > "$home/.claude.json" <<'EOF'
{ "mcpServers": { "gitnexus": { "command": "npx" } } }
EOF
  echo "$home"
}

# Make a fake bin dir with stub binaries. We MUST symlink real jq + md5/cksum
# into the fake bin too — otherwise tests that try to restrict PATH to just
# the fake bin (to simulate "omni missing") would also lose jq, breaking the
# script. Conversely, including the real jq's directory in PATH on developer
# machines often pulls real omni in via the same brew bin.
make_fake_bin() {
  local bin
  bin=$(mktemp -d)
  for cmd in omni rtk node; do
    cat > "$bin/$cmd" <<'EOF'
#!/bin/sh
exit 0
EOF
    chmod +x "$bin/$cmd"
  done
  # Symlink real jq + hashing tool so the script can run with PATH=fake_bin only
  ln -s "$(/usr/bin/which jq 2>/dev/null || echo /usr/bin/jq)" "$bin/jq" 2>/dev/null
  for h in md5 md5sum cksum; do
    real=$(/usr/bin/which "$h" 2>/dev/null)
    [ -n "$real" ] && ln -s "$real" "$bin/$h" 2>/dev/null
  done
  echo "$bin"
}

# ─────────────────────────────────────────────────────────────────
echo "=== happy-path: all deps satisfied → zero output ==="
TEST_HOME=$(make_happy_home)
FAKE_BIN=$(make_fake_bin)
output=$(PATH="$FAKE_BIN:/usr/bin:/bin" HOME="$TEST_HOME" bash "$SCRIPT" 2>&1)
exit_code=$?
assert_eq "$exit_code" "0" "happy-path exits 0"
assert_eq "$output" "" "happy-path is silent"
rm -rf "$TEST_HOME" "$FAKE_BIN"

# ─────────────────────────────────────────────────────────────────
echo ""
echo "=== REQUIRED: missing superpowers triggers [REQUIRED] warning ==="
TEST_HOME=$(make_happy_home)
# Remove superpowers
rm -rf "$TEST_HOME/.claude/plugins/cache/claude-plugins-official"
FAKE_BIN=$(make_fake_bin)
output=$(PATH="$FAKE_BIN:/usr/bin:/bin" HOME="$TEST_HOME" bash "$SCRIPT" 2>&1)
assert_contains "$output" "REQUIRED" "[REQUIRED] section emitted"
assert_contains "$output" "superpowers" "names superpowers as missing"
# Verify JSON is well-formed
echo "$output" | jq -e '.systemMessage | length > 0' >/dev/null 2>&1 \
  && { echo "✓ output is valid JSON with systemMessage"; PASS=$((PASS+1)); } \
  || { echo "✗ output is malformed JSON"; FAIL=$((FAIL+1)); }
rm -rf "$TEST_HOME" "$FAKE_BIN"

# ─────────────────────────────────────────────────────────────────
echo ""
echo "=== RECOMMENDED: missing omni triggers [RECOMMENDED] warning ==="
TEST_HOME=$(make_happy_home)
# omni not in fake bin → missing
RESTRICTED_BIN=$(mktemp -d)
for cmd in rtk node; do
  cat > "$RESTRICTED_BIN/$cmd" <<'EOF'
#!/bin/sh
exit 0
EOF
  chmod +x "$RESTRICTED_BIN/$cmd"
done
ln -s "$(/usr/bin/which jq)" "$RESTRICTED_BIN/jq" 2>/dev/null
for h in md5 md5sum cksum; do
  real=$(/usr/bin/which "$h" 2>/dev/null)
  [ -n "$real" ] && ln -s "$real" "$RESTRICTED_BIN/$h" 2>/dev/null
done
output=$(PATH="$RESTRICTED_BIN:/usr/bin:/bin" HOME="$TEST_HOME" bash "$SCRIPT" 2>&1)
assert_contains "$output" "RECOMMENDED" "[RECOMMENDED] section emitted"
assert_contains "$output" "omni" "names omni as missing"
assert_contains "$output" "brew install omni" "includes install hint"
rm -rf "$TEST_HOME" "$RESTRICTED_BIN"

# ─────────────────────────────────────────────────────────────────
echo ""
echo "=== DEPRECATED: plan-plus enabled triggers [DEPRECATED] warning ==="
TEST_HOME=$(make_happy_home)
# Enable plan-plus in settings.json
cat > "$TEST_HOME/.claude/settings.json" <<'EOF'
{
  "env": {},
  "hooks": { "PreToolUse": [ { "hooks": [ { "command": "/usr/bin/omni --pre" } ] } ] },
  "enabledPlugins": { "plan-plus@plan-plus": true }
}
EOF
FAKE_BIN=$(make_fake_bin)
output=$(PATH="$FAKE_BIN:/usr/bin:/bin" HOME="$TEST_HOME" bash "$SCRIPT" 2>&1)
assert_contains "$output" "DEPRECATED" "[DEPRECATED] section emitted"
assert_contains "$output" "plan-plus" "names plan-plus as deprecated"
assert_contains "$output" "PR #20" "references the deprecation PR"
rm -rf "$TEST_HOME" "$FAKE_BIN"

# ─────────────────────────────────────────────────────────────────
echo ""
echo "=== caching: same finding set → second run is silent ==="
TEST_HOME=$(make_happy_home)
rm -rf "$TEST_HOME/.claude/plugins/cache/claude-plugins-official"
FAKE_BIN=$(make_fake_bin)
out1=$(PATH="$FAKE_BIN:/usr/bin:/bin" HOME="$TEST_HOME" bash "$SCRIPT" 2>&1)
out2=$(PATH="$FAKE_BIN:/usr/bin:/bin" HOME="$TEST_HOME" bash "$SCRIPT" 2>&1)
[ -n "$out1" ] && [ -z "$out2" ] \
  && { echo "✓ first run warns, second run silent (cache hit)"; PASS=$((PASS+1)); } \
  || { echo "✗ caching failed (out1='${out1:0:40}...' out2='${out2:0:40}...')"; FAIL=$((FAIL+1)); }
# Cache file present
ls "$TEST_HOME"/.lean-flow-dep-check.* >/dev/null 2>&1 \
  && { echo "✓ cache marker file exists"; PASS=$((PASS+1)); } \
  || { echo "✗ cache marker not created"; FAIL=$((FAIL+1)); }
rm -rf "$TEST_HOME" "$FAKE_BIN"

# ─────────────────────────────────────────────────────────────────
echo ""
echo "=== caching: different finding set → re-warns ==="
TEST_HOME=$(make_happy_home)
rm -rf "$TEST_HOME/.claude/plugins/cache/claude-plugins-official"
FAKE_BIN=$(make_fake_bin)
# First run: missing superpowers
out1=$(PATH="$FAKE_BIN:/usr/bin:/bin" HOME="$TEST_HOME" bash "$SCRIPT" 2>&1)
# Now also remove the rtk binary to change the finding set
rm -f "$FAKE_BIN/rtk"
out2=$(PATH="$FAKE_BIN:/usr/bin:/bin" HOME="$TEST_HOME" bash "$SCRIPT" 2>&1)
[ -n "$out2" ] \
  && { echo "✓ different finding set re-warns (cache invalidated)"; PASS=$((PASS+1)); } \
  || { echo "✗ should have re-warned with new finding"; FAIL=$((FAIL+1)); }
rm -rf "$TEST_HOME" "$FAKE_BIN"

# ─────────────────────────────────────────────────────────────────
echo ""
echo "=== hooks.json wires check-dependencies into SessionStart ==="
HOOKS_JSON="${REPO_ROOT}/plugin/hooks/hooks.json"
assert_contains "$(cat $HOOKS_JSON)" "check-dependencies.sh" "check-dependencies registered"

echo ""
echo "================================"
echo "$PASS passed, $FAIL failed"
echo "================================"
[ "$FAIL" -eq 0 ]
