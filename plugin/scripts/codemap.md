# plugin/scripts/

## Responsibility

Plugin scripts directory provides pre/post-tool hooks and automation tasks that enforce workflow guardrails, consolidate memory, auto-update documentation, and detect repository changes. These scripts run at SessionStart, PreToolUse, PostToolUse, and SessionStop lifecycle events to guide Claude's behavior within the codebase.

## Design

**Hook-based architecture**: Each `.sh` script is a discrete hook (PreToolUse, PostToolUse, SessionStart, SessionStop) that reads stdin JSON, applies pattern matching or state checks, and emits JSON decisions (block/allow/guidance). No inter-script dependencies.

**Gate patterns**: `auto-dream.sh` uses dual gates (session count + elapsed time) to throttle expensive consolidation. `auto-compress-output.sh` uses line-count threshold to decide whether to invoke haiku summarization. Guards prevent wasteful API calls.

**Configuration injection**: Scripts source `load-config.sh` to read `LEAN_FLOW_*` environment variables (protected branches, dream intervals, session thresholds) — single source of truth for tunable policies.

**Subdirectories**: `claude-monitor/` and `project-doctor/` contain specialized multi-file analysis tools (likely MCP servers or deeper diagnostics).

## Flow

1. **SessionStart**: `check-dependencies.sh` audits installed plugins/tools, caches findings by hash to suppress duplicate warnings.
2. **PreToolUse**: Git commands route through `block-*.sh` guards (protected branches, no-verify, secret files, branch naming); `auto-compress-output.sh` pre-executes high-output commands (git log, tests) and compresses output via haiku if > 25 lines.
3. **PostToolUse**: `auto-update-codemaps.py` detects changed directories from `git diff-tree`, reads file contents, calls Claude API to generate/update codemap.md sections. `delegate-task-retry.sh` detects Task tool failures and appends inline fix hints.
4. **SessionStop**: `auto-dream.sh` checks dual gates; if both pass, spawns background process running `auto-dream-prompt.md` (memory cleanup) via haiku model with 20-turn limit and 5-minute timeout.

`auto-observe.sh` silently captures session activity to `~/.claude/knowledge/patterns.db` by parsing session logs and storing tool/command observations keyed by session ID.

## Integration

- **Git hooks**: Scripts intercept git commands (commit, push, branch creation) and enforce workflow policies (no Claude identity attribution, no --no-verify, protected branch safety).
- **API integration**: `auto-update-codemaps.py` reads OAuth token from macOS keychain (fallback: ANTHROPIC_API_KEY) to call Claude API directly.
- **State management**: Uses `~/.claude/dream-state/`, `.slim/cartography.json`, `~/.claude/knowledge/patterns.db` for persistent lock files, change tracking, and pattern memory.
- **Model selection**: Uses claude-haiku-4-5-20251001 for token-efficient summarization and memory consolidation tasks.
- **Subdirectory tools**: `claude-monitor/` and `project-doctor/` likely provide deeper codebase analysis queried by hooks or triggered manually for diagnostics.
