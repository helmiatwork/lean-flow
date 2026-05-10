#!/bin/bash
# Block PR comments, reviews, and API comment calls
# User owns these repos — comments from their own account look like self-talk
# Opt-out: LEAN_FLOW_BLOCK_PR_COMMENTS_DISABLED=true

[[ "${LEAN_FLOW_BLOCK_PR_COMMENTS_DISABLED:-}" == "true" ]] && exit 0

CMD=$(jq -r '.tool_input.command // ""' 2>/dev/null)
[[ -z "$CMD" ]] && exit 0

if echo "$CMD" | grep -qE 'gh (pr review|pr comment|api .*/comments|api .*/reviews)'; then
  echo '{"decision":"block","reason":"BLOCKED: Never create PR comments or reviews. Push code changes directly to the branch instead."}'
  exit 0
fi

exit 0
