# plugin/hooks/

## Responsibility

`plugin/hooks/` defines the lifecycle event handlers that intercept and validate Claude's actions throughout a session. `hooks.json` centralizes all hook configurations for four major event types: SessionStart (initialization), PreToolUse (validation before execution), PostToolUse (side effects after execution), SubagentStop, and Stop. This enables guardrails, workflows, and auto-maintenance without modifying core tool logic.

## Design

Hook system uses a declarative JSON structure with conditional matching on tool types (Bash, Read, Write/Edit, Task, EnterPlanMode, ExitPlanMode). Each hook entry specifies a command script, optional timeout, conditional `if` matcher pattern, and execution mode (sync/async). Matchers enable selective hook triggering—e.g., `Bash(git push *)` only fires pre-push guards, while broader `Write|Edit` hooks apply to file operations universally.

## Flow

1. **SessionStart**: Sequential initialization scripts validate MCP servers, plugins, permissions, and check dependencies before session begins
2. **PreToolUse**: Conditional guards execute before tool invocation—git security checks (no-verify, protected branches, secrets), linting, branch naming enforcement
3. **PostToolUse**: Post-execution workflows update plan checklists, track test failures, regenerate codemaps, delegate task retries, and manage plan mode transitions
4. **SubagentStop/Stop**: Cleanup and final review hooks when agents or sessions terminate

## Integration

Hooks invoke scripts in `${CLAUDE_PLUGIN_ROOT}/scripts/` (bash and Python executables) that implement specific safety checks and maintenance tasks. Matchers correlate to tool names exposed by Claude's runtime; hook execution is driven by the plugin host's event dispatcher when tools are called. Results feed back into context (warnings, blocks, updates) to influence downstream behavior.
