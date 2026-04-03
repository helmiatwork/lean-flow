#!/usr/bin/env bash
# Block --no-verify flag on git commands
CMD=$(jq -r '.tool_input.command // ""')
if echo "$CMD" | grep -qE 'git\s+.*--no-verify'; then
  echo '{"decision":"block","reason":"Blocked: --no-verify is not allowed. Fix the hook issue instead of bypassing it."}'
fi
