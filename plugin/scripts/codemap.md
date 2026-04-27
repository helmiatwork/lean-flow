# plugin/scripts/

## Responsibility
The `plugin/scripts/` directory contains hook implementations and automation tools that intercept Claude's workflow to enforce standards, compress output, update documentation, and manage memory consolidation. Each script is a specialized guard rail — blocking unsafe operations, optimizing token usage, or keeping codebase maps current.

## Design
Scripts follow a **hook-based architecture** layered by execution stage:
- **PreToolUse hooks** (`block-*.sh`, `auto-compress-output.sh`) intercept commands before execution, validating against policies or optimizing output.
- **PostToolUse hooks** (`enforce-tdd.sh`, `auto-update-codemaps.sh`) run after tool execution to trigger side effects (tests, docs).
- **SessionStart/Stop hooks** (`ensure-*.sh`, `auto-dream.sh`) manage background tasks: cartography indexing, memory consolidation, monitor installation.
- **Utility modules** (`cartographer.py`, `auto-observe.sh`) provide async pattern detection and directory mapping without blocking the main flow.

All blocks use jq for JSON parsing and exit code semantics: `exit 0` = pass-through, `exit 2` = block with reason, `exit 1` = error.

## Flow
1. **Command interception**: PreToolUse hooks parse `jq '.tool_input.command'` from stdin, test against blocklist patterns (protected branches, secrets, identity markers), and return decision JSON or exit 2.
2. **Output optimization**: `auto-compress-output.sh` detects high-output commands (git log, tests, grep -r), runs them directly, compresses via haiku if >25 lines, returns compressed summary.
3. **Documentation sync**: `auto-update-codemaps.py` hooks PostToolUse on git commits, reads changed dirs from `git diff-tree`, fetches file contents, calls Claude API to generate codemap sections.
4. **Memory consolidation**: `auto-dream.sh` runs on SessionStop after N sessions AND N hours, triggers `auto-dream-prompt.md` to prune patterns.db and consolidate ~/.claude/projects/ memories.
5. **Cartography indexing**: `ensure-cartography.sh` on SessionStart checks .slim/cartography.json state, runs `cartographer.py changes` to detect stale per-folder codemaps, reports affected folders.

## Integration
- **Config**: Scripts load `load-config.sh` for gated thresholds (LEAN_FLOW_PROTECTED_BRANCHES, LEAN_FLOW_DREAM_SESSIONS, LEAN_FLOW_DREAM_HOURS).
- **Claude CLI**: `auto-dream.sh`, `ensure-claude-monitor.sh` invoke `claude` binary with --model and --allowedTools flags; `auto-observe.sh` reads session logs from /tmp/claude-sessions/.
- **Knowledge system**: `auto-observe.sh` writes pattern observations to ~/.claude/knowledge/patterns.db; `auto-dream.py` prunes and merges entries.
- **Git hooks**: Blocks integrate with pre-commit validation; `auto-update-codemaps.sh` triggers as PostToolUse after commits.
- **SwiftBar monitor** (`claude-monitor/`): `ensure-claude-monitor.sh` installs plugin + launchd fetcher for usage stats; `auto-compress-output.sh` uses claude CLI to generate summaries.
