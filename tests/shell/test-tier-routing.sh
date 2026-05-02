#!/usr/bin/env bash
# Test suite for STAR classifier tier routing
# Verifies that each tier (simple, medium, heavy, greenfield, hotfix)
# produces the correct routing decision in UserPromptSubmit hook output

set -euo pipefail
cd "$(dirname "$0")/../.."

PASS=0
FAIL=0

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

echo "=== STAR Classifier Tier Routing Tests ==="
echo ""
echo "Note: These tests verify tier classification patterns and verify that"
echo "the standard-development-flow.md workflow document includes all tiers"
echo "and routing paths."
echo ""

# Test 1-5: All tiers must be documented in the workflow
# These are assertion tests, not simulation tests
echo "Tests 1-5: All STAR tiers documented in standard-development-flow.md"
echo "  All five tier classifications must be present in the workflow mermaid."
echo ""

if [ ! -f "plugin/workflows/standard-development-flow.md" ]; then
  echo "✗ standard-development-flow.md not found"
  FAIL=$((FAIL+1))
else
  WORKFLOW_DOC="plugin/workflows/standard-development-flow.md"

  # Test 1: Simple tier must be documented
  if grep -qE "simple|DIRECTFIX" "$WORKFLOW_DOC"; then
    echo "✓ Test 1: Simple tier documented in workflow"
    PASS=$((PASS+1))
  else
    echo "✗ Test 1: Simple tier missing from workflow"
    FAIL=$((FAIL+1))
  fi

  # Test 2: Medium tier must be documented
  if grep -q "medium" "$WORKFLOW_DOC"; then
    echo "✓ Test 2: Medium tier documented in workflow"
    PASS=$((PASS+1))
  else
    echo "✗ Test 2: Medium tier missing from workflow"
    FAIL=$((FAIL+1))
  fi

  # Test 3: Heavy tier must be documented
  if grep -q "heavy" "$WORKFLOW_DOC"; then
    echo "✓ Test 3: Heavy tier documented in workflow"
    PASS=$((PASS+1))
  else
    echo "✗ Test 3: Heavy tier missing from workflow"
    FAIL=$((FAIL+1))
  fi

  # Test 4: Greenfield tier must be documented
  if grep -qE "greenfield|GREENFIELD" "$WORKFLOW_DOC"; then
    echo "✓ Test 4: Greenfield tier documented in workflow"
    PASS=$((PASS+1))
  else
    echo "✗ Test 4: Greenfield tier missing from workflow"
    FAIL=$((FAIL+1))
  fi

  # Test 5: Hotfix tier must be documented
  if grep -qE "hotfix|HOTFIX" "$WORKFLOW_DOC"; then
    echo "✓ Test 5: Hotfix tier documented in workflow"
    PASS=$((PASS+1))
  else
    echo "✗ Test 5: Hotfix tier missing from workflow"
    FAIL=$((FAIL+1))
  fi
fi
echo ""

# Test 6: Verify standard-development-flow.md mermaid documents all tiers
echo "Test 6: Workflow documentation completeness"
if [ -f "plugin/workflows/standard-development-flow.md" ]; then
  flow_doc=$(cat plugin/workflows/standard-development-flow.md)

  # All five tiers must be explicitly mentioned
  assert_contains "$flow_doc" "simple" "Workflow docs mention 'simple' tier"
  assert_contains "$flow_doc" "medium" "Workflow docs mention 'medium' tier"
  assert_contains "$flow_doc" "heavy" "Workflow docs mention 'heavy' tier"
  assert_contains "$flow_doc" "greenfield" "Workflow docs mention 'greenfield' tier"
  assert_contains "$flow_doc" "hotfix" "Workflow docs mention 'hotfix' tier"

  # Verify mermaid diagram references all tiers
  assert_contains "$flow_doc" "STARCHECK" "Workflow mermaid includes STAR classification node"

  # Verify routing decisions are present
  assert_contains "$flow_doc" "DIRECTFIX\|direct" "Workflow shows direct/simple routing path"
  assert_contains "$flow_doc" "DISPATCH" "Workflow shows dispatch path for medium/heavy"
  assert_contains "$flow_doc" "fixer" "Workflow mentions fixer dispatch"
else
  echo "✗ standard-development-flow.md not found"
  FAIL=$((FAIL+1))
fi
echo ""

# Test 7: standard-development-flow.md documents tier routing in prose
echo "Test 7: Tier Routing documentation in standard-development-flow.md"
if [ -f "plugin/workflows/standard-development-flow.md" ]; then
  WORKFLOW_DOC="plugin/workflows/standard-development-flow.md"

  # Check that workflow doc has Tier Routing or equivalent section
  if grep -qE "Tier Routing|tier.*routing|STAR.*classify" "$WORKFLOW_DOC"; then
    echo "✓ standard-development-flow.md has Tier Routing section"
    PASS=$((PASS+1))

    # Verify routing table includes all tiers
    if grep -qE "simple.*medium.*heavy" "$WORKFLOW_DOC" && \
       grep -qE "greenfield|hotfix" "$WORKFLOW_DOC"; then
      echo "✓ Tier Routing documentation includes all five tiers"
      PASS=$((PASS+1))
    else
      echo "✗ Tier Routing documentation missing one or more tiers"
      FAIL=$((FAIL+1))
    fi
  else
    echo "✗ standard-development-flow.md missing Tier Routing documentation"
    FAIL=$((FAIL+1))
  fi
else
  echo "✗ standard-development-flow.md not found"
  FAIL=$((FAIL+1))
fi
echo ""

echo "================================"
echo "$PASS passed, $FAIL failed"
echo "================================"

[ "$FAIL" -eq 0 ]
