# plugin/scripts/

## Responsibility
`plugin/scripts/` provides pre/post-tool-use hooks and session utilities that enforce constraints, auto-optimize documentation, consolidate memory, and detect repository changes. These run transparently in the background without user intervention—blocking dangerous operations, compressing large outputs, and keeping codemaps synchronized.

## Design
Each hook is a standalone bash/Python script that reads JSON from stdin, pattern-matches against tool commands or outputs, and either blocks (exit 2), asks permission (JSON with `permissionDecision`), or emits guidance (JSON with `additionalContext`). Core patterns:
- **Block scripts** (`block-*.sh`): regex match command, emit error and exit 2
- **Intercept scripts** (`auto-compress-output.sh`, `auto-dream.sh`): check gates/conditions, emit `hookSpecificOutput` with compressed summary
- **Update scripts** (`auto-update-codemaps.py/sh`, `cartographer.py`): detect changed files/dirs via git, read source code, call Claude API to generate or refresh documentation
- **Cleanup/consolidation** (`auto-dream.sh`): dual-gate (session count + elapsed time) before triggering memory optimization via `auto-dream-prompt.md`

## Flow
1. **PreToolUse hooks** intercept commands before execution: `auto-compress-output.sh` runs high-output commands locally and summarizes via haiku; `block-*.sh` scripts reject dangerous patterns (direct protected-branch push, secret files, identity markers)
2. **PostToolUse hooks** observe tool results: `delegate-task-retry.sh` detects Task delegation failures and suggests fixes; `enforce-tdd.sh` reminds on implementation-only writes; `auto-observe.sh` logs session activity to patterns.db
3. **SessionStart** runs `ensure-cartography.sh` to check Tier 1 (docs/CODEBASE_MAP.md) and Tier 2 (.slim/cartography.json) staleness, prompting cartographer updates
4. **SessionStop** (via `auto-dream.sh`) dual-gates on session count + hours elapsed, then triggers memory consolidation prompt in background
5. **Git commit post-hook** (`auto-update-codemaps.sh`) runs `auto-update-codemaps.py`, which diffs changed dirs and regenerates affected `codemap.md` files

## Integration
- **Config**: `load-config.sh` (not in listing) provides `LEAN_FLOW_PROTECTED_BRANCHES`, `LEAN_FLOW_DREAM_SESSIONS`, `LEAN_FLOW_DREAM_HOURS`
- **Knowledge DB**: `auto-observe.sh` writes to `~/.claude/knowledge/patterns.db`; `auto-dream.sh` uses it for pattern pruning
- **Memory**: `auto-dream-prompt.md` defines consolidation rules; output goes to `~/.claude/projects/*/memory/`
- **Cartographer**: `.slim/cartography.json` tracks file hashes; `ensure-cartography.sh` calls `cartographer.py changes` and `update`; hooks read git diff-tree for affected dirs
- **Claude API**: `auto-update-codemaps.py` calls Claude API (OAuth from macOS keychain or `ANTHROPIC_API_KEY`) to generate codemap sections; `auto-dream.sh` shells out to `claude` CLI tool
- **Git**: All scripts use `git rev
