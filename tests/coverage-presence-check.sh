#!/usr/bin/env bash
# Shell script presence check for plugin/hooks and plugin/scripts
# Verifies that every hook and script is referenced by at least one test
#
# Usage: bash tests/coverage-presence-check.sh [--report]
# Exit code: 0 if all files are referenced, non-zero if any file is not referenced

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
COVERAGE_DIR="${COVERAGE_DIR:-.coverage}"

mkdir -p "$COVERAGE_DIR"

# Check if a script is tested by examining test references
# Returns true (0) if found in test files, false (1) otherwise
is_referenced() {
  local script="$1"
  local scriptname=$(basename "$script")
  local scriptbase="${scriptname%.*}"

  # Check if this script is referenced in any test file
  # Test references typically look like: source/invoke the script, or reference by name
  if grep -r "$scriptbase\|$scriptname" "$REPO_ROOT/tests/shell/" 2>/dev/null | grep -q .; then
    return 0
  fi
  return 1
}

# Main check run
main() {
  echo "================================"
  echo "Shell Script Presence Check"
  echo "================================"
  echo "Verifies every hook/script is referenced by at least one test"
  echo ""

  local all_files_str
  all_files_str=$(
    { find "$REPO_ROOT/plugin/hooks" -type f -name "*.sh" 2>/dev/null; \
      find "$REPO_ROOT/plugin/scripts" -type f -name "*.sh" 2>/dev/null; } | sort
  )

  if [ -z "$all_files_str" ]; then
    echo "✗ No shell scripts found in plugin/hooks or plugin/scripts"
    return 1
  fi

  local total_pass=0
  local total_fail=0

  echo "Analyzing test references for hook and script files..."
  echo ""
  echo "Script References:"

  while IFS= read -r script; do
    if [ -z "$script" ] || [ ! -f "$script" ]; then
      continue
    fi

    local filename=$(basename "$script")

    # Check if referenced
    if is_referenced "$script"; then
      printf "  ✓ %-50s referenced\n" "$filename"
      total_pass=$((total_pass + 1))
    else
      printf "  ✗ %-50s not-referenced\n" "$filename"
      total_fail=$((total_fail + 1))
    fi
  done <<EOF
$all_files_str
EOF

  echo ""
  echo "================================"
  echo "Presence Check Summary"
  echo "================================"
  echo ""
  echo "Scripts referenced: $total_pass"
  echo "Scripts not-referenced: $total_fail"
  echo ""

  if [ "$total_fail" -gt 0 ]; then
    echo "⚠️  PRESENCE GATE FAILED: $total_fail script(s) not referenced in tests"
    echo ""
    echo "To fix:"
    echo "  1. Add test cases in tests/shell/ that reference uncovered scripts"
    echo "  2. Ensure test files reference the script name or basename"
    echo "  3. Run: bash tests/run-all.sh to verify all tests pass"
    echo "  4. Re-run: bash tests/coverage-presence-check.sh"
    echo ""
    return 1
  else
    echo "✓ PRESENCE GATE PASSED: all scripts referenced in tests"
    return 0
  fi
}

main "$@"
