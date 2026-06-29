#!/usr/bin/env bash
# PreToolUse Bash hook: run rubocop on changed Ruby files before `git push`.
# Scoped to diff vs upstream so it runs in seconds. RSpec is intentionally
# left to CI (full suite is too slow for a pre-push hook).
set -euo pipefail

input="$(cat)"
cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // ""')"

if [[ -z "$cmd" ]]; then
  exit 0
fi

# Only act on `git push`
if ! printf '%s' "$cmd" | grep -qE '^[[:space:]]*git[[:space:]]+push'; then
  exit 0
fi

# Skip branch/tag deletes
if printf '%s' "$cmd" | grep -qE '(:[[:space:]]*[A-Za-z0-9._/-]+|--delete)'; then
  exit 0
fi

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
[[ -z "$repo_root" ]] && exit 0
[[ ! -f "$repo_root/Gemfile" ]] && exit 0

cd "$repo_root"

# Determine the set of Ruby files that will be pushed.
files=""
if git rev-parse '@{upstream}' >/dev/null 2>&1; then
  files="$(git diff '@{upstream}'..HEAD --name-only --diff-filter=ACMR 2>/dev/null | grep -E '\.(rb|rake|gemspec)$|^Gemfile$' || true)"
else
  files="$(git diff origin/HEAD..HEAD --name-only --diff-filter=ACMR 2>/dev/null | grep -E '\.(rb|rake|gemspec)$|^Gemfile$' || true)"
fi

# Filter to files that still exist in the working tree
existing=""
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  [[ -f "$repo_root/$f" ]] && existing+="$f"$'\n'
done <<< "$files"

if [[ -z "${existing// /}" ]]; then
  exit 0
fi

# Run rubocop only if it's in the bundle
if [[ -f Gemfile.lock ]] && grep -q '^[[:space:]]*rubocop' Gemfile.lock; then
  # shellcheck disable=SC2086
  if ! printf '%s' "$existing" | xargs bundle exec rubocop --force-exclusion >&2; then
    echo "Workflow rule: rubocop failed on changed files. Fix offenses before pushing." >&2
    exit 2
  fi
fi

exit 0
