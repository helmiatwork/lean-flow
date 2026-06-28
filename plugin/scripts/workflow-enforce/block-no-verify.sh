#!/usr/bin/env bash
# PreToolUse Bash hook: block --no-verify / --no-gpg-sign / commit.gpgsign=false
set -euo pipefail

input="$(cat)"
cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // ""')"

if [[ -z "$cmd" ]]; then
  exit 0
fi

if printf '%s' "$cmd" | grep -qE -- '(--no-verify|--no-gpg-sign|-c[[:space:]]+commit\.gpgsign=false)'; then
  echo "Workflow rule: --no-verify / hook-skip is forbidden. Fix the underlying failure instead." >&2
  echo "Command: $cmd" >&2
  exit 2
fi

exit 0
