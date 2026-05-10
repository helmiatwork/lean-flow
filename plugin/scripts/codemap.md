# plugin/scripts/

## Responsibility

`plugin/scripts/` provides **hook handlers** and **automation** for the Lean Flow development workflow. It intercepts Claude Code tool calls and git operations to enforce constraints, consolidate knowledge, update documentation, and detect configuration issues—all with zero or minimal token cost.

## Design

- **Hook architecture**: Each script processes stdin JSON (PreToolUse/PostToolUse events) and outputs JSON decisions or additionalContext. Exit codes: 0 = pass-through, 2 = block, other = special handling.
- **Pattern tables**: `delegate-task-retry.sh`, `block-*.sh` use regex tables to match error patterns and emit targeted fix hints.
- **State machines**: `auto-dream.sh`, `auto-observe.sh` track sessions/consolidation via files in `~/.claude/dream-state/` and SQLite (`patterns.db`), gated by thresholds (session count, elapsed hours).
- **Token-aware compression**: `auto-compress-output.sh` detects high-output commands (git log, pytest, grep -r), runs them locally, summarizes via Haiku model if >25 lines.
- **Documentation sync**: `auto-update-codemaps.py` detects git commit changes, reads affected dirs, calls Claude API to generate/update `codemap.md` sections.
- **Cartography mapping**: `cartographer.py` maintains `.slim/cartography.json` with file hashes and change diffs; used by codemaps updater and change detection.

## Flow

1. **PreToolUse hooks** (block-*.sh, enforce-branch-naming.sh): Intercept command before execution. Check constraints (protected branches, secret files, identity markers, naming rules). Output JSON with decision (block/allow) or permissionDecisionReason.
2. **Tool execution**: Command runs or is blocked.
3. **PostToolUse hooks** (auto-update-codemaps.sh, delegate-task-retry.sh): After execution, analyze output/exit code. Emit additionalContext with retry hints or trigger background documentation updates.
4. **SessionStart dependency audit** (check-dependencies.sh): Runs once per session, caches findings by hash, emits systemMessage with install instructions for missing REQUIRED/RECOMMENDED plugins.
5. **SessionStop consolidation** (auto-dream.sh): Dual-gated (N sessions + N hours). Triggers `patterns.db` optimization (auto-observe.sh captures session events to patterns.db) and memory cleanup via Haiku.

## Integration

- **Entry points**: Claude Code settings.json hooks (PreToolUse, PostToolUse, SessionStart, SessionStop matchers).
- **State**: `~/.claude/dream-state/`, `~/.claude/knowledge/patterns.db`, `.slim/cartography.json` (repo-local).
- **External tools**: jq (settings parsing), sqlite3 (patterns DB), git (diffs, branches), Python (Claude API calls, pattern DB ops).
- **Config**: `load-config.sh` (sourced by multi-file scripts) reads LEAN_FLOW_* env vars (protected branches, dream thresholds, etc.).
- **Output channels**: Exit codes, stderr, JSON to stdout, jq-emitted hook decisions, additionalContext appended to model turns, systemMessages at SessionStart.
