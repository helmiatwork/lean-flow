# plugin/scripts/

## Responsibility
`plugin/scripts/` contains hook executables and background agents that enforce development workflows, optimize token usage, and maintain documentation. Scripts run at SessionStart/Stop, PreToolUse, and PostToolUse events, plus periodic background tasks (memory consolidation, codemap updates).

## Design
- **Hook pattern**: Most scripts read JSON from stdin, validate conditions, emit JSON to stdout with decision (`block`, `ask`, or pass-through)
- **Config-driven**: `load-config.sh` provides tunables (protected branches, dream gates, monitor toggle)
- **Zero-overhead guards**: Scripts exit early (exit 0) when conditions don't match—no API calls for irrelevant events
- **Dual-gate async tasks**: `auto-dream.sh` uses session count + elapsed time before triggering background consolidation; locks prevent concurrent runs
- **Cartography tiers**: Tier 1 (`CODEBASE_MAP.md` via git log), Tier 2 (per-folder `codemap.md` via `cartographer.py` change detection)

## Flow
1. **SessionStart**: `ensure-cartography.sh` + `ensure-claude-monitor.sh` check state, emit advisories
2. **PreToolUse**: `block-*.sh` scripts validate (git flags, secret files, protected branches, Claude identity); `auto-compress-output.sh` intercepts high-output commands, runs them locally, compresses via haiku if >25 lines
3. **PostToolUse**: `enforce-tdd.sh` checks for orphaned implementation files; `auto-update-codemaps.py` reads git diff-tree, syncs affected directories' `codemap.md`
4. **SessionStop**: `auto-observe.sh` logs session patterns to `~/.claude/knowledge/patterns.db`; `auto-dream.sh` (dual-gated by session count + hours) triggers background memory consolidation via Claude's haiku model

## Integration
- **Hooks**: Register in `.claude/config.json` under `hooks` section (SessionStart, PreToolUse, PostToolUse, SessionStop events)
- **State dirs**: `~/.claude/dream-state/` (consolidation gates), `~/.claude/knowledge/patterns.db` (SQLite observations), `.slim/cartography.json` (per-repo change tracking)
- **Config**: Sources `load-config.sh` for `LEAN_FLOW_*` vars (dream gates, protected branches, monitor toggle)
- **Tools**: Calls Claude API (haiku for compression), git CLI (log/diff), jq/Python for parsing; on macOS installs SwiftBar plugin via `claude-monitor/` subdir
