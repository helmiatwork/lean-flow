# plugin/hooks/

## Responsibility
Centralized lifecycle and event hook configuration for the Claude plugin system. Defines automated scripts and validations triggered at key session and tool execution boundaries (SessionStart, PreToolUse, PostToolUse, SubagentStop).

## Design
Event-driven hook registry using JSON with three core abstractions:
- **Event types**: SessionStart (initialization), PreToolUse (guard checks), PostToolUse (cleanup/tracking), SubagentStop (delegation cleanup)
- **Matchers**: Filter hooks by tool type (Bash, Write/Edit, Read, Task, EnterPlanMode, ExitPlanMode) or run unconditionally
- **Hook specs**: Command execution with optional timeout, conditional logic (`if` field), and async flags

## Flow
1. **SessionStart**: Chains 12 setup commands (knowledge-mcp, plugins, permissions, MCPs, monitoring tools, dependency checks)
2. **PreToolUse**: Branches by tool matcher—Bash hooks enforce git safety (block pushes, --no-verify, secrets); Write/Edit/Read hooks validate file access; all paths converge on monitoring/compression
3. **PostToolUse**: Triggers based on action (plan restructuring on ExitPlanMode, codemap updates on git commits, test failure tracking on Bash)
4. **SubagentStop**: Cleanup workflow hook invocation

## Integration
- **Scripts directory** (`${CLAUDE_PLUGIN_ROOT}/scripts/`): All hooks execute bash/python scripts for safety checks, MCP initialization, workflow management, and session tracking
- **Plan/monitoring systems**: EnterPlanMode, ExitPlanMode, and claude-session-track hooks coordinate with planning and observability infrastructure
- **Git/PR workflow**: PreToolUse and PostToolUse gates integrate with git and GitHub CLI to enforce commit identity and track PR creation
- **Task delegation**: SubagentStop and delegate-task-retry.sh handle async task lifecycle
