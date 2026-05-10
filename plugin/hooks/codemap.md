# plugin/hooks/

## Responsibility
Central lifecycle hook configuration for the Claude plugin system. Defines event-driven triggers (SessionStart, PreToolUse, PostToolUse, SubagentStop, Stop) that execute validation, enforcement, and automation scripts at key workflow moments.

## Design
- **Event-based architecture**: hooks.json organizes scripts by lifecycle phases (SessionStart, Pre/PostToolUse, SubagentStop, Stop)
- **Conditional execution**: PreToolUse hooks use matchers (Bash, Write|Edit, Read) and `if` patterns to target specific tool invocations
- **Timeout management**: Each hook specifies explicit timeouts (3s–60s) to prevent hangs during tool execution
- **Tool-specific gating**: Separate hook chains for Bash commands (git/gh operations), file operations (Write/Edit/Read), and plan mode transitions

## Flow
1. **SessionStart**: Initializes plugin infrastructure (MCP servers, dependencies, permissions) sequentially before user interaction
2. **PreToolUse**: Intercepts tool execution—validates git operations (no --no-verify, branch naming), warns on secret file access, gates file reads
3. **PostToolUse**: Post-execution actions (PR template enforcement, plan restructuring, test tracking, codemap updates) triggered by tool type and bash patterns
4. **SubagentStop/Stop**: Cleanup and review hooks when subagents or sessions terminate

## Integration
- Executes scripts from `${CLAUDE_PLUGIN_ROOT}/scripts/` (bash and Python runners)
- Hooks into Claude's tool execution pipeline via matcher conditions
- Enforces guardrails (block-protected-push.sh, warn-secret-files.sh) and automates workflows (auto-update-codemaps.sh, update-plan-checklist.sh)
- Async option available for non-blocking PR workflows; timeout values prevent system deadlock
