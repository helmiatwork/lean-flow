# plugin/hooks/

## Responsibility
Defines lifecycle hooks that intercept and execute scripts at key plugin events: session initialization, pre/post tool execution, plan mode transitions, and agent completion. Centralizes hook orchestration through `hooks.json` configuration.

## Design
Event-driven hook system using JSON configuration with matchers (tool types: Bash, Write/Edit, Read, Task, EnterPlanMode, ExitPlanMode) and conditional execution via `if` patterns. Supports timeout enforcement, async flags, and sequential command chaining per lifecycle stage.

## Flow
**SessionStart** → runs 11 setup/validation scripts (MCPs, plugins, permissions, dependencies). **PreToolUse** → gates operations by tool type (Bash git safeguards, file access controls, branch/PR validation). **PostToolUse** → triggers workflow hooks, plan restructuring, test tracking, codemap auto-updates on commit. **SubagentStop/Stop** → runs post-execution reviews and cleanup.

## Integration
Hooks configuration consumed by plugin runtime to intercept Claude tool execution. Scripts in `${CLAUDE_PLUGIN_ROOT}/scripts/` directory handle enforcement (git safety checks, secret blocking, PR templates), MCP setup (knowledge, playwright, RTK, omni), and state management (plan updates, test tracking, codemap generation). Integrates with git, GitHub CLI, and Python/Bash script ecosystem.
