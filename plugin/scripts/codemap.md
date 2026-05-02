# plugin/scripts/

## Responsibility

This directory contains **hook scripts and automation agents** that enforce workflow discipline, optimize token usage, and consolidate memory across Claude sessions. Scripts run at key lifecycle points (SessionStart, PreToolUse, PostToolUse, SessionStop) to gate commands, compress output, update documentation, and learn from patterns.

## Design

- **Hook-oriented**: Each script listens to a specific event (PreToolUse on Bash/Task, PostToolUse on Write/Edit, SessionStart/Stop lifecycle)
- **Silent-by-default**: Scripts exit 0 (no-op) unless they detect a violation or optimization opportunity; no token cost for normal flow
- **Dual-gated memory consolidation** (`auto-dream.sh`): runs only after N sessions AND N hours elapsed, preventing thrashing
- **Pattern capture** (`auto-observe.sh`): zero-token background logging of session activity to SQLite knowledge DB
- **Config-driven**: Loads `LEAN_FLOW_PROTECTED_BRANCHES`, `LEAN_FLOW_DREAM_SESSIONS`, etc. from `load-config.sh`
- **Fallback resilience**: OAuth → env var for API tokens; haiku summarization falls back to truncation; lock files prevent concurrent dream runs

## Flow

1. **SessionStart** (`check-dependencies.sh`): audits missing tools/plugins, caches finding hash to avoid duplicate warnings
2. **PreToolUse** (`block-*.sh` suite): intercept Bash/git/Task commands, validate against rules (no protected branch pushes, no secret files, no Claude identity in commits)
3. **PreToolUse** (`auto-compress-output.sh`): detects high-output commands (git log, test suites), runs directly, compresses via haiku if >25 lines
4. **PostToolUse** (`auto-update-codemaps.py`): after git commit, diffs changed dirs, reads source files, calls Claude API to auto-fill codemap.md sections
5. **PostToolUse** (`enforce-tdd.sh`): if implementation file written, checks for test file; if missing, injects TDD reminder (RED→GREEN→REFACTOR flow)
6. **PostToolUse** (`delegate-task-retry.sh`): detects Task tool failures, pattern-matches error output, appends retry hints with fixed parameters
7. **SessionStop** (`auto-dream.sh`): if N sessions + N hours elapsed, launches background `claude` process with `auto-dream-prompt.md` to prune memory, merge duplicates, decay stale patterns

## Integration

- **Settings & config**: reads `~/.claude/settings.json`, `~/.claude.json`, `LEAN_FLOW_*` env vars via `load-config.sh`
- **Git hooks**: runs as Claude Code hook events, not traditional git hooks; validates state via `git rev-parse`, `git diff-tree`, `git branch`
- **Knowledge DB**: `auto-observe.sh` writes session observations to `~/.claude/knowledge/patterns.db` (SQLite); auto-dream prunes/decays it
- **Memory system**: consolidates `~/.claude/projects/*/memory/MEMORY.md` files; estimates token cost across all project memories
- **Cartographer** (`cartographer.py`): companion file-hashing tool; codemaps integration point for tracking repo structure changes
- **OAuth/Keychain**: `auto-update-codemaps.py`
