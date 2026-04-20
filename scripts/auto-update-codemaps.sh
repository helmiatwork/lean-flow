#!/usr/bin/env bash
# PostToolUse hook: auto-updates codemap.md files after git commit

git rev-parse --is-inside-work-tree &>/dev/null 2>&1 || exit 0
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
[ -z "$REPO_ROOT" ] && exit 0
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3 "$SCRIPT_DIR/auto-update-codemaps.py" "$REPO_ROOT"
