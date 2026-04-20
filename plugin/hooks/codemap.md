# plugin/hooks/

## Responsibility
Defines lifecycle hooks that execute scripts at key plugin lifecycle events (SessionStart, PreToolUse). Orchestrates initialization, safety checks, and preventive measures before tool execution.

## Design
JSON-based declarative hook configuration with event-driven architecture. Each hook specifies:
- **Event trigger**: `SessionStart` (session initialization), `PreToolUse` (before tool execution)
- **Matcher conditions**: Tool type matching (Bash, Write/Edit, etc.) and command pattern matching (e.g., `Bash(git push *)`)
- **Action type**: Command execution with configurable timeouts (3000-30000ms)
- **Conditional guards**: `if` conditions prevent execution on protected patterns (git --no-verify, secret files)

## Flow
1. **SessionStart**: On plugin initialization, sequentially runs 9 setup scripts (knowledge-mcp, plugins, permissions, playwright-mcp, claude-monitor, plan-viewer, rtk, cartography, briefing)
2. **PreToolUse**: Before Bash/Write/Edit tool execution, applies matching guards (git safety, secret detection, output compression) conditionally based on command patterns
3. Scripts return exit codes to halt execution on safety violations

## Integration
- Executed by plugin runtime on defined lifecycle events; scripts reference `${CLAUDE_PLUGIN_ROOT}` environment variable
- Prevents unintended operations (unauthorized git pushes, secret file modifications, wrong directory writes)
- Integrates with `scripts/` directory implementations (block-protected-push.sh, warn-secret-files.sh, etc.)
- Complements core plugin safety policy with automated preventive enforcement
