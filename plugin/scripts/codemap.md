# plugin/scripts/

## Responsibility
Automation hooks and utilities that manage the Claude dev workflow: memory consolidation, codebase cartography, security gates on git operations, TDD enforcement, and token-efficient output compression. Scripts run at session lifecycle points (Start, PreToolUse, PostToolUse, Stop) to enforce patterns without blocking the user.

## Design
**Hook-based intervention**: Each script is a small, focused gate (2-100 lines) that reads JSON input, makes a decision (allow/block/modify), and exits with status code 0 (pass), 2 (block), or emits JSON. **Dual-gate pattern** (auto-dream.sh, block-protected-push.sh) combines multiple conditions (time + session count, regex + branch check) before acting. **Background consolidation** (auto-dream.sh, auto-observe.sh) captures patterns asynchronously without blocking the session. **Token budgeting** (auto-compress-output.sh) intercepts high-output commands (git log, test runs, grep -r) and summarizes via Claude Haiku before returning results.

## Flow
1. **SessionStart**: `ensure-cartography.sh`, `ensure-claude-monitor.sh` check preconditions (git repo, Python, SwiftBar) and warn if mapping/monitoring is stale.
2. **PreToolUse**: `auto-compress-output.sh` intercepts read-heavy commands; `block-*.sh` gates prevent unsafe git operations (--no-verify, direct main/master push, secrets, .env staging, claude identity markers).
3. **PostToolUse**: `auto-update-codemaps.py` parses git diff-tree for changed dirs and calls Claude API to regenerate codemap.md sections; `enforce-tdd.sh` reminds users to write tests for new implementation files.
4. **SessionStop**: `auto-dream.sh` (dual-gated by time + session count) triggers `auto-observe.sh` to extract session patterns (tools used, repo, branch, duration) into patterns.db, then runs memory consolidation prompt.

## Integration
- **~/.claude/projects/**: Memory files read/written by auto-dream.sh consolidation task.
- **~/.claude/knowledge/patterns.db**: SQLite DB populated by auto-observe.sh; pruned/scored by auto-dream.sh memory consolidation.
- **~/.claude/plans/**: Target for plan storage (enforced by block-wrong-plan-dir.sh).
- **CLAUDE_PLUGIN_ROOT/scripts/claude-monitor/**: SwiftBar integration spawned by ensure-claude-monitor.sh.
- **cartographer.py**: File-hashing and codemap generation invoked by auto-update-codemaps.py and ensure-cartography.sh.
- **ANTHROPIC_API_KEY / macOS keychain**: OAuth token fallback in auto-update-codemaps.py for API calls.
- **git hooks ecosystem**: Scripts emit exit codes and JSON (`{"decision":"block"}`) for PreToolUse/PostToolUse handlers to interpret.
