# plugin/scripts/

## Responsibility
`plugin/scripts/` contains PreToolUse/PostToolUse hooks and utility scripts that intercept, validate, and transform Claude's tool calls. These hooks enforce safety policies (no `--no-verify`, no secret files, no protected branch pushes), compress large command output via haiku, auto-update codemaps after commits, and consolidate project memory on session stop.

## Design
**Hook architecture**: Individual bash/Python scripts (`block-*.sh`, `auto-*.sh`) are composed into a unified `bash-guard.sh` that can be disabled per-check via `LEAN_FLOW_*_DISABLED` env vars. Each hook reads JSON from stdin, validates against patterns, and returns JSON or exits with code 2 (block). **Token optimization**: `auto-compress-output.sh` runs high-output commands directly (git log, tests, grep) and summarizes large results via Claude Haiku before returning to the model. **Codemap automation**: `auto-update-codemaps.py` detects changed directories from `git diff-tree`, reads file contents, and calls Claude API to generate directory documentation sections. **Pattern observability**: `auto-observe.sh` silently captures session tool usage and stores it in `~/.claude/knowledge/patterns.db` for later analysis. **Memory consolidation**: `auto-dream.sh` dual-gates (N sessions AND N hours) before running `auto-dream-prompt.md` to prune stale memories and deduplicate patterns.

## Flow
1. **PreToolUse hooks** intercept bash/git/gh commands → `bash-guard.sh` validates against policy rules → blocks (exit 2), asks (permissionDecision), or passes through
2. **Output compression** runs high-output commands directly, counts lines, calls Haiku API if >25 lines, returns compressed summary
3. **PostToolUse** on git commit → `auto-update-codemaps.sh` shells to Python → reads changed dirs → calls Claude API to fill codemap sections
4. **Session lifecycle**: on Stop → `auto-observe.sh` logs tool usage to patterns.db (no API call) → after N sessions + N hours, `auto-dream.sh` triggers consolidation in background (5min timeout, doesn't block)

## Integration
**Input**: hooks receive JSON from Claude's tool execution system via stdin (`.tool_input.command`, `.cwd`, `.session_id`). **Output**: JSON back to stdout (blocking decisions, compressed results) or direct API calls (Claude API via oauth keychain or `ANTHROPIC_API_KEY`). **Storage**: writes to `~/.claude/dream-state/` (session counters, lock files), `~/.claude/knowledge/patterns.db` (observed patterns), `.slim/cartography.json` (repo state via `cartographer.py`). **Env config**: loads from `load-config.sh` for `LEAN_FLOW_*` settings (protected branches, dream gates, per-check disables). **Subdir**: `project-doctor/` contains health check and remediation tools (called by consolidation or on demand).
