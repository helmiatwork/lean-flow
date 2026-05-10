# plugin/hooks/

## Responsibility
Defines lifecycle hooks that execute scripts at key plugin events (SessionStart, PreToolUse, PostToolUse, SubagentStop). Manages guard rails (git security, secret detection, branch naming), workflow tracking, and automated maintenance tasks triggered by user actions.

## Design
Event-driven architecture using matchers (`Bash`, `Write|Edit`, `Read`, `EnterPlanMode`, etc.) to conditionally execute bash/python scripts. Each hook specifies `type`, `command`, optional `timeout`, `if` condition, and `async` flag. Supports conditional execution via glob patterns (e.g., `Bash(git push *)`) and matcher-specific routing.

## Flow
Plugin lifecycle triggers hook events → matcher evaluates against tool/action type → matched conditionals execute scripts in sequence → scripts enforce policies (block unsafe git ops), track sessions (claude-monitor), update documentation (codemaps), and handle plan mode transitions. SessionStart runs initialization sequence; PreToolUse enforces constraints; PostToolUse performs cleanup/tracking; SubagentStop handles subagent teardown.

## Integration
Scripts live in `${CLAUDE_PLUGIN_ROOT}/scripts/` and invoke MCP servers (knowledge, playwright, claude-monitor, omni, gitnexus, cartography). Hooks coordinate with plan-viewer, RTK, and workflow-hook.sh for cross-cutting concerns. PostToolUse triggers codemap regeneration on git commits and tracks test failures, binding to version control and documentation systems.
