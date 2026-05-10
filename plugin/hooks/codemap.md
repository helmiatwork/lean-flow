# plugin/hooks/

## Responsibility
Defines lifecycle hooks that execute at key plugin events (SessionStart, PreToolUse, PostToolUse, SubagentStop, Stop). Orchestrates initialization scripts, git/security guardrails, and workflow callbacks through a declarative hook configuration system.

## Design
JSON-based hook registry with event-driven architecture. Each hook entry specifies: matcher (tool type filter), conditional execution ("if" patterns), command type (bash/python), timeout, and async behavior. Matchers like "Bash", "Write|Edit", "Read" route hooks to appropriate tool invocations. PreToolUse hooks enforce constraints before execution; PostToolUse hooks react after completion.

## Flow
1. **SessionStart**: Sequential initialization chain (knowledge-mcp → plugins → permissions → playwright-mcp → plan-viewer → rtk → omni → gitnexus → cartography → dependencies check → workflow-hook)
2. **PreToolUse**: Conditional guards intercept Bash (git push/commit/pr), Write/Edit (secret files, plan directory), and Read operations before execution
3. **PostToolUse**: Matchers trigger on Write/Edit, EnterPlanMode, ExitPlanMode, Bash (with optional async), Task delegation, and global codemap updates
4. **SubagentStop/Stop**: Post-agent review and final workflow callbacks

## Integration
Hooks execute scripts from `${CLAUDE_PLUGIN_ROOT}/scripts/` directory (ensure-*.sh, block-*.sh, enforce-*.sh, workflow-hook.sh, restructure-plan.py). Timeouts range 3s–60s depending on operation complexity. Integrates with git/GitHub CLI (pre-push validations, PR templates, branch naming), plan mode system (restructure-plan.py), and codemap maintenance (auto-update-codemaps.sh).
