#!/bin/bash
# Hook: PreToolUse — warn when browser_snapshot is called
# Heavy pages (dashboards, tables, GRIN) exceed Claude's 20MB limit.
# Prefer browser_evaluate or browser_run_code for data extraction.
# Opt-out: LEAN_FLOW_WARN_BROWSER_SNAPSHOT_DISABLED=true

[[ "${LEAN_FLOW_WARN_BROWSER_SNAPSHOT_DISABLED:-}" == "true" ]] && exit 0

TOOL_NAME="${CLAUDE_TOOL_NAME:-}"

if [[ "$TOOL_NAME" == "mcp__playwright__browser_snapshot" ]]; then
  cat >&2 <<'MSG'
Warning: browser_snapshot can exceed 20MB on heavy pages.
Consider using browser_evaluate to extract only the data you need,
or browser_take_screenshot with an element selector for visual checks.
MSG
fi

exit 0
