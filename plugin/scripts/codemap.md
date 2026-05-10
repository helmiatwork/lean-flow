# plugin/scripts/

# plugin/scripts/ Codemap

## Responsibility
Automation hooks and utilities for the lean-flow workflow. Intercepts Claude tool calls (PreToolUse), observes session activity (PostToolUse), enforces team rules (branch naming, PR templates, TDD), auto-updates documentation (codemaps), and consolidates session memory.

## Design
- **Hook pattern**: PreToolUse/PostToolUse handlers read stdin JSON, emit stdout JSON with `hookSpecificOutput` or block via exit code 2
- **Guard composition**: `bash-guard.sh` unifies multiple git/gh blockers with individual opt-out env vars (`LEAN_FLOW_*_DISABLED`)
- **Output compression**: `auto-compress-output.sh` intercepts high-volume commands (git log, test suites), runs them directly, summarizes via haiku if >25 lines
- **Cartography tiers**: Tier 1 (`docs/CODEBASE_MAP.md` via git history), Tier 2 (per-folder `codemap.md` via `cartographer.py` hashing)
- **Memory gates**: `auto-dream.sh` dual-gates consolidation on session count AND elapsed time to avoid thrashing

## Flow
1. **SessionStart**: `ensure-cartography.sh` + `check-dependencies.sh` emit system messages about stale codemaps and missing tools
2. **PreToolUse**: `bash-guard.sh` (git/gh blockers), `enforce-branch-naming.sh`, `enforce-pr-template.sh`, `auto-compress-output.sh` intercept commands, block or pass through
3. **PostToolUse**: `compact-nudge.js` (context threshold), `enforce-tdd.sh` (test existence), `delegate-task-retry.sh` (Task tool fixes), `auto-update-codemaps.py` (commit-triggered updates)
4. **SessionStop**: `auto-observe.sh` (silent session pattern capture) → `patterns.db`, then `auto-dream.sh` (memory consolidation if gates pass)
5. **Manual**: `cartographer.py` (`init`/`changes`/`update`) tracks file hashes and triggers codemap refreshes

## Integration
- **Settings bridge**: Reads `~/.claude/settings.json`, `~/.claude.json`, `load-config.sh` for `LEAN_FLOW_*` env vars
- **Knowledge store**: `auto-observe.sh` → `patterns.db`; `auto-dream.sh` reads/prunes memory files
- **Git integration**: All scripts assume repo context; `auto-update-codemaps.py` uses `git diff-tree` to detect changed dirs
- **Keychain/API**: `auto-update-codemaps.py` fetches OAuth token from macOS keychain, falls back to `ANTHROPIC_API_KEY`
- **Cartographer state**: `.slim/cartography.json` (hashes), per-folder `codemap.md` (docs)
- **Task tool**: `delegate-task-retry.sh` post-processes failures, suggests parameter fixes for orchestrator retry
