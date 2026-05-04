#!/usr/bin/env bash
# PreToolUse Bash hook: enforce branch naming convention on `git checkout -b` / `git switch -c`.
set -euo pipefail

input="$(cat)"
cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // ""')"

if [[ -z "$cmd" ]]; then
  exit 0
fi

# Match `git checkout -b NAME` or `git switch -c NAME`
name=""
if [[ "$cmd" =~ ^[[:space:]]*git[[:space:]]+checkout[[:space:]]+-b[[:space:]]+([A-Za-z0-9._/-]+) ]]; then
  name="${BASH_REMATCH[1]}"
elif [[ "$cmd" =~ ^[[:space:]]*git[[:space:]]+switch[[:space:]]+-c[[:space:]]+([A-Za-z0-9._/-]+) ]]; then
  name="${BASH_REMATCH[1]}"
else
  exit 0
fi

allowed='^(feature|fix|improvement|security|chore|docs|test|hotfix|release|experiment|revert)\/[A-Za-z0-9._/-]+$'

if [[ "$name" =~ $allowed ]]; then
  exit 0
fi

echo "Workflow rule: branch must start with feature/|fix/|improvement/|security/|chore/|docs/|test/|hotfix/|release/|experiment/|revert/" >&2
echo "Got: $name" >&2
exit 2
