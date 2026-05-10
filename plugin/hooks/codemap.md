# plugin/hooks/

## Responsibility
Defines lifecycle hooks that execute during Claude plugin sessions. `hooks.json` specifies automated validation, security checks, and monitoring scripts that run at key workflow moments (SessionStart, PreToolUse, PostToolUse, SubagentStop).

## Design
Hook configuration uses a declarative JSON structure with three main trigger points: SessionStart (unconditional initialization), PreToolUse (conditional on tool type via `matcher` field and optional `if` patterns), and PostToolUse (conditional on tool completion). Each hook entry contains a `command` (bash/python script), optional `timeout`, `if` condition for pattern matching, and `async` flag. Default execution is synchronous unless marked `async: false`.

## Flow
1. **SessionStart** executes sequentially on session init: MCP setup (knowledge, playwright), plugin verification, permission checks, dependency validation
2. **PreToolUse** conditionally triggers before tool execution—Bash hooks enforce git safety (block protected push, no-verify, secrets), enforce naming/templates; Write/Edit/Read hooks validate file access; monitoring hook logs session activity
3. **PostToolUse** triggers after tool completion—tracks writes, plan mode transitions, git commits (with auto-codemap update), test failures, and task retries; session tracking logs session events
4. All scripts resolve `${CLAUDE_PLUGIN_ROOT}` at runtime

## Integration
Hooks bridge the plugin execution engine and `scripts/` directory utilities. SessionStart ensures downstream tools (RTK, Omni, GitNexus) are initialized. PreToolUse guards call protection, secrets, and file access. PostToolUse drives automation (codemap regeneration, plan restructuring, monitoring). SessionStart and PreToolUse/PostToolUse hooks feed into claude-monitor tracking via `claude-session-track.sh` for observability.
