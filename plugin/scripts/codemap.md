# plugin/scripts/

## Responsibility

This directory contains **session lifecycle hooks and automation scripts** that intercept Claude's tool execution, git workflows, and memory consolidation. It enforces constraints (branch naming, protected pushes, secret staging), compresses output, detects task delegation failures, and auto-updates documentation after commits.

## Design

- **Hook architecture**: PreToolUse/PostToolUse bash scripts that read stdin JSON, validate/transform commands, emit JSON decisions (`exit 2` = block, `exit 0` = pass-through).
- **Gate patterns**: `auto-dream.sh` and `auto-observe.sh` use dual gates (session count + time threshold, lock files) to prevent redundant runs.
- **Config inheritance**: Scripts source `load-config.sh` to read `LEAN_FLOW_*` env vars (protected branches, dream frequency, etc.) — keeps policy in one place.
- **Token optimization**: `auto-compress-output.sh` intercepts high-output commands (git log, test runs, recursive grep), runs them locally, summarizes via haiku if >25 lines. `cartographer.py` uses incremental file hashing to track repo changes without re-scanning.
- **Fallback chains**: OAuth → keychain → env var for API credentials; omni/rtk detection with degradation hints in `check-dependencies.sh`.

## Flow

1. **SessionStart**: `check-dependencies.sh` audits installed tools (jq, omni, gitnexus, knowledge-mcp), caches findings by hash to avoid repetition.
2. **PreToolUse** (command interception):
   - `auto-compress-output.sh` → detects high-output commands, executes directly, compresses via haiku.
   - `enforce-branch-naming.sh` → validates `git checkout -b` matches `feature/|fix/|improvement/...` pattern.
   - `block-*.sh` (5 scripts) → reject protected-branch pushes, `--no-verify` flags, `.env`/credential staging, Claude identity in commits, wrong plan dirs.
3. **PostToolUse**:
   - `auto-update-codemaps.sh` → calls Python script to detect changed dirs from HEAD commit, reads files, calls Claude API to fill codemap.md sections.
   - `delegate-task-retry.sh` → pattern-matches Task tool failures, appends retry guidance (missing params, invalid agent type) to next turn.
   - `auto-observe.sh` → silently logs session activity (tools used, branch, duration, key commands) to `~/.claude/knowledge/patterns.db`.
4. **SessionStop**: `auto-dream.sh` (dual-gated by session count + elapsed hours) triggers async memory consolidation (`claude --allowedTools Read,Write,Edit` with max 20 turns, 5-min timeout).

## Integration

- **Memory system**: `auto-dream.sh` uses `auto-dream-prompt.md` to consolidate `~/.claude/projects/*/memory/MEMORY.md` and prune `patterns.db` (unused patterns, stale refs, duplicates).
- **Cartographer**: `cartographer.py` maps repos (init hashes, detect changes, update state) — integrates with `auto-update-codemaps.py` to target changed dirs.
- **Git hooks**: Scripts assume `git` is available; `auto-update-codemaps.py` uses keychain (macOS) or `
