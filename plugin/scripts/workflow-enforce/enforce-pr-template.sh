#!/usr/bin/env bash
# PreToolUse Bash hook: force PR template usage when one exists in the repo.
# Blocks `gh pr create --body ...` (inline body) when a template file exists
# and --body-file is NOT used.
set -euo pipefail

input="$(cat)"
cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // ""')"

if [[ -z "$cmd" ]]; then
  exit 0
fi

# Only act on `gh pr create`
if ! printf '%s' "$cmd" | grep -qE 'gh[[:space:]]+pr[[:space:]]+create'; then
  exit 0
fi

# Find repo root
repo_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$repo_root" ]]; then
  exit 0
fi

template=""
for candidate in \
  ".github/PULL_REQUEST_TEMPLATE.md" \
  ".github/pull_request_template.md" \
  "PULL_REQUEST_TEMPLATE.md" \
  "pull_request_template.md" \
  "docs/PULL_REQUEST_TEMPLATE.md" \
  "docs/pull_request_template.md"; do
  if [[ -f "$repo_root/$candidate" ]]; then
    template="$repo_root/$candidate"
    break
  fi
done

if [[ -z "$template" ]]; then
  exit 0
fi

# Has --body but NOT --body-file?
if printf '%s' "$cmd" | grep -qE -- '--body([^[:alnum:]_-]|$)' && \
   ! printf '%s' "$cmd" | grep -qE -- '--body-file'; then
  echo "Workflow rule: this repo has a PR template at $template" >&2
  echo "Read it, fill it in, and pass --body-file <file> (or omit --body so gh auto-loads it)." >&2
  echo "Never use ad-hoc --body for repos with a template." >&2
  exit 2
fi

exit 0
