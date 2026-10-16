#!/usr/bin/env bash
# Block saving plans to docs/superpowers/plans/ — must use ~/.claude/plans/

FILE_PATH=$(jq -r '.tool_input.file_path // ""')

if echo "$FILE_PATH" | grep -qE 'docs/superpowers/plans/'; then
  echo "Blocked: Plans must be saved to ~/.claude/plans/, not docs/superpowers/plans/." >&2
  exit 2
fi
