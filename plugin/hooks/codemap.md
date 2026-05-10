# plugin/hooks/

## Responsibility
Defines lifecycle hooks for the Claude plugin that execute at key workflow stages (SessionStart, PreToolUse, PostToolUse, SubagentStop). Orchestrates initialization scripts, safety guards, and post-action workflows to maintain system integrity and automation.

## Design
Hook registry organized by event type with optional matchers (Bash, Write/Edit, Read, Task, EnterPlanMode, ExitPlanMode). Each hook contains command-based actions with configurable timeouts and conditional execution ("if" filters). Supports both synchronous and async execution modes. Uses bash/python scripts as hook implementations via `${CLAUDE_PLUGIN_ROOT}/scripts/` references.

## Flow
**SessionStart** → Initializes MCPs (knowledge, playwright, omni), ensures plugins/permissions/dependencies, runs workflow hook. **PreToolUse** → Guards against dangerous Bash patterns (force-push, secret commits, no-verify flags), enforces naming/PR standards, applies tool-specific gates (file-read, plan-dir validation). **PostToolUse** → Triggers post-write workflows, tracks test failures, updates plan state (restructure on exit), auto-updates codemaps on commits. **SubagentStop** → Reviews subagent output, fires final workflow hook.

## Integration
Hooks invoke scripts in `scripts/` directory (bash-guard.sh, ensure-*.sh, block-*.sh, enforce-*.sh, workflow-hook.sh). Hooks reference `${CLAUDE_PLUGIN_ROOT}` for dynamic root resolution. Integrates with git/GitHub workflows (gh pr, git push), plan-mode system, codemaps, and test tracking. Conditional execution filters on tool type and command patterns enable fine-grained control flow between plugin components.
