#!/bin/bash
# test-commands.sh — smoke tests for all command definitions

set -eu

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-.}"
COMMANDS_DIR="$PLUGIN_ROOT/plugin/commands"
PASS=0
FAIL=0

echo "=== Command Definitions Test Suite ===" >&2
echo "" >&2

# Helper: check command file
check_command() {
  local cmd_name="$1"
  local cmd_file="$COMMANDS_DIR/${cmd_name}.md"

  printf "Testing /%s ... " "$cmd_name" >&2

  # 1. File exists
  if [ ! -f "$cmd_file" ]; then
    echo "FAIL (file not found: $cmd_file)" >&2
    FAIL=$((FAIL + 1))
    return 1
  fi

  # 2. Has valid YAML frontmatter
  if ! head -1 "$cmd_file" | grep -q "^---$"; then
    echo "FAIL (missing YAML start marker)" >&2
    FAIL=$((FAIL + 1))
    return 1
  fi

  if ! grep -q "^name:" "$cmd_file"; then
    echo "FAIL (missing 'name' field in frontmatter)" >&2
    FAIL=$((FAIL + 1))
    return 1
  fi

  if ! grep -q "^description:" "$cmd_file"; then
    echo "FAIL (missing 'description' field in frontmatter)" >&2
    FAIL=$((FAIL + 1))
    return 1
  fi

  # 3. Has command heading (# /lean-flow:name or # /name)
  local heading1="# /lean-flow:$cmd_name"
  local heading2="# /$cmd_name"
  if ! grep -q "^$heading1$" "$cmd_file" && ! grep -q "^$heading2$" "$cmd_file"; then
    echo "FAIL (missing heading: '$heading1' or '$heading2')" >&2
    FAIL=$((FAIL + 1))
    return 1
  fi

  # 4. File is well-formed (has body content after frontmatter)
  local line_count
  line_count=$(wc -l < "$cmd_file")
  if [ "$line_count" -lt 10 ]; then
    echo "FAIL (file too short, likely empty or malformed)" >&2
    FAIL=$((FAIL + 1))
    return 1
  fi

  echo "OK" >&2
  PASS=$((PASS + 1))
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

echo "" >&2
echo "=== Summary ===" >&2
echo "Passed: $PASS" >&2
echo "Failed: $FAIL" >&2
echo "" >&2

if [ "$FAIL" -eq 0 ]; then
  echo "✅ All command definitions valid." >&2
  exit 0
else
  echo "❌ $FAIL command(s) failed validation." >&2
  exit 1
fi
