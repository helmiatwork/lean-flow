# plugin/scripts/

## Responsibility

`plugin/scripts/` contains PreToolUse and PostToolUse hooks that intercept and modify Claude's tool execution. Hooks enforce guardrails (block unsafe git operations, secret files, Claude attribution), compress large command outputs, auto-update documentation after commits, and consolidate session memory on stop.

## Design

**Hook architecture**: Each script reads JSON from stdin, inspects `.tool_input.command` or `.tool_input.file_path`, decides whether to block (exit 2), ask permission (exit 0 with JSON), or pass through (exit 0). `bash-guard.sh` unifies all git/gh checks with opt-out env vars (`LEAN_FLOW_*_DISABLED`). 

**Patterns**: `auto-compress-output.sh` detects high-output commands (git log, grep -r, test runs), executes them directly, compresses via haiku if >25 lines, returns summary without API call. `auto-update-codemaps.py` reads git diff-tree to find changed directories, collects file contents, calls Claude API to generate concise codemap sections. `auto-observe.sh` logs session activity to `~/.claude/knowledge/patterns.db` as lightweight observations.

**Config inheritance**: Scripts source `load-config.sh` for shared settings like `LEAN_FLOW_PROTECTED_BRANCHES`, `LEAN_FLOW_DREAM_SESSIONS`, `LEAN_FLOW_DREAM_HOURS`.

## Flow

1. **PreToolUse** (before tool execution): Guard scripts (`bash-guard.sh`, `block-*.sh`) inspect command, return block decision or pass through. `auto-compress-output.sh` runs high-output commands directly, compresses output, returns summary.

2. **PostToolUse** (after tool execution): `auto-update-codemaps.sh` triggers on git commit, calls `auto-update-codemaps.py` to detect changed directories and regenerate codemap sections via Claude API.

3. **Session stop** (background): `auto-dream.sh` checks dual gates (N sessions AND N hours), locks to prevent concurrent runs, spawns haiku consolidation task against memory files and patterns.db in background (300s timeout).

## Integration

- **Hooks entry point**: Scripts are registered as PreToolUse/PostToolUse hooks in Claude plugin manifest (not in this directory).
- **Config**: Inherits `LEAN_FLOW_*` settings from `load-config.sh` (sibling directory).
- **Token budget**: `auto-compress-output.sh` saves tokens by executing and summarizing locally; `auto-dream.py` uses haiku model for memory cleanup.
- **Knowledge DB**: `auto-observe.sh` writes session patterns to `~/.claude/knowledge/patterns.db`; `auto-dream.sh` reads and prunes it.
- **Codemap generation**: `auto-update-codemaps.py` reads repo structure and calls Claude API; results stored as `codemap.md` in each directory.
- **Subprocess directory**: `project-doctor/` contains specialized diagnostic/remediation tools (not documented here).
