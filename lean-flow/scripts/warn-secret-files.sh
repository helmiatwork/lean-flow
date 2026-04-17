#!/usr/bin/env bash
# Warn when editing files that might contain secrets
FILE=$(jq -r '.tool_input.file_path // .tool_input.filePath // ""')
if echo "$FILE" | grep -qiE '\.(env|pem|key|p12|pfx|jks)$|credentials|secrets|\.secret'; then
  echo "{\"decision\":\"block\",\"reason\":\"⚠️ This file may contain secrets: $FILE. If intentional, use Bash to edit it directly.\"}"
fi
