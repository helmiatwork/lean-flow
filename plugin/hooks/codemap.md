# plugin/hooks/

## Responsibility
Defines lifecycle hooks that trigger automated scripts at key workflow stages (SessionStart, PreToolUse, PostToolUse, SubagentStop). Enforces security guardrails, manages tool execution controls, and coordinates plugin initialization and monitoring across the entire Claude plugin ecosystem.

## Design
- **Event-driven architecture**: Hooks keyed by lifecycle event (SessionStart, PreToolUse, PostToolUse, SubagentStop)
- **Matcher-based filtering**: PreToolUse/PostToolUse hooks conditionally execute based on tool type (Bash, Write/Edit, Read, Task, etc.) or command patterns (e.g., `Bash(git push *)`)
- **Configurable timeouts**: Each hook specifies execution timeout; async option available (e.g., `"async": false` for PR creation tracking)
- **Bash script composition**: Modular enforcement scripts (block-protected-push.sh, warn-secret-files.sh, auto-compress-output.sh, etc.) loaded at runtime

## Flow
1. **SessionStart**: 12 initialization scripts execute sequentially (MCP servers, permissions, plugins, monitors)
2. **PreToolUse**: 
   - Bash tools filtered for security checks (git push protection, --no-verify blocking, secret detection)
   - Write/Edit triggers secret file warnings and plan directory validation
   - Read operations gated by file-read-gate.sh
   - All routes through claude-session-track.sh for monitoring
3. **PostToolUse**: Write/Edit, plan mode transitions (Enter/Exit), Bash PR creation, and task delegation trigger respective workflows; auto-update-codemaps.sh fires on git commits
4. **SubagentStop**: Cleanup via workflow-hook.sh

## Integration
- **Scripts location**: `${CLAUDE_PLUGIN_ROOT}/scripts/` (bash and Python executables)
- **Monitors**: claude-monitor, claude-session-track.sh provide runtime telemetry
- **Workflows**: workflow-hook.sh bridges hook events to higher-level orchestration
- **Dependencies**: Integrated with plan-viewer, RTK, Omni, GitNexus, Cartography plugins (initialized in SessionStart)
- **File operations**: Codemaps auto-updated on commits; plan restructuring on ExitPlanMode via Python script
