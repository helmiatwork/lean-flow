# plugin/scripts/

## Responsibility

`plugin/scripts/` contains PreToolUse/PostToolUse hooks and utility scripts that enforce workflow rules, optimize token usage, and automate maintenance tasks. Each script intercepts or follows tool execution to gate dangerous operations, compress output, update documentation, and consolidate memory.

## Design

- **Hook pattern**: Scripts read JSON from stdin (`jq` extract), decide silently (exit 0), ask permission (emit JSON to stdout), or block (exit 2 with error). PreToolUse gates *before* execution; PostToolUse analyzes *after*.
- **Dual-gate pattern**: `auto-dream.sh` requires both N sessions *and* N hours elapsed before running memory consolidation—prevents both spam and stale checks.
- **Lock files + state dirs**: `~/.lean-flow-dream-state/`, `/tmp/claude-sessions/` track session count, last-dream timestamp, and prevent concurrent runs via `lockfile` + age check.
- **Config injection**: Scripts source `load-config.sh` to read `LEAN_FLOW_*` environment variables (protected branches, dream thresholds, etc.).
- **Fallback chains**: `auto-update-codemaps.py` tries macOS keychain for OAuth, falls back to `ANTHROPIC_API_KEY` env var; `auto-observe.sh` silently exits if git/db unavailable.

## Flow

1. **PreToolUse hooks** (e.g., `block-secret-commits.sh`, `enforce-branch-naming.sh`) intercept Bash/git commands before Claude runs them.
   - Patterns match command strings; exit 2 blocks, exit 0 allows, JSON output requests permission.
2. **Output compression** (`auto-compress-output.sh`): detects high-output commands (git log, tests, recursive grep), runs them directly, compresses via Claude Haiku if >25 lines, returns summary instead of full output.
3. **PostToolUse hooks** (`auto-update-codemaps.sh`, `delegate-task-retry.sh`) run after tool execution, read results, emit guidance.
   - `auto-update-codemaps.py` diffs HEAD, reads affected directories, calls Claude API to regenerate `codemap.md` sections.
4. **Session end** (`auto-dream.sh`, `auto-observe.sh`): On Stop event, silently capture session logs to patterns.db, then trigger memory consolidation if gates pass.
5. **Repository mapping** (`cartographer.py`): Independent utility to hash directory contents and detect changes without API calls—prep work for codemap updates.

## Integration

- **Settings**: Reads `~/.claude/settings.json` and `~/.claude.json` via `jq` for plugin/MCP config validation (`check-dependencies.sh`).
- **Git workflow**: Enforces branch naming, blocks secret commits, protects main branches, blocks `--no-verify` bypasses.
- **Memory system**: `auto-dream.sh` invokes Claude with `auto-dream-prompt.md` to consolidate `~/.claude/projects/*/memory/` files; `auto-observe.sh` writes session observations to `~/.claude/knowledge/patterns.db`.
- **Keychain/OAuth**: `auto-update-codemaps.py` retrieves API credentials from macOS Keychain (fallback env var) to authenticate API calls.
- **Hook wiring**: Scripts are registered as PreToolU
