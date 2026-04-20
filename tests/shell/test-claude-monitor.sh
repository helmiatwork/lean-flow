#!/usr/bin/env bash
# Test suite for plugin/scripts/claude-monitor/claude-usage.3m.sh
# Tests SwiftBar display logic, cache reading, and menu actions

set -e

PASS=0
FAIL=0
SCRIPT_PATH="/Users/theresiaputri/repo/lean-flow/plugin/scripts/claude-monitor/claude-usage.3m.sh"

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
    echo "✗ $3 (expected substring '$2', got: '$1')"
    FAIL=$((FAIL+1))
  fi
}

assert_not_contains() {
  if ! echo "$1" | grep -q "$2"; then
    echo "✓ $3"
    PASS=$((PASS+1))
  else
    echo "✗ $3 (unexpected substring '$2' found in: '$1')"
    FAIL=$((FAIL+1))
  fi
}

# Check if jq is available
if ! command -v jq &> /dev/null; then
  echo "⚠ jq not found. Skipping tests."
  exit 0
fi

# Setup test environment
test_home=$(mktemp -d)
export HOME="$test_home"
CACHE_FILE="/tmp/claude-usage-cache.json"
BLINK_FLAG="/tmp/claude-usage-blink"
CONFIG_FILE="$test_home/.config/claude-usage/config"

cleanup() {
  rm -rf "$test_home" 2>/dev/null || true
  rm -f "$CACHE_FILE" "$BLINK_FLAG" 2>/dev/null || true
}

trap cleanup EXIT

echo "=== Test 1: No cache file → gray output ==="
rm -f "$CACHE_FILE" "$BLINK_FLAG"
output=$(bash "$SCRIPT_PATH" 2>/dev/null)
assert_contains "$output" "☁️ --% | color=#888888" "no cache shows gray cloud icon"

echo ""
echo "=== Test 2: Cache with session_pct='?' → gray output ==="
rm -f "$CACHE_FILE" "$BLINK_FLAG"
cat > "$CACHE_FILE" << 'EOF'
{
  "session": "?",
  "week_all": "?",
  "week_sonnet": "?",
  "session_reset": "?",
  "week_all_reset": "?",
  "week_sonnet_reset": "?",
  "updated": "2026-04-20 10:00:00"
}
EOF
output=$(bash "$SCRIPT_PATH" 2>/dev/null)
assert_contains "$output" "☁️ --% | color=#888888" "session_pct='?' shows gray cloud icon"

echo ""
echo "=== Test 3: Low usage (10/20/5) → green icon ==="
rm -f "$CACHE_FILE" "$BLINK_FLAG"
cat > "$CACHE_FILE" << 'EOF'
{
  "session": 10,
  "week_all": 20,
  "week_sonnet": 5,
  "session_reset": "2026-05-20",
  "week_all_reset": "2026-04-27",
  "week_sonnet_reset": "2026-04-27",
  "updated": "2026-04-20 10:00:00"
}
EOF
output=$(bash "$SCRIPT_PATH" 2>/dev/null)
assert_contains "$output" "🟢" "low usage shows green icon"
assert_not_contains "$output" "☁️" "green icon output does not show cloud"

echo ""
echo "=== Test 4: Medium usage (55/20/5) → yellow icon ==="
rm -f "$CACHE_FILE" "$BLINK_FLAG"
cat > "$CACHE_FILE" << 'EOF'
{
  "session": 55,
  "week_all": 20,
  "week_sonnet": 5,
  "session_reset": "2026-05-20",
  "week_all_reset": "2026-04-27",
  "week_sonnet_reset": "2026-04-27",
  "updated": "2026-04-20 10:00:00"
}
EOF
output=$(bash "$SCRIPT_PATH" 2>/dev/null)
assert_contains "$output" "🟡" "medium usage shows yellow icon"
assert_not_contains "$output" "☁️" "yellow icon output does not show cloud"

echo ""
echo "=== Test 5: High usage (85/20/5) → red icon ==="
rm -f "$CACHE_FILE" "$BLINK_FLAG"
cat > "$CACHE_FILE" << 'EOF'
{
  "session": 85,
  "week_all": 20,
  "week_sonnet": 5,
  "session_reset": "2026-05-20",
  "week_all_reset": "2026-04-27",
  "week_sonnet_reset": "2026-04-27",
  "updated": "2026-04-20 10:00:00"
}
EOF
output=$(bash "$SCRIPT_PATH" 2>/dev/null)
assert_contains "$output" "🔴" "high usage shows red icon"
assert_not_contains "$output" "☁️" "red icon output does not show cloud"

echo ""
echo "=== Test 6: Fresh blink flag → ⚡ in title ==="
rm -f "$CACHE_FILE" "$BLINK_FLAG"
cat > "$CACHE_FILE" << 'EOF'
{
  "session": 30,
  "week_all": 20,
  "week_sonnet": 5,
  "session_reset": "2026-05-20",
  "week_all_reset": "2026-04-27",
  "week_sonnet_reset": "2026-04-27",
  "updated": "2026-04-20 10:00:00"
}
EOF
touch "$BLINK_FLAG"
output=$(bash "$SCRIPT_PATH" 2>/dev/null)
assert_contains "$output" "⚡" "fresh blink flag shows lightning icon"
assert_contains "$output" "color=#00ffcc" "blink state has cyan color"

echo ""
echo "=== Test 7: Stale blink flag (>10s old) → normal icon ==="
rm -f "$CACHE_FILE" "$BLINK_FLAG"
cat > "$CACHE_FILE" << 'EOF'
{
  "session": 30,
  "week_all": 20,
  "week_sonnet": 5,
  "session_reset": "2026-05-20",
  "week_all_reset": "2026-04-27",
  "week_sonnet_reset": "2026-04-27",
  "updated": "2026-04-20 10:00:00"
}
EOF
# Create stale blink flag (15 seconds ago)
touch -t "$(date -v-15S +%Y%m%d%H%M.%S)" "$BLINK_FLAG"
output=$(bash "$SCRIPT_PATH" 2>/dev/null)
assert_not_contains "$output" "⚡" "stale blink flag does not show lightning icon"
assert_contains "$output" "🟢" "stale blink flag reverts to normal icon"

echo ""
echo "=== Test 8: Display format contains ┊ separator ==="
rm -f "$CACHE_FILE" "$BLINK_FLAG"
cat > "$CACHE_FILE" << 'EOF'
{
  "session": 10,
  "week_all": 20,
  "week_sonnet": 5,
  "session_reset": "2026-05-20",
  "week_all_reset": "2026-04-27",
  "week_sonnet_reset": "2026-04-27",
  "updated": "2026-04-20 10:00:00"
}
EOF
output=$(bash "$SCRIPT_PATH" 2>/dev/null)
# First line should have the display with separators
first_line=$(echo "$output" | head -1)
assert_contains "$first_line" "10%(2026-05-20)┊20%(2026-04-27)┊5%(2026-04-27)" "display format has correct ┊ separators"

echo ""
echo "=== Test 9: set_interval writes config correctly ==="
rm -f "$CONFIG_FILE" "$CACHE_FILE" "$BLINK_FLAG"
mkdir -p "$(dirname "$CONFIG_FILE")"
bash "$SCRIPT_PATH" set_interval 120
exit_code=$?
assert_eq "$exit_code" "0" "set_interval exits with 0"
config_content=$(cat "$CONFIG_FILE")
assert_eq "$config_content" "refresh_seconds=120" "set_interval writes refresh_seconds to config"

echo ""
echo "=== Test 10: Dropdown contains expected labels ==="
rm -f "$CACHE_FILE" "$BLINK_FLAG"
cat > "$CACHE_FILE" << 'EOF'
{
  "session": 15,
  "week_all": 30,
  "week_sonnet": 10,
  "session_reset": "2026-05-20",
  "week_all_reset": "2026-04-27",
  "week_sonnet_reset": "2026-04-27",
  "updated": "2026-04-20 10:00:00"
}
EOF
output=$(bash "$SCRIPT_PATH" 2>/dev/null)
assert_contains "$output" "Session:" "dropdown contains 'Session:'"
assert_contains "$output" "Week (all):" "dropdown contains 'Week (all):'"
assert_contains "$output" "Week (sonnet):" "dropdown contains 'Week (sonnet):'"

echo ""
echo "================================"
echo "$PASS passed, $FAIL failed"
echo "================================"

[ "$FAIL" -eq 0 ]
