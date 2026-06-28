#!/usr/bin/env bash
# PreToolUse Bash hook: reject git commit / gh pr create|edit containing AI attribution
set -euo pipefail

input="$(cat)"
cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // ""')"

if [[ -z "$cmd" ]]; then
  exit 0
fi

# Only inspect commit / PR commands
if ! printf '%s' "$cmd" | grep -qE 'git[[:space:]]+commit|gh[[:space:]]+pr[[:space:]]+(create|edit)'; then
  exit 0
fi

# Patterns that indicate Claude/AI authorship
patterns=(
  'Co-Authored-By:[[:space:]]*Claude'
  'Co-authored-by:[[:space:]]*Claude'
  'Generated with Claude Code'
  'Generated with \[Claude Code\]'
  'noreply@anthropic\.com'
  '🤖'
)

for pat in "${patterns[@]}"; do
  if printf '%s' "$cmd" | grep -qE -- "$pat"; then
    echo "Workflow rule: no Claude/AI/Co-Authored-By attribution in commits or PRs." >&2
    echo "Matched pattern: $pat" >&2
    exit 2
  fi
done

exit 0
