#!/usr/bin/env bash
# Block deletion of remote branches — prevents accidentally closing PRs
# Opt-out: LEAN_FLOW_BLOCK_BRANCH_DELETE_DISABLED=true

[[ "${LEAN_FLOW_BLOCK_BRANCH_DELETE_DISABLED:-}" == "true" ]] && exit 0

CMD=$(jq -r '.tool_input.command // ""' 2>/dev/null)
[[ -z "$CMD" ]] && exit 0

if echo "$CMD" | grep -qE "git\s+push\s+\S+\s+--delete"; then
  echo "{\"decision\":\"block\",\"reason\":\"Blocked: never delete remote branches. This closes any associated PRs. Use --force-with-lease to update branch history instead.\"}"
  exit 0
fi

exit 0
