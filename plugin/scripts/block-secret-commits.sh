#!/usr/bin/env bash
# Block staging secret/credential files via git add

CMD=$(jq -r '.tool_input.command // ""')

# Block explicit git add of secret files
if echo "$CMD" | grep -qE 'git\s+add.*(\s|/)\.env(\s|$|\.)|git\s+add.*credentials|git\s+add.*\.secret'; then
  echo "Blocked: Cannot stage secret/credential files (.env, credentials, .secret). Use .env.example instead." >&2
  exit 2
fi

# Warn on git add . or git add -A (may accidentally stage secrets)
if echo "$CMD" | grep -qE 'git\s+add\s+(-A|\.\s*$)'; then
  echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"git add -A/. may stage .env or credential files. Stage specific files by name instead."}}'
  exit 0
fi
