# plugin/hooks/

## Responsibility
Centralized hook lifecycle configuration that triggers validation, safety, and automation scripts at key Claude plugin execution points (SessionStart, PreToolUse, PostToolUse).

## Design
- **Event-driven architecture**: Hooks keyed by lifecycle stage (SessionStart, PreToolUse, PostToolUse) with nested matcher conditions (Bash, Write|Edit, Read, Task, plan modes)
- **Conditional execution**: `if` fields enable pattern matching (e.g., `Bash(git push *)`) to run specific scripts only for matching tool invocations
- **Timeout enforcement**: Each hook command specifies timeout (3s–60s) to prevent blocking execution
- **Async control**: Optional `async: false` flag (e.g., PR creation hooks) for synchronous execution when ordering matters

## Flow
1. **SessionStart** → Runs 12 sequential setup scripts (MCP servers, plugins, dependencies, monitoring)
2. **PreToolUse** → Intercepts tool calls (Bash/Write/Edit/Read) and runs guards (git safety, secret checks, file gates) before execution
3. **PostToolUse** → Triggers post-execution workflows (plan restructuring, test tracking, codemap updates, session monitoring)
4. Matchers and `if` conditions determine which subset of hooks fires per tool invocation

## Integration
- Invoked by Claude plugin runtime at session and tool lifecycle boundaries
- Scripts reference `${CLAUDE_PLUGIN_ROOT}` for cross-plugin access (knowledge MCP, Playwright MCP, claude-monitor, RTK, omni, gitnexus, cartography)
- Output from hooks feeds monitoring/tracking systems (claude-session-track.sh, claude-monitor); git operations guard critical workflows (protected branches, PR templates, commit identity)
