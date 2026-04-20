# plugin/scripts/

## Responsibility
Implements lean-flow plugin hooks and automation: memory consolidation, cartography updates, TDD enforcement, output compression, and protective git guardrails. Entry points for SessionStart/Stop, PreToolUse/PostToolUse events, and background daemons (monitor, auto-dream).

## Design
**Hook architecture**: Each shell script reads JSON stdin, makes decisions (block/allow/modify), outputs JSON or exits with code 2 (block). **Dual-gate pattern**: `auto-dream.sh` uses session count + elapsed time before consolidation. **Cartography strategy**: Tier 1 (`CODEBASE_MAP.md` via git log), Tier 2 (per-folder `codemap.md` via `cartographer.py` change detection). **Token optimization**: `auto-compress-output.sh` intercepts high-output commands, runs them directly, summarizes via haiku if >25 lines. **Config injection**: `load-config.sh` sources `LEAN_FLOW_*` environment variables (protected branches, dream thresholds, monitor toggle).

## Flow
1. **SessionStart** → `ensure-cartography.sh` checks mapping staleness, `ensure-claude-monitor.sh` installs SwiftBar monitor
2. **PreToolUse** (Bash) → `auto-compress-output.sh` intercepts git log/tests/grep, runs directly, compresses output; `block-*.sh` validate git/PR commands
3. **PostToolUse** (Write/Edit/Commit) → `enforce-tdd.sh` checks for matching test files, `auto-update-codemaps.py` reads changed dirs via `git diff-tree`, calls Claude API with directory contents
4. **SessionStop** → `auto-dream.sh` checks dual gates (N sessions + N hours), locks, spawns haiku consolidation in background via `auto-dream-prompt.md`; `auto-observe.sh` parses session log, extracts tool patterns, writes observations to `~/.claude/knowledge/patterns.db`

## Integration
- **Hooks**: Invoked by lean-flow runtime at SessionStart/Stop, PreToolUse/PostToolUse events
- **APIs**: `auto-update-codemaps.py` calls Claude API (OAuth from keychain or `ANTHROPIC_API_KEY`); `auto-compress-output.sh` shells to haiku model
- **Cartographer**: `ensure-cartography.sh` spawns `cartographer.py` to detect changed folders; paired with `auto-update-codemaps.py` for per-folder codemap generation
- **Monitor**: `ensure-claude-monitor.sh` installs `claude-monitor/` (SwiftBar plugin + fetcher + launchd) to track API usage in menu bar
- **Config**: All scripts source `load-config.sh` for runtime settings (protected branches, dream intervals, monitor toggle)
