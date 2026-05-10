#!/usr/bin/env bash
# Master test runner for lean-flow test suite
# Runs all tests and summarizes results
# Usage: bash tests/run-all.sh

set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

PASS=0
FAIL=0
TOTAL=0

# Color codes
GREEN='\033[32m'
RED='\033[31m'
RESET='\033[0m'

echo "================================"
echo "Running lean-flow test suite"
echo "================================"
echo ""

# Check dependencies
echo "Checking dependencies..."
missing_deps=()

if ! command -v jq &> /dev/null; then
  echo "⚠ jq not found (some shell tests may be skipped)"
fi

if ! command -v python3 &> /dev/null; then
  echo "⚠ python3 not found (Python tests will be skipped)"
  missing_deps+=("python3")
fi

echo ""

# Test: test-load-config.sh
echo -n "Running tests/shell/test-load-config.sh... "
TOTAL=$((TOTAL+1))
start_time=$(date +%s)
if bash "tests/shell/test-load-config.sh" > /tmp/test-load-config.log 2>&1; then
  end_time=$(date +%s)
  elapsed=$((end_time - start_time))
  printf "${GREEN}✓${RESET} test-load-config.sh (${elapsed}s)\n"
  PASS=$((PASS+1))
else
  end_time=$(date +%s)
  elapsed=$((end_time - start_time))
  printf "${RED}✗${RESET} test-load-config.sh (${elapsed}s)\n"
  FAIL=$((FAIL+1))
  cat /tmp/test-load-config.log
fi

# Test: test-claude-monitor.sh
echo -n "Running tests/shell/test-claude-monitor.sh... "
TOTAL=$((TOTAL+1))
start_time=$(date +%s)
if bash "tests/shell/test-claude-monitor.sh" > /tmp/test-claude-monitor.log 2>&1; then
  end_time=$(date +%s)
  elapsed=$((end_time - start_time))
  printf "${GREEN}✓${RESET} test-claude-monitor.sh (${elapsed}s)\n"
  PASS=$((PASS+1))
else
  end_time=$(date +%s)
  elapsed=$((end_time - start_time))
  printf "${RED}✗${RESET} test-claude-monitor.sh (${elapsed}s)\n"
  FAIL=$((FAIL+1))
  cat /tmp/test-claude-monitor.log
fi

# Test: test-hooks-pretooluse.sh
echo -n "Running tests/shell/test-hooks-pretooluse.sh... "
TOTAL=$((TOTAL+1))
start_time=$(date +%s)
if bash "tests/shell/test-hooks-pretooluse.sh" > /tmp/test-hooks-pretooluse.log 2>&1; then
  end_time=$(date +%s)
  elapsed=$((end_time - start_time))
  printf "${GREEN}✓${RESET} test-hooks-pretooluse.sh (${elapsed}s)\n"
  PASS=$((PASS+1))
else
  end_time=$(date +%s)
  elapsed=$((end_time - start_time))
  printf "${RED}✗${RESET} test-hooks-pretooluse.sh (${elapsed}s)\n"
  FAIL=$((FAIL+1))
  cat /tmp/test-hooks-pretooluse.log
fi

# Test: test-workflow-hooks.sh
echo -n "Running tests/shell/test-workflow-hooks.sh... "
TOTAL=$((TOTAL+1))
start_time=$(date +%s)
if bash "tests/shell/test-workflow-hooks.sh" > /tmp/test-workflow-hooks.log 2>&1; then
  end_time=$(date +%s)
  elapsed=$((end_time - start_time))
  printf "${GREEN}✓${RESET} test-workflow-hooks.sh (${elapsed}s)\n"
  PASS=$((PASS+1))
else
  end_time=$(date +%s)
  elapsed=$((end_time - start_time))
  printf "${RED}✗${RESET} test-workflow-hooks.sh (${elapsed}s)\n"
  FAIL=$((FAIL+1))
  cat /tmp/test-workflow-hooks.log
fi

# Test: test-ensure-scripts.sh
echo -n "Running tests/shell/test-ensure-scripts.sh... "
TOTAL=$((TOTAL+1))
start_time=$(date +%s)
if bash "tests/shell/test-ensure-scripts.sh" > /tmp/test-ensure-scripts.log 2>&1; then
  end_time=$(date +%s)
  elapsed=$((end_time - start_time))
  printf "${GREEN}✓${RESET} test-ensure-scripts.sh (${elapsed}s)\n"
  PASS=$((PASS+1))
else
  end_time=$(date +%s)
  elapsed=$((end_time - start_time))
  printf "${RED}✗${RESET} test-ensure-scripts.sh (${elapsed}s)\n"
  FAIL=$((FAIL+1))
  cat /tmp/test-ensure-scripts.log
fi

# Test: test-project-doctor.sh
echo -n "Running tests/shell/test-project-doctor.sh... "
TOTAL=$((TOTAL+1))
start_time=$(date +%s)
if bash "tests/shell/test-project-doctor.sh" > /tmp/test-project-doctor.log 2>&1; then
  end_time=$(date +%s)
  elapsed=$((end_time - start_time))
  printf "${GREEN}✓${RESET} test-project-doctor.sh (${elapsed}s)\n"
  PASS=$((PASS+1))
else
  end_time=$(date +%s)
  elapsed=$((end_time - start_time))
  printf "${RED}✗${RESET} test-project-doctor.sh (${elapsed}s)\n"
  FAIL=$((FAIL+1))
  cat /tmp/test-project-doctor.log
fi

# Test: test_cartographer.py
if [[ " ${missing_deps[@]} " =~ " python3 " ]]; then
  echo "⊘ tests/python/test_cartographer.py (skipped: python3 not found)"
else
  echo -n "Running tests/python/test_cartographer.py... "
  TOTAL=$((TOTAL+1))
  start_time=$(date +%s)
  if python3 "tests/python/test_cartographer.py" > /tmp/test_cartographer.log 2>&1; then
    end_time=$(date +%s)
    elapsed=$((end_time - start_time))
    printf "${GREEN}✓${RESET} test_cartographer.py (${elapsed}s)\n"
    PASS=$((PASS+1))
  else
    end_time=$(date +%s)
    elapsed=$((end_time - start_time))
    printf "${RED}✗${RESET} test_cartographer.py (${elapsed}s)\n"
    FAIL=$((FAIL+1))
    cat /tmp/test_cartographer.log
  fi
fi

# Test: test_scan_codebase.py
if [[ " ${missing_deps[@]} " =~ " python3 " ]]; then
  echo "⊘ tests/python/test_scan_codebase.py (skipped: python3 not found)"
else
  echo -n "Running tests/python/test_scan_codebase.py... "
  TOTAL=$((TOTAL+1))
  start_time=$(date +%s)
  if python3 "tests/python/test_scan_codebase.py" > /tmp/test_scan_codebase.log 2>&1; then
    end_time=$(date +%s)
    elapsed=$((end_time - start_time))
    printf "${GREEN}✓${RESET} test_scan_codebase.py (${elapsed}s)\n"
    PASS=$((PASS+1))
  else
    end_time=$(date +%s)
    elapsed=$((end_time - start_time))
    printf "${RED}✗${RESET} test_scan_codebase.py (${elapsed}s)\n"
    FAIL=$((FAIL+1))
    cat /tmp/test_scan_codebase.log
  fi
fi

# ── Suites added in test/comprehensive-suite ──────────────────────────
run_shell_suite() {
  local rel="$1"
  local name
  name=$(basename "$rel")
  echo -n "Running $rel... "
  TOTAL=$((TOTAL+1))
  start_time=$(date +%s)
  if bash "$rel" > "/tmp/$name.log" 2>&1; then
    elapsed=$(( $(date +%s) - start_time ))
    printf "${GREEN}✓${RESET} $name (${elapsed}s)\n"
    PASS=$((PASS+1))
  else
    elapsed=$(( $(date +%s) - start_time ))
    printf "${RED}✗${RESET} $name (${elapsed}s)\n"
    FAIL=$((FAIL+1))
    cat "/tmp/$name.log"
  fi
}

run_shell_suite "tests/shell/test-load-workflow.sh"
run_shell_suite "tests/shell/test-skill-references.sh"
run_shell_suite "tests/shell/test-integration-lifecycle.sh"
run_shell_suite "tests/shell/test-omos-adoptions.sh"
run_shell_suite "tests/shell/test-ensure-companions.sh"
run_shell_suite "tests/shell/test-check-dependencies.sh"
run_shell_suite "tests/shell/test-tier-routing.sh"
run_shell_suite "tests/shell/test-agent-contracts.sh"
run_shell_suite "tests/shell/test-ensure-script-coverage.sh"

if command -v node &>/dev/null; then
  for nt in tests/node/*.mjs; do
    [ -f "$nt" ] || continue
    name=$(basename "$nt")
    echo -n "Running $nt... "
    TOTAL=$((TOTAL+1))
    start_time=$(date +%s)
    if node --test "$nt" > "/tmp/$name.log" 2>&1; then
      elapsed=$(( $(date +%s) - start_time ))
      printf "${GREEN}✓${RESET} $name (${elapsed}s)\n"
      PASS=$((PASS+1))
    else
      elapsed=$(( $(date +%s) - start_time ))
      printf "${RED}✗${RESET} $name (${elapsed}s)\n"
      FAIL=$((FAIL+1))
      cat "/tmp/$name.log"
    fi
  done
else
  echo "⊘ Node tests skipped (node not found)"
fi

echo ""
echo "=== shellcheck (P1 coverage gate) ==="
if command -v shellcheck >/dev/null 2>&1; then
  find plugin/scripts tests/shell .claude/hooks -name "*.sh" -type f 2>/dev/null \
    | xargs shellcheck --severity=warning 2>&1 || {
      echo "FAIL: shellcheck reported warnings"
      FAIL=$((FAIL+1))
    }
  if [ $? -eq 0 ]; then
    echo "  ok: shellcheck clean"
  fi
else
  echo "  skip: shellcheck not installed"
fi

echo ""
echo "================================"
if [ "$FAIL" -eq 0 ]; then
  printf "${GREEN}$PASS/$TOTAL suites passed${RESET}\n"
else
  printf "${RED}$PASS/$TOTAL suites passed (${FAIL} failed)${RESET}\n"
fi
echo "================================"

# Cleanup temp logs
rm -f /tmp/test-*.log /tmp/test_*.log

[ "$FAIL" -eq 0 ]
