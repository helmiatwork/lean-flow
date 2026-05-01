# plugin/hooks/

## Responsibility
Defines lifecycle hooks that execute at key plugin events: session initialization, pre/post tool execution, and subagent lifecycle. Acts as the central configuration point for injecting validation, monitoring, and workflow automation into the Claude plugin runtime.

## Design
Hook system uses event-driven architecture with three layers: **event triggers** (SessionStart, PreToolUse, PostToolUse, SubagentStop), **matchers** (tool type filters like "Bash", "Write|Edit", "Read"), and **command payloads** (bash/python scripts with timeout enforcement). Conditionals via `"if"` field gate execution (e.g., `"if": "Bash(git push *)"` limits hook to specific tool invocations).

## Flow
SessionStart executes initialization chain sequentially (knowledge MCPs, plugin setup, CLI tool provisioning). PreToolUse gates dangerous operations (git push blocking, secret file warnings) before tools run. PostToolUse triggers post-execution workflows (plan restructuring, test tracking, codemap updates). Matchers enable targeted hook execution—Bash hooks block unsafe git operations; Write/Edit hooks warn on sensitive files; Read hooks apply access gates.

## Integration
Hooks orchestrate scripts across `plugin/scripts/` (ensure-*.sh for dependency setup, block-*.sh for security gates, workflow-hook.sh for event propagation). Coordinates with claude-monitor for session telemetry, plan-viewer for plan mode events, and auto-update-codemaps.sh for documentation sync. Timeout values (3s–60s) prevent blocking Claude's execution loop.
