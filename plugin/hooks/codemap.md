# plugin/hooks/

## Responsibility
Central configuration for Claude plugin lifecycle and tool-use hooks. Defines automated startup initialization, git safety guards, and pre-execution validators that run during plugin sessions.

## Design
- **Hook registry pattern**: `hooks.json` organizes handlers by lifecycle event (`SessionStart`, `PreToolUse`) with optional matchers (`Bash`, `Write|Edit`) and conditional guards (`if` field)
- **Timeout enforcement**: Each hook specifies millisecond timeouts to prevent blocking operations (30s for MCPs, 3-5s for lightweight checks)
- **Guard-rail approach**: Pre-tool hooks intercept dangerous operations (git push, --no-verify, secret commits) via conditional pattern matching before execution

## Flow
1. **SessionStart** triggers sequentially through 9 initialization scripts (knowledge MCP → plugins → permissions → MCPs → monitoring → RTK → cartography → briefing)
2. **PreToolUse** evaluates incoming Bash commands and file operations against matchers/conditions
3. Matching hooks execute validation/blocking scripts; non-matching hooks skip execution
4. Auto-compression runs universally for Bash tools to limit output verbosity

## Integration
- Scripts referenced in hooks live in `${CLAUDE_PLUGIN_ROOT}/scripts/` (sibling directory)
- Hooks integrate with Claude's tool execution system via `type: "command"` handlers
- Guards prevent accidental git identity leaks, secret pushes, and file operations in protected directories
- Output compression (`auto-compress-output.sh`) integrates with downstream log handling
