# plugin/scripts/

## Responsibility

`plugin/scripts/` provides the lean-flow workflow automation layer—PreToolUse blockers, PostToolUse nudges, auto-consolidation, and codemap generation. These hooks enforce constraints (no `--no-verify`, protected branches, Claude identity), compress verbose output, detect and guide task failures, and maintain living documentation (codemaps, memory consolidation).

## Design

**Hook Pattern**: Each script is a single-responsibility hook (PreToolUse or PostToolUse) that reads stdin JSON, applies logic, and emits `jq` output with `hookSpecificOutput` or exit code 2 (block). 

**Unified Guards**: `bash-guard.sh` consolidates all git/gh blockers with opt-out env vars (`LEAN_FLOW_*_DISABLED`); `cartographer.py` tracks file hashes and changed directories for incremental codemap updates; `auto-update-codemaps.py` leverages Claude's API (with OAuth keychain fallback) to generate accurate documentation sections.

**Async Tasks**: `auto-dream.sh` uses dual gates (session count + elapsed time) and lockfiles to prevent concurrent memory consolidation; `compact-nudge.js` debounces context warnings; `auto-observe.sh` silently logs session patterns to SQLite without API calls.

## Flow

1. **PreToolUse Bash**: `bash-guard.sh` blocks risky commands (`--no-verify`, protected branch pushes, secret files, Claude identity, PR comments); `enforce-branch-naming.sh` validates branch prefixes; `enforce-pr-template.sh` requires template usage.

2. **PostToolUse Write/Edit**: `enforce-tdd.sh` injects test reminders when implementation files are written; `auto-compress-output.sh` intercepts high-output commands (git log, pytest, recursive grep), runs them, compresses output via haiku if >25 lines.

3. **PostToolUse Task**: `delegate-task-retry.sh` detects delegation failures and appends inline retry guidance with concrete parameter fixes.

4. **PostToolUse (all tools)**: `compact-nudge.js` reads session metrics from `/tmp/claude-ctx-{session_id}.json` and nudges compaction when context usage ≥30%, debounced every 10 tool calls.

5. **SessionStart**: `check-dependencies.sh` audits missing/misconfigured companion plugins (superpowers, omni, gitnexus, rtk, knowledge-mcp), caches hash of findings to avoid duplicate emissions.

6. **SessionStop**: `auto-dream.sh` triggers memory consolidation (dual-gated by session count and hours elapsed); `auto-observe.sh` silently appends session activity (tools used, commands, duration) to `~/.claude/knowledge/patterns.db`.

7. **PostToolUse Git**: `auto-update-codemaps.py` (via `auto-update-codemaps.sh`) runs after commits, uses `cartographer.py` to detect changed directories, reads file contents, calls Claude API to generate or update `codemap.md` sections.

## Integration

- **Settings/Config**: `load-config.sh` sourced by bash scripts to read `LEAN_FLOW_*` env vars (dream session count, hours, individual check toggles).
- **APIs**: OAuth token (macOS keychain) or `ANTHROPIC_API_KEY` env var for `auto-
