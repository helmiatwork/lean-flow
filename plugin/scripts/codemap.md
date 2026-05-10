# plugin/scripts/

## Responsibility

`plugin/scripts/` contains Git hooks, lifecycle automation, and auxiliary tooling that enforce workflow rules, compress token overhead, and maintain repository intelligence. It gates dangerous operations, consolidates memory, detects missing dependencies, and auto-updates documentation on commit.

## Design

**Hook architecture**: Scripts are split by event (PreToolUse, PostToolUse, SessionStart, Stop) and concern (blocking, compression, observation, updates). Each is independently executable and silent-failing (exit 0 to allow passthrough).

**Guard patterns**: `block-*.sh` scripts use regex on jq-extracted command strings to detect violations—Claude identity markers, --no-verify flags, direct pushes to protected branches, secret file staging. They emit structured JSON or stderr to signal block/ask decisions.

**Token optimization**: `auto-compress-output.sh` intercepts high-output commands (git log, test suites, recursive grep) and delegates to claude-haiku to summarize, avoiding token bloat. `auto-observe.sh` silently captures session patterns into `~/.claude/knowledge/patterns.db` for pattern matching in later sessions.

**Memory consolidation**: `auto-dream.sh` runs on SessionStop after dual gates (N sessions + N hours) to prune, merge, and reindex memories in `~/.claude/projects/*/memory/` and the patterns database. Uses `auto-dream-prompt.md` as instruction set.

**Documentation sync**: `auto-update-codemaps.py` runs PostToolUse on git commits, reads changed directories via `git diff-tree`, calls Claude API to generate/update `codemap.md` sections with file-level specifics.

**Observability**: `cartographer.py` tracks directory hashes and detects changes (init/changes/update commands) to feed codemap regeneration. `check-dependencies.sh` audits SessionStart for missing/misconfigured companion plugins (superpowers, jq, omni, gitnexus) and emits actionable system messages.

## Flow

**Pre-commit flow**: Bash command flows through `enforce-branch-naming.sh` (branch name check), `block-*.sh` pipeline (identity, --no-verify, protected branch, secret files). Blocks emit exit 2; asks emit JSON to `permissionDecision: "ask"`.

**Execution + observation**: High-output commands trigger `auto-compress-output.sh` (PreToolUse) which runs command directly, compresses via haiku if >25 lines, emits summary via `hookSpecificOutput`. `auto-observe.sh` (silent, no API) reads session log, extracts tool patterns, records to patterns.db.

**Post-commit**: `auto-update-codemaps.py` (PostToolUse) reads git diff-tree output, scans changed dirs, calls Claude API with directory contents and SYSTEM_PROMPT to fill codemap sections. Falls back to env var if keychain OAuth unavailable.

**Lifecycle automation**: `auto-dream.sh` (SessionStop) checks dual gates (session count, hours elapsed), acquires lock, spawns background haiku task to consolidate memories. `check-dependencies.sh` (SessionStart) audits SETTINGS and .claude.json, emits single systemMessage listing missing REQUIRED/RECOMMENDED tools with install hints (cache-keyed to avoid spam).

**Retry logic**: `delegate-task-retry.sh` (PostToolUse on Task tool) pattern-matches errors against table (missing subagent_type, invalid agent,
