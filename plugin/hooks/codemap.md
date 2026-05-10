# plugin/hooks/

## Responsibility
Defines lifecycle hooks that execute at key session and tool-use points. Orchestrates initialization, security gates, and post-action workflows through declarative command chains.

## Design
- **Hook registry pattern**: `hooks.json` maps event types (`SessionStart`, `PreToolUse`, `PostToolUse`, `SubagentStop`, `Stop`) to conditional command arrays
- **Matcher-based routing**: `PreToolUse` and `PostToolUse` conditionally trigger hooks based on tool type (`Bash`, `Write|Edit`, `Read`, `Task`, `EnterPlanMode`, `ExitPlanMode`)
- **Timeout & async control**: Each hook specifies execution timeout and optional async flag; conditional execution via `if` patterns (e.g., `Bash(git push *)`)

## Flow
1. **SessionStart**: Runs 11 sequential initialization scripts (MCP servers, plugins, permissions, dependencies)
2. **PreToolUse**: Gate checks execute before tool invocation—git security (block unsafe pushes, secrets, Claude identity), branch naming, linting
3. **PostToolUse**: Workflow tracking and state updates after tool execution—plan restructuring, test failure tracking, codemap auto-updates, PR workflows
4. **SubagentStop/Stop**: Cleanup and post-execution review hooks

## Integration
- Scripts reference `${CLAUDE_PLUGIN_ROOT}` for execution paths across `scripts/` directory
- Hooks integrate with plan mode system (`EnterPlanMode`, `ExitPlanMode`), git workflows, and codemap maintenance
- Feeds into subagent delegation (`delegate-task-retry.sh`) and session lifecycle management
- Enables security guardrails (prevent unsafe git ops, block secret commits) and documentation auto-sync
