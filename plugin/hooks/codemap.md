# plugin/hooks/

## Responsibility
Defines lifecycle hooks that execute scripts at key plugin events (SessionStart, PreToolUse, PostToolUse). Controls initialization, tool execution guards, and post-action workflows—enabling dependency setup, security checks, and automated updates across the plugin ecosystem.

## Design
Hook registry pattern in `hooks.json` with three lifecycle phases: each phase contains conditional matchers (Bash, Write/Edit, Read, Task, plan modes) paired with command arrays. Supports conditional execution via `if` patterns, async control, and per-command timeouts. Uses variable interpolation (`${CLAUDE_PLUGIN_ROOT}`) for script paths.

## Flow
1. **SessionStart**: Sequential execution of 12+ setup scripts (MCP servers, plugins, permissions, dependencies)
2. **PreToolUse**: Conditional guards based on tool type—Bash operations trigger git/secret validation; Write/Edit warn on sensitive files; Read gates file access
3. **PostToolUse**: Triggered after tool execution—restructures plans, updates checklists, tracks test failures, auto-commits codemaps, delegates task retries. Logging via `claude-session-track.sh`

## Integration
Invoked by the plugin runtime at tool lifecycle events. Scripts in `${CLAUDE_PLUGIN_ROOT}/scripts/` handle MCP server provisioning (knowledge, playwright, omni), git safety enforcement, file access control, and workflow automation. Coordinates with plan mode (ExitPlanMode restructuring), task delegation, and session monitoring systems.
