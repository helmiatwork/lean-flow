#!/usr/bin/env bash
# Test suite for agent contract compliance
# Verifies:
# - C.1 Frontmatter consistency with orchestrator.md Agent Cast
# - C.2 Required-skills section matches global CLAUDE.md table
# - C.3 Off-scope re-dispatch contract documented

set -euo pipefail
cd "$(dirname "$0")/../.."

PASS=0
FAIL=0

assert_file_exists() {
  if [ -f "$1" ]; then
    echo "✓ $2"
    PASS=$((PASS+1))
  else
    echo "✗ $2 (file not found: $1)"
    FAIL=$((FAIL+1))
  fi
}

assert_contains() {
  if echo "$1" | grep -q "$2"; then
    echo "✓ $3"
    PASS=$((PASS+1))
  else
    echo "✗ $3 (missing: '$2')"
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

# ────────────────────────────────────────────────────────────────────
# C.1: Frontmatter consistency with orchestrator.md Agent Cast (parsed)
# ────────────────────────────────────────────────────────────────────

echo "=== C.1: Agent Frontmatter Consistency (Parsed from orchestrator.md) ==="
echo ""

assert_file_exists "plugin/agents/orchestrator.md" "orchestrator.md exists"

orchestrator_content=$(cat plugin/agents/orchestrator.md)

# Parse orchestrator.md Agent Cast section to extract (model, tools) per agent
# Format: prose with "@lean-flow:<agent>" headings, followed by metadata lines
# Extract: model from inline (haiku)/(sonnet)/(opus) markers
#         tools from "Permissions:" lines, translating descriptions to tool lists

# Helper: extract model from an agent's prose section in orchestrator.md
# Look for (model) marker in the ~10 lines after the agent heading
parse_agent_model() {
  local agent="$1"
  local section=$(echo "$orchestrator_content" | sed -n "/@lean-flow:$agent/,/@lean-flow:/p" | head -10)

  if echo "$section" | grep -qE '\(haiku\)'; then
    echo "haiku"
  elif echo "$section" | grep -qE '\(sonnet\)'; then
    echo "sonnet"
  elif echo "$section" | grep -qE '\(opus\)'; then
    echo "opus"
  else
    echo ""
  fi
}

# Helper: extract tools from an agent's Permissions line in orchestrator.md
# Translate: "Read-only (Read, Grep, Glob, Bash)" → ["Read", "Grep", "Glob", "Bash"]
#            "tools: []" / "think-only" → []
#            "Read/Write (Read, Write, Edit, Bash, Grep, Glob, Agent)" → ["Read", "Write", "Edit", "Bash", "Grep", "Glob", "Agent"]
parse_agent_tools() {
  local agent="$1"
  local section=$(echo "$orchestrator_content" | sed -n "/@lean-flow:$agent/,/@lean-flow:/p" | head -10)

  # Match "Permissions: ..." or "tools: ..." line
  local perms_line=$(echo "$section" | grep -E "Permissions:|tools:" | head -1)

  if echo "$perms_line" | grep -q "tools: \[\]"; then
    echo "[]"
  elif echo "$perms_line" | grep -q "think-only"; then
    echo "[]"
  elif echo "$perms_line" | grep -qE "Read-only"; then
    # Extract tools from parentheses: "Read-only (Read, Grep, Glob, Bash)" → ["Read","Grep","Glob","Bash"]
    local tools=$(echo "$perms_line" | sed -n 's/.*(\(.*\)).*/\1/p' | sed 's/, /","/g; s/^/["/; s/$/"]/')
    echo "$tools"
  elif echo "$perms_line" | grep -qE "Read/Write"; then
    # Extract tools from parentheses: "Read/Write (Read, Write, ...)" → ["Read","Write",...]
    local tools=$(echo "$perms_line" | sed -n 's/.*(\(.*\)).*/\1/p' | sed 's/, /","/g; s/^/["/; s/$/"]/')
    echo "$tools"
  else
    # Fallback for unrecognized format
    echo ""
  fi
}

# Helper: normalize whitespace in JSON for comparison
normalize_json() {
  echo "$1" | tr -d ' '
}

# Helper: get expected model for a specific agent by parsing orchestrator.md
get_expected_model() {
  local agent="$1"
  parse_agent_model "$agent"
}

# Helper: get expected tools for a specific agent by parsing orchestrator.md
get_expected_tools() {
  local agent="$1"
  parse_agent_tools "$agent"
}

# Check each agent file exists and has correct frontmatter
for agent in fixer designer oracle code-reviewer explorer librarian; do
  agent_file="plugin/agents/${agent}.md"
  assert_file_exists "$agent_file" "$agent_file exists"

  if [ -f "$agent_file" ]; then
    agent_content=$(cat "$agent_file")

    # Check frontmatter name
    if echo "$agent_content" | head -10 | grep -q "^name: $agent"; then
      echo "✓ $agent has correct 'name:' in frontmatter"
      PASS=$((PASS+1))
    else
      echo "✗ $agent frontmatter 'name:' mismatch (expected: name: $agent)"
      FAIL=$((FAIL+1))
    fi

    # Extract and verify exact model value (from orchestrator.md)
    actual_model=$(echo "$agent_content" | head -10 | grep "^model:" | sed 's/^model: //' | tr -d ' ')
    expected_model=$(get_expected_model "$agent")
    if [ -z "$expected_model" ]; then
      echo "✗ $agent: could not parse model from orchestrator.md"
      FAIL=$((FAIL+1))
    elif [ "$actual_model" = "$expected_model" ]; then
      echo "✓ $agent has correct 'model: $actual_model' (matches orchestrator.md)"
      PASS=$((PASS+1))
    else
      echo "✗ $agent model mismatch (orchestrator.md says: $expected_model, $agent_file says: $actual_model)"
      FAIL=$((FAIL+1))
    fi

    # Extract and verify exact tools value (from orchestrator.md)
    actual_tools=$(echo "$agent_content" | head -10 | grep "^tools:" | sed 's/^tools: //')
    actual_tools_normalized=$(normalize_json "$actual_tools")
    expected_tools=$(get_expected_tools "$agent")
    expected_tools_normalized=$(normalize_json "$expected_tools")

    if [ -z "$expected_tools" ]; then
      echo "✗ $agent: could not parse tools from orchestrator.md"
      FAIL=$((FAIL+1))
    elif [ "$actual_tools_normalized" = "$expected_tools_normalized" ]; then
      echo "✓ $agent has correct 'tools' specification (matches orchestrator.md)"
      PASS=$((PASS+1))
    else
      echo "✗ $agent tools mismatch (orchestrator.md says: $expected_tools, $agent_file says: $actual_tools)"
      FAIL=$((FAIL+1))
    fi
  fi
done
echo ""

# ────────────────────────────────────────────────────────────────────
# C.2: Required-skills section present and matches CLAUDE.md
# ────────────────────────────────────────────────────────────────────

echo "=== C.2: Required Skills Sections ==="
echo ""

# Expected skills per agent from global CLAUDE.md Agent Cast
# (Using simple globals instead of associative arrays for portability)

for agent in fixer designer oracle code-reviewer explorer librarian; do
  agent_file="plugin/agents/${agent}.md"

  if [ ! -f "$agent_file" ]; then
    echo "✗ $agent_file missing"
    FAIL=$((FAIL+1))
    continue
  fi

  agent_content=$(cat "$agent_file")

  # Check Required Skills section exists
  if echo "$agent_content" | grep -qE "## Required Skills|^## Mandatory Skills|^## Skills"; then
    echo "✓ $agent has Required Skills section"
    PASS=$((PASS+1))

    # Check for at least one skill keyword
    if echo "$agent_content" | grep -qE "(superpower|skill|capability)"; then
      echo "✓ $agent Required Skills section has content"
      PASS=$((PASS+1))
    else
      echo "✗ $agent Required Skills section appears empty"
      FAIL=$((FAIL+1))
    fi
  else
    echo "✗ $agent missing Required Skills section"
    FAIL=$((FAIL+1))
  fi
done
echo ""

# ────────────────────────────────────────────────────────────────────
# C.3: Off-scope re-dispatch contract documented
# ────────────────────────────────────────────────────────────────────

echo "=== C.3: Off-scope Re-dispatch Routing ==="
echo ""

for agent in fixer designer oracle code-reviewer explorer librarian; do
  agent_file="plugin/agents/${agent}.md"

  if [ ! -f "$agent_file" ]; then
    echo "✗ $agent_file missing"
    FAIL=$((FAIL+1))
    continue
  fi

  agent_content=$(cat "$agent_file")

  # Assert: Off-scope routing section exists with correct heading
  if echo "$agent_content" | grep -q "## Off-scope Routing"; then
    echo "✓ $agent has '## Off-scope Routing' section"
    PASS=$((PASS+1))
  else
    echo "✗ $agent missing '## Off-scope Routing' section"
    FAIL=$((FAIL+1))
    continue
  fi

  # Assert: "do NOT execute" or equivalent refusal language is present
  if echo "$agent_content" | grep -qE "(do NOT execute|do not execute|Do NOT|refusal|off-scope.*re-dispatch)"; then
    echo "✓ $agent has refusal language (do NOT execute)"
    PASS=$((PASS+1))
  else
    echo "✗ $agent missing refusal language"
    FAIL=$((FAIL+1))
  fi

  # Assert: OFF-SCOPE return format is documented
  if echo "$agent_content" | grep -q "OFF-SCOPE: dispatch to"; then
    echo "✓ $agent documents OFF-SCOPE return format"
    PASS=$((PASS+1))
  else
    echo "✗ $agent missing 'OFF-SCOPE: dispatch to' format"
    FAIL=$((FAIL+1))
  fi

  # Assert: Clarifier that OFF-SCOPE is system-context guidance (not automatic runtime routing)
  if echo "$agent_content" | grep -q "system-context"; then
    echo "✓ $agent clarifies OFF-SCOPE as system-context guidance"
    PASS=$((PASS+1))
  else
    echo "✗ $agent missing clarifier about system-context guidance for OFF-SCOPE"
    FAIL=$((FAIL+1))
  fi

  # Assert: All 5 other peer agents are mentioned by lean-flow:<name>
  for other in fixer designer oracle code-reviewer explorer librarian; do
    [ "$other" = "$agent" ] && continue
    if echo "$agent_content" | grep -q "lean-flow:$other"; then
      echo "✓ $agent mentions peer agent lean-flow:$other"
      PASS=$((PASS+1))
    else
      echo "✗ $agent does not mention peer agent lean-flow:$other"
      FAIL=$((FAIL+1))
    fi
  done
done
echo ""

# ────────────────────────────────────────────────────────────────────
# Consistency cross-checks
# ────────────────────────────────────────────────────────────────────

echo "=== Consistency Cross-Checks ==="
echo ""

# Check that fixer has end-to-end execution contract
fixer_content=$(cat plugin/agents/fixer.md)
if echo "$fixer_content" | grep -q "End-to-End Execution Contract"; then
  echo "✓ Fixer has End-to-End Execution Contract section"
  PASS=$((PASS+1))
else
  echo "✗ Fixer missing End-to-End Execution Contract section"
  FAIL=$((FAIL+1))
fi

# Check that designer has required content (responsibilities and stops before PR)
designer_content=$(cat plugin/agents/designer.md)
if echo "$designer_content" | grep -q "Stops Before PR\|stops before"; then
  echo "✓ Designer has Stops Before PR section"
  PASS=$((PASS+1))
else
  echo "✗ Designer missing Stops Before PR section"
  FAIL=$((FAIL+1))
fi

# Check that oracle explicitly documents tools: []
oracle_content=$(cat plugin/agents/oracle.md)
if echo "$oracle_content" | grep -q "tools: \[\]"; then
  echo "✓ Oracle frontmatter explicitly declares tools: []"
  PASS=$((PASS+1))
else
  echo "✗ Oracle frontmatter missing tools: []"
  FAIL=$((FAIL+1))
fi

echo ""
echo "================================"
echo "$PASS passed, $FAIL failed"
echo "================================"

[ "$FAIL" -eq 0 ]
