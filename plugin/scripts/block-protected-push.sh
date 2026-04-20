#!/usr/bin/env bash
# Block direct pushes to protected branches (but allow branches containing those words)

# Load config (sets LEAN_FLOW_PROTECTED_BRANCHES)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=load-config.sh
source "${SCRIPT_DIR}/load-config.sh" 2>/dev/null || true

CMD=$(jq -r '.tool_input.command // ""')

# Build a regex alternation from the configured protected branch list
_branches_pattern=$(echo "$LEAN_FLOW_PROTECTED_BRANCHES" | tr ' ' '|')

# Match only when a protected name is the final ref argument (not part of a path)
if echo "$CMD" | grep -qE "git\s+push\s+\S+\s+(${_branches_pattern})\s*\$"; then
  echo "{\"decision\":\"block\",\"reason\":\"Blocked: never push directly to ${LEAN_FLOW_PROTECTED_BRANCHES}. Create a feature branch and open a PR instead.\"}"
fi
