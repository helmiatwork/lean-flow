#!/bin/bash
# File Read Gate: inject recent git activity before reading a file
# Input: TOOL_INPUT env var contains JSON with "file_path" key

file_path=$(echo "${TOOL_INPUT:-{}}" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('file_path',''))" 2>/dev/null)

[ -z "$file_path" ] && exit 0

# Only act on files inside a git repo
git_root=$(git -C "$(dirname "$file_path")" rev-parse --show-toplevel 2>/dev/null)
[ -z "$git_root" ] && exit 0

# Get last 3 commits touching this file
recent=$(git -C "$git_root" log --oneline -3 -- "$file_path" 2>/dev/null)
[ -z "$recent" ] && exit 0

rel_path="${file_path#$git_root/}"

printf '{"additionalContext": "Recent git activity on %s:\n%s"}' "$rel_path" "$recent"
