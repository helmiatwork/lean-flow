# plugin/scripts/

## Responsibility

`plugin/scripts/` contains automation hooks and utilities that integrate with Claude's session lifecycle and git workflow. These scripts run as PreToolUse/PostToolUse interceptors, git hooks, and background consolidation tasks—enforcing TDD discipline, blocking unsafe operations, compressing verbose output, and maintaining project memory without explicit user invocation.

## Design

**Hook pattern**: Most scripts read stdin JSON, inspect tool commands/responses, and emit decision JSON (block/allow/context injection) or exit silently (zero cost on no-match).

**Gate pattern**: `auto-dream.sh` uses dual gates (session count + elapsed time) to throttle expensive consolidation; `auto-observe.sh` silently logs to SQLite with no API cost.

**Config loading**: Scripts source `load-config.sh` to read user settings (protected branches, dream frequency, etc.) without hardcoding policy.

**Token efficiency**: `auto-compress-output.sh` intercepts high-output commands (git log, test runs, recursive grep), runs them directly, compresses via haiku-4-5 if >25 lines, returns summary. `auto-update-codemaps.py` uses OAuth keychain fallback + git diff-tree to update only affected directories.

## Flow

1. **SessionStart**: `check-dependencies.sh` audits missing plugins/tools, emits single systemMessage if gaps detected (REQUIRED/RECOMMENDED/DEPRECATED buckets). Caches result by hash to avoid repeat noise.

2. **PreToolUse** (blocking gates):
   - `block-*.sh` scripts examine command string, reject unsafe patterns (--no-verify, protected branch pushes, .env stages, Claude identity markers).
   - `auto-compress-output.sh` intercepts read-heavy commands, executes locally, compresses if output >25 lines, returns JSON to block original call.
   - `block-secret-commits.sh` asks for confirmation on `git add -A` (may stage secrets).

3. **PostToolUse** (guidance injection):
   - `enforce-tdd.sh` detects implementation write without test, injects reminder + TDD workflow steps.
   - `delegate-task-retry.sh` catches Task tool failures, pattern-matches error type (missing params, rate limit, etc.), appends retry hint.
   - `auto-update-codemaps.sh` spawns `auto-update-codemaps.py` after git commit; Python script reads changed dirs from diff-tree, reads file contents, calls Claude API to fill codemap sections.

4. **SessionStop**: `auto-dream.sh` checks dual gates (N sessions + N hours), acquires lock, spawns background consolidation (memory cleanup + pattern DB decay) via haiku-4-5 with timeout.

5. **Silent observation**: `auto-observe.sh` (SessionStop) reads session log, extracts tool/command summary, writes to `~/.claude/knowledge/patterns.db` without API call.

## Integration

- **Settings**: Scripts read `~/.claude/settings.json` (jq), `~/.claude.json` (mcpServers), `.lean-flow-*` config via `load-config.sh`.
- **Git**: Commands validated against protected branches, hook state stored in `.git/hooks/`. Output diff-tree used for change detection.
- **Memory**: Pattern DB at `~/.claude/knowledge/patterns.db` (SQLite); dream state cached in `~/.claude/dream-state/` (last
