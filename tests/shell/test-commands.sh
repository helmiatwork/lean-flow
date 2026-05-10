#!/bin/bash
# test-commands.sh — smoke tests for all command definitions

set -euo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-.}"
COMMANDS_DIR="$PLUGIN_ROOT/plugin/commands"
PASS=0
FAIL=0

echo "=== Command Definitions Test Suite ==="
echo ""

# Helper: check command file
check_command() {
  local cmd_name="$1"
  local cmd_file="$COMMANDS_DIR/${cmd_name}.md"

  echo -n "Testing /$cmd_name ... "

  # 1. File exists
  if [ ! -f "$cmd_file" ]; then
    echo "FAIL (file not found: $cmd_file)"
    ((FAIL++))
    return 1
  fi

  # 2. Has valid YAML frontmatter
  if ! head -1 "$cmd_file" | grep -q "^---$"; then
    echo "FAIL (missing YAML start marker)"
    ((FAIL++))
    return 1
  fi

  if ! grep -q "^name:" "$cmd_file"; then
    echo "FAIL (missing 'name' field in frontmatter)"
    ((FAIL++))
    return 1
  fi

  if ! grep -q "^description:" "$cmd_file"; then
    echo "FAIL (missing 'description' field in frontmatter)"
    ((FAIL++))
    return 1
  fi

  # 3. Has command heading (# /lean-flow:name or # /name)
  local heading1="# /lean-flow:$cmd_name"
  local heading2="# /$cmd_name"
  if ! grep -q "^$heading1$" "$cmd_file" && ! grep -q "^$heading2$" "$cmd_file"; then
    echo "FAIL (missing heading: '$heading1' or '$heading2')"
    ((FAIL++))
    return 1
  fi

  # 4. File is well-formed (not empty, closes frontmatter)
  if ! grep -q "^---$" "$cmd_file" | head -2; then
    echo "FAIL (malformed frontmatter)"
    ((FAIL++))
    return 1
  fi

  echo "OK"
  ((PASS++))
  return 0
}

# Test all 10 commands
check_command "agents"
check_command "workflow"
check_command "generate-codemap"
check_command "update-codemap"
check_command "lint"
check_command "test"
check_command "status"
check_command "review"
check_command "sync-checklist"
check_command "pattern-search"

# Also check legacy commands still exist
check_command "project-doctor"
check_command "project-doctor-fix"

echo ""
echo "=== Summary ==="
echo "Passed: $PASS"
echo "Failed: $FAIL"
echo ""

if [ $FAIL -eq 0 ]; then
  echo "✅ All command definitions valid."
  exit 0
else
  echo "❌ $FAIL command(s) failed validation."
  exit 1
fi
