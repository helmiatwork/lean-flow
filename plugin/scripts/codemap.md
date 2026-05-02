# plugin/scripts/

## Responsibility

`plugin/scripts/` contains hook handlers and automation tools that intercept Claude Code operations—pre/post tool use, session lifecycle, git operations—to enforce workflow rules, consolidate memory, update documentation, and optimize token usage. Every script is silent-by-default; they fail open (exit 0) unless blocking is required.

## Design

- **Hook pattern**: Each script reads JSON from stdin (tool input/output), checks conditions via regex/jq, emits JSON back or exits with decision code (0=pass, 2=block). No side effects unless stated.
- **Silent default**: Missing files, unavailable CLIs, non-matching conditions all → exit 0. Only emit output when actionable.
- **Dual-gated activation**: `auto-dream.sh` and `auto-observe.sh` use session counters + time windows to prevent runaway overhead. `auto-compress-output.sh` checks line count before invoking haiku model.
- **Stateless blocks**: `block-*.sh` scripts are read-only guards that reject dangerous patterns (--no-verify, protected branches, secret files, Claude identity in commits).
- **Async background ops**: `auto-dream.sh` spawns consolidation in background with lock file to prevent concurrent runs and 5-minute timeout.

## Flow

1. **PreToolUse** → `auto-compress-output.sh` intercepts high-output commands (git log, test runs, grep -r), runs them directly, compresses via Haiku if >25 lines, returns summary.
2. **PreToolUse** → `block-*.sh` guards reject git commits with --no-verify, pushes to protected branches, secret file staging, Claude identity markers, wrong plan directory, wrong flags.
3. **PostToolUse (Write/Edit)** → `enforce-tdd.sh` detects implementation files written without tests, injects TDD workflow reminder (RED→GREEN→REFACTOR).
4. **PostToolUse (Task)** → `delegate-task-retry.sh` catches Task delegation failures (missing subagent_type, InputValidationError, rate-limit), emits pattern-matched fix hints inline.
5. **PostToolUse (git commit)** → `auto-update-codemaps.py` extracts changed directories, reads file contents, calls Claude API to generate/refresh codemap.md sections per dir.
6. **SessionStop** → `auto-dream.sh` checks dual gates (24+ hours elapsed AND N sessions since last consolidation), spawns background memory consolidation (dedup, prune patterns, optimize token cost) via haiku model.
7. **SessionStop** → `auto-observe.sh` silently logs session tool counts/branch/repo to patterns.db (SQLite), no API call.
8. **SessionStart** → `check-dependencies.sh` audits for missing companion plugins (superpowers, omni, gitnexus, rtk, knowledge-mcp), emits categorized systemMessage once per unique missing set (cached by hash).

## Integration

- **Config source**: `load-config.sh` (not shown) supplies `LEAN_FLOW_PROTECTED_BRANCHES`, `LEAN_FLOW_DREAM_SESSIONS`, `LEAN_FLOW_DREAM_HOURS`, `CLAUDE_PLUGIN_ROOT`, CLI tool paths.
- **State dirs**: `~/.claude/dream-state/` (session count, last-dream timestamp, lock), `~/.claude/knowledge/
