#!/usr/bin/env bash
# Block --no-verify and --no-gpg-sign flags on git commands

CMD=$(jq -r '.tool_input.command // ""')

if echo "$CMD" | grep -qE 'git\s+(commit|push|merge|rebase).*--no-verify'; then
  echo "Blocked: --no-verify is not allowed. Fix the underlying hook issue instead." >&2
  exit 2
fi

if echo "$CMD" | grep -qE 'git\s+commit.*--no-gpg-sign'; then
  echo "Blocked: --no-gpg-sign is not allowed." >&2
  exit 2
fi
