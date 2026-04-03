#!/usr/bin/env bash
# Block direct pushes to main/master/staging
CMD=$(jq -r '.tool_input.command // ""')
if echo "$CMD" | grep -qE 'git\s+push\s+.*\b(master|main|staging)\b'; then
  echo '{"decision":"block","reason":"Blocked: never push directly to main/master/staging. Create a feature branch and open a PR instead."}'
fi
