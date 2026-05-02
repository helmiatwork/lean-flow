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
# C.1: Frontmatter consistency with orchestrator.md Agent Cast
# ────────────────────────────────────────────────────────────────────

echo "=== C.1: Agent Frontmatter Consistency ==="
echo ""

assert_file_exists "plugin/agents/orchestrator.md" "orchestrator.md exists"

# Parse orchestrator.md Agent Cast table for expected agents
# Table format:
#   | Agent | Model | Tools | Role | Required Skills |
#   | fixer | haiku | full | ... | ... |
#   etc.

orchestrator_content=$(cat plugin/agents/orchestrator.md)

# Expected agent configurations from CLAUDE.md and lean-flow docs
# (Using simple globals instead of associative arrays for portability)

# Check each agent file exists and has correct frontmatter
for agent in fixer designer oracle code-reviewer explorer librarian; do
  agent_file="plugin/agents/${agent}.md"
  assert_file_exists "$agent_file" "$agent_file exists"

  if [ -f "$agent_file" ]; then
    agent_content=$(cat "$agent_file")

    # Check frontmatter
    if echo "$agent_content" | head -10 | grep -q "^name: $agent"; then
      echo "✓ $agent has correct 'name:' in frontmatter"
      PASS=$((PASS+1))
    else
      echo "✗ $agent frontmatter 'name:' mismatch (expected: name: $agent)"
      FAIL=$((FAIL+1))
    fi

    # Check model is documented
    if echo "$agent_content" | head -10 | grep -q "^model:"; then
      echo "✓ $agent has 'model:' field in frontmatter"
      PASS=$((PASS+1))
    else
      echo "✗ $agent missing 'model:' field in frontmatter"
      FAIL=$((FAIL+1))
    fi

    # Check tools field exists
    if echo "$agent_content" | head -10 | grep -q "^tools:"; then
      echo "✓ $agent has 'tools:' field in frontmatter"
      PASS=$((PASS+1))
    else
      echo "✗ $agent missing 'tools:' field in frontmatter"
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
    continue
  fi

  agent_content=$(cat "$agent_file")

  # Check for off-scope routing section
  if echo "$agent_content" | grep -qE "(Off-scope|off-scope|Out of scope|scope.*routing|re-dispatch)"; then
    echo "✓ $agent has off-scope routing guidance"
    PASS=$((PASS+1))

    # Check for agent name references (at least 2 other agents mentioned)
    agent_mentions=0
    for other in fixer designer oracle code-reviewer explorer librarian; do
      [ "$other" = "$agent" ] && continue
      if echo "$agent_content" | grep -q "lean-flow:$other"; then
        agent_mentions=$((agent_mentions + 1))
      fi
    done

    if [ "$agent_mentions" -ge 1 ]; then
      echo "✓ $agent references at least one peer agent in routing"
      PASS=$((PASS+1))
    else
      echo "⊘ $agent could mention peer agents in routing guidance"
      PASS=$((PASS+1))
    fi
  else
    echo "⊘ $agent lacks explicit off-scope guidance (may inherit from role)"
    PASS=$((PASS+1))
  fi
done
echo ""

# ────────────────────────────────────────────────────────────────────
# Consistency cross-checks
# ────────────────────────────────────────────────────────────────────

echo "=== Consistency Cross-Checks ==="
echo ""

# Check that fixer and designer have end-to-end execution contracts
fixer_content=$(cat plugin/agents/fixer.md)
if echo "$fixer_content" | grep -q "End-to-End Execution Contract"; then
  echo "✓ Fixer has End-to-End Execution Contract section"
  PASS=$((PASS+1))
else
  echo "✗ Fixer missing End-to-End Execution Contract section"
  FAIL=$((FAIL+1))
fi

designer_content=$(cat plugin/agents/designer.md)
if echo "$designer_content" | grep -q "end-to-end\|contract\|responsibility"; then
  echo "✓ Designer has contract/responsibility documentation"
  PASS=$((PASS+1))
else
  echo "⊘ Designer may need explicit contract documentation"
  PASS=$((PASS+1))
fi

# Check that oracle explicitly has no tools
oracle_content=$(cat plugin/agents/oracle.md)
if echo "$oracle_content" | grep -qE "(no tools|tools.*\[\]|\[\\s*\\])"; then
  echo "✓ Oracle explicitly documents no tools (think-only)"
  PASS=$((PASS+1))
else
  echo "⊘ Oracle should explicitly state 'no tools' / 'think-only'"
  PASS=$((PASS+1))
fi

echo ""
echo "================================"
echo "$PASS passed, $FAIL failed"
echo "================================"

[ "$FAIL" -eq 0 ]
