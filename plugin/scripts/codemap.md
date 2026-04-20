# plugin/scripts/

## Responsibility

`plugin/scripts/` contains lean-flow's runtime hooks and automation tools. It bridges the Claude API and local development workflow via:
- **PreToolUse/PostToolUse hooks** — intercept and gate commands (block secrets, protected branches, identity markers)
- **Auto-consolidation** — compress large outputs (haiku), update codemaps post-commit, consolidate memory periodically
- **Observability** — capture session patterns to knowledge database, monitor usage via SwiftBar
- **Repository mapping** — track code structure changes via cartographer, maintain tier-1/tier-2 documentation

## Design

**Hook-based interception pattern**: Each `block-*.sh` and `auto-*.sh` implements a discrete policy as a bash hook that reads JSON stdin, validates a command or file operation, and outputs `exit 2` (block) or JSON decision. No side effects unless explicitly gated.

**Dual-gate idiom** (e.g., `auto-dream.sh`): Session consolidation runs only after *both* N elapsed hours AND M sessions since last run, preventing spam while ensuring eventual consistency.

**Tiered mapping** (`ensure-cartography.sh`): Tier 1 uses `git log` to detect high-level changes in `docs/CODEBASE_MAP.md`; Tier 2 uses `cartographer.py` to track per-folder `codemap.md` diffs via content hashing (`.slim/cartography.json`).

**Token-aware fallback** (`auto-compress-output.sh`): Large command output compresses via Haiku API if available, falls back to truncation. Small outputs (<25 lines) bypass compression entirely — zero cost.

**Config-driven safety** (sourced from `load-config.sh`): Protected branch names, dream thresholds, and monitor enable/disable centralized in config; scripts exit silently if config not loaded.

## Flow

1. **Session start** → `SessionStart` hooks run `ensure-*.sh` (cartography, claude-monitor, knowledge-mcp) — idempotent setup
2. **Command execution** → `PreToolUse` hooks intercept: `block-*.sh` gates (secrets, identity, protected branches); `auto-compress-output.sh` runs high-output commands directly, compresses if >25 lines
3. **Post-commit** → `PostToolUse` hook runs `auto-update-codemaps.py` via `auto-update-codemaps.sh` — reads `git diff-tree`, updates affected directories' `codemap.md` via Claude API
4. **Session stop** → `auto-dream.sh` checks dual gates (hours + session count); if both pass, runs `auto-dream-prompt.md` in background with Haiku to consolidate memory/prune patterns
5. **Background observation** → `auto-observe.sh` silently logs session activity (tool usage, repo, branch) to `~/.claude/knowledge/patterns.db` via Python SQLite insert
6. **Monitor refresh** → launchd agent (installed by `ensure-claude-monitor.sh`) runs `claude-usage-fetch.sh` every 3min, SwiftBar plugin displays in menu bar

## Integration

- **Config layer**: All scripts source `${CLAUDE_PLUGIN_ROOT}/load-config.sh` for centralized settings (protected branches, dream gates, monitor toggle)
- **Knowledge MCP** (`ensure-knowledge-mcp.sh`):
