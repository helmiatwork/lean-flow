# plugin/hooks/

## Responsibility
Defines lifecycle hooks that trigger automated scripts and validation checks at key plugin events (SessionStart, PreToolUse, PostToolUse, SubagentStop, Stop). Enforces security guardrails, dependency initialization, and workflow automation across the Claude plugin ecosystem.

## Design
Hook system organized by event type with conditional matchers (Bash, Write/Edit, Read, Task, EnterPlanMode, ExitPlanMode). Each hook specifies command path, timeout, and optional conditional `if` expressions. Uses environment variable `${CLAUDE_PLUGIN_ROOT}` for script resolution. Supports async/sync execution modes and chaining multiple hooks per event.

## Flow
**SessionStart** → executes 11 initialization scripts (MCP servers, permissions, dependencies). **PreToolUse** → conditional validation blocks unsafe git/gh operations before execution. **PostToolUse** → event-specific handlers trigger plan restructuring, test tracking, codemap updates. **SubagentStop/Stop** → cleanup and workflow callbacks. Timeouts prevent hangs; `if` conditions gate execution to specific tool patterns.

## Integration
Connects to `/scripts/` directory (ensure-*.sh, block-*.sh, workflow-hook.sh, restructure-plan.py). Integrates with git/gh workflows, plan mode toggling, and subagent task delegation. Hooks into tool execution pipeline to enforce security (block-protected-push.sh, block-secret-commits.sh) and maintain state (auto-update-codemaps.sh, track-test-failures.sh).
