# plugin/hooks/

## Responsibility
Central lifecycle hook configuration for the Claude plugin system. Defines automated actions triggered at key session and tool execution points (SessionStart, PreToolUse, PostToolUse, SubagentStop) to enforce security, manage dependencies, track workflows, and coordinate plugin initialization.

## Design
Event-driven hook system using matchers to conditionally execute bash/python scripts. Each hook entry specifies:
- **Hook type**: `command` execution with timeout and optional `if` conditions
- **Matchers**: Tool names (Bash, Write, Edit, Read, Task, EnterPlanMode, ExitPlanMode) to filter when hooks run
- **Async support**: Explicit `async: false` flag for synchronous execution (e.g., PR creation)
Hooks are organized by lifecycle stage with layered execution — base hooks run always, matcher-specific hooks add conditional logic.

## Flow
1. **SessionStart**: Sequentially ensure MCPs, plugins, permissions, and monitoring tools are initialized (ensures-* scripts, 30s timeout for heavy operations)
2. **PreToolUse**: Bash tool use triggers git security checks (block-protected-push, block-no-verify, block-secret-commits); Read/Write/Edit matchers gate file access; auto-compress output runs last
3. **PostToolUse**: Write/Edit updates trigger workflow hooks; plan mode transitions (Enter/Exit) restructure and track state; PR creation and git commits trigger async workflows; task delegation retried
4. **SubagentStop**: Workflow cleanup hook fires

## Integration
- **Scripts**: All hooks invoke bash/python scripts in `${CLAUDE_PLUGIN_ROOT}/scripts/` (ensure-*.sh, block-*.sh, workflow-hook.sh, auto-update-codemaps.sh, claude-monitor/*, restructure-plan.py)
- **Tool matchers**: Integrates with Claude's tool execution pipeline (Bash, Read, Write, Edit, Task, EnterPlanMode, ExitPlanMode)
- **Session tracking**: claude-monitor integration logs PreToolUse and PostToolUse events
- **Workflow system**: workflow-hook.sh dispatches to external workflow handlers at each lifecycle stage
