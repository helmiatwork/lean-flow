#!/usr/bin/env bash
# Block saving plans to docs/superpowers/plans/ — must use ~/.gemini/plans/

FILE_PATH=$(jq -r '.tool_input.file_path // ""')

if echo "$FILE_PATH" | grep -qE 'docs/superpowers/plans/'; then
  echo "Blocked: Plans must be saved to ~/.gemini/plans/, not docs/superpowers/plans/." >&2
  exit 2
fi
