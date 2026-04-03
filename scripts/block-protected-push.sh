#!/usr/bin/env bash
# Block direct pushes to main/master/staging (but allow branches containing those words)
CMD=$(jq -r '.tool_input.command // ""')
# Match only when the protected name is the final ref argument (not part of a path)
if echo "$CMD" | grep -qE 'git\s+push\s+\S+\s+(master|main|staging)\s*$'; then
  echo '{"decision":"block","reason":"Blocked: never push directly to main/master/staging. Create a feature branch and open a PR instead."}'
fi
