# plugin/hooks/

## Responsibility
Defines lifecycle hooks that trigger automated scripts during Claude plugin sessions. Orchestrates initialization, tool validation, and post-execution workflows to maintain code quality, security, and documentation standards.

## Design
- **Hook-based architecture**: `hooks.json` declares event triggers (`SessionStart`, `PreToolUse`, `PostToolUse`) with conditional matchers (`Bash`, `Write|Edit`, `Read`, `Task`, plan modes)
- **Command pattern**: Each hook executes bash or Python scripts with configurable timeouts and conditional guards (`if` fields)
- **Matcher filtering**: Hooks target specific tool types or patterns (e.g., `Bash(git push *)`, `Bash(gh pr create*)`) to avoid unnecessary execution
- **Async control**: Most hooks run synchronously; workflow hooks support async execution for non-blocking operations

## Flow
1. **SessionStart**: Chains 12 initialization scripts (MCP servers, plugins, permissions, dependencies) with 5-60s timeouts
2. **PreToolUse**: Validates incoming tool calls—blocks dangerous git operations, enforces naming/templates, gates file reads, tracks sessions
3. **PostToolUse**: Reacts to tool completion—updates checklists, regenerates codemaps, tracks test failures, restructures plans, delegates task retries
4. Each phase gates execution via matchers, allowing precise interception of specific operations

## Integration
- Invoked by Claude plugin runtime at session and tool-use boundaries
- References scripts in `${CLAUDE_PLUGIN_ROOT}/scripts/` (enforce-pr-template.sh, block-protected-push.sh, auto-update-codemaps.sh, etc.)
- Integrates with external tools: git, GitHub CLI (`gh`), Playwright MCP, rubocop, knowledge bases
- Feeds data to monitoring (claude-monitor/claude-session-track.sh) and plan management (restructure-plan.py, update-plan-checklist.sh)
