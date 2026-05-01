# plugin/hooks/

## Responsibility

`plugin/hooks/` defines the lifecycle hooks that trigger automated scripts at key session and tool execution points. `hooks.json` is the central configuration declaring when and how scripts run during SessionStart, PreToolUse, PostToolUse, and SubagentStop events.

## Design

- **Event-driven architecture**: Four primary hook points (SessionStart, PreToolUse, PostToolUse, SubagentStop) map to lifecycle phases
- **Conditional execution**: Hooks use `matcher` patterns (e.g., "Bash", "Write|Edit", "Read") and `if` guards (e.g., `Bash(git push *)`) to target specific tool operations
- **Timeout and async control**: Each command specifies `timeout` (milliseconds) and optional `async: false` for synchronous execution
- **Script abstraction**: Hooks invoke bash/python scripts in `${CLAUDE_PLUGIN_ROOT}/scripts/` rather than inline logic

## Flow

1. **SessionStart**: Chains 12 initialization scripts (knowledge MCP, plugins, permissions, MCPs, monitors, dependency checks)
2. **PreToolUse**: Applies guards (git protection rules, file read gates) before Bash/Write/Edit/Read tools execute; runs compression and monitoring
3. **PostToolUse**: Triggers workflows on Write/Edit, plan mode transitions, PR creation, test tracking, and codemap updates
4. **SubagentStop**: Invokes workflow cleanup hook

## Integration

- **Scripts**: Hooks delegate to shell/Python scripts in `plugin/scripts/` (e.g., `block-protected-push.sh`, `auto-update-codemaps.sh`, `claude-monitor/`)
- **Tool matchers**: Integrates with tool types (Bash, Write, Edit, Read, Task, EnterPlanMode, ExitPlanMode)
- **Plugin initialization**: SessionStart ensures all MCPs and plugins (knowledge, playwright, RTK, omni, gitnexus, cartography) are available before session begins
