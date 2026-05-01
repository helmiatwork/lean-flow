# plugin/hooks/

## Responsibility
Defines all plugin lifecycle and tool-use hooks executed during Claude sessions. `hooks.json` is the central configuration that orchestrates initialization, pre/post-tool validation, security checks, and cleanup via bash/python scripts.

## Design
Hook events are organized by lifecycle stage (`SessionStart`, `PreToolUse`, `PostToolUse`, `SubagentStop`, `Stop`). Each event contains matcher-based hook chains that conditionally execute scripts. Matchers filter by tool type (Bash, Write, Read, Task, EnterPlanMode, ExitPlanMode). Conditional execution uses `if` patterns like `Bash(git push *)` for fine-grained control. Timeouts (3s–60s) prevent runaway processes.

## Flow
1. **SessionStart**: Initializes MCPs (knowledge, playwright, monitor), plugins, and permissions; runs workflow setup.
2. **PreToolUse**: Bash hooks block dangerous operations (force-push, no-verify, secret commits); file access gates (Write/Edit/Read); session tracking.
3. **PostToolUse**: Tracks writes, plan mode transitions, PR creation, test failures; auto-updates codemaps on git commit; restructures plans on exit; delegates task retries.
4. Terminal events (SubagentStop, Stop) trigger workflow cleanup hooks.

## Integration
Scripts live in `${CLAUDE_PLUGIN_ROOT}/scripts/` and subdirectories (`claude-monitor/`, etc.). Hooks integrate with git operations, file system access, task delegation, plan-viewer, and RTK workflow. Session tracking feeds data to claude-monitor for observability. Codemap updates sync documentation on commits. All timeouts and conditions reference external shell/python implementations—this file is configuration only.
