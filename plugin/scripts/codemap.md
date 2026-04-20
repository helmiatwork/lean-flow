# plugin/scripts/

## Responsibility

The `plugin/scripts/` directory provides git hooks, automation agents, and monitoring tools that enforce development practices, optimize Claude interactions, and maintain codebase documentation. It bridges the Claude CLI with repository workflows and memory consolidation systems.

## Design

- **Hook pattern**: Bash wrappers (`block-*.sh`, `auto-*.sh`, `enforce-tdd.sh`) intercept git and tool commands via PreToolUse/PostToolUse, returning JSON decisions to allow/block/modify behavior
- **Config inheritance**: Scripts source `load-config.sh` (not shown) to read `LEAN_FLOW_*` env vars for session gates, protected branches, TDD enforcement
- **Silent agents**: `auto-dream.sh` (session consolidation), `auto-observe.sh` (pattern capture), and `auto-compress-output.sh` (large output handling) run in background with dual gates (session count + time elapsed) to avoid token waste
- **Cartographer integration**: `cartographer.py` maintains `.slim/cartography.json` hash state; `auto-update-codemaps.py` regenerates `codemap.md` files via Claude API post-commit
- **OAuth + keychain**: `auto-update-codemaps.py` retrieves API tokens from macOS keychain (`Claude Code-credentials`), falls back to `ANTHROPIC_API_KEY`

## Flow

1. **PreToolUse hooks** (block-*.sh, auto-compress-output.sh): Intercept bash/git commands, inspect via jq, return decision JSON (block exit 2, modify, or pass through exit 0)
2. **PostToolUse hooks** (auto-update-codemaps.sh, enforce-tdd.sh): Trigger after Write/Edit/Bash, update docs or remind on TDD violations
3. **SessionStart/SessionStop**: `ensure-cartography.sh` checks mapping staleness; `auto-dream.sh` runs background consolidation after N sessions AND N hours
4. **Silent observation**: `auto-observe.sh` parses session logs, updates `~/.claude/knowledge/patterns.db` with tool usage stats
5. **Background compression**: `auto-compress-output.sh` intercepts high-output commands (git log, tests, grep -r), summarizes via haiku if >25 lines, returns compressed summary

## Integration

- **Git hooks environment**: Reads `HEAD` commit via `git diff-tree` to determine changed dirs; validates branch names against `$LEAN_FLOW_PROTECTED_BRANCHES`
- **Memory system**: `auto-dream.sh` invokes Claude on `auto-dream-prompt.md` to consolidate `~/.claude/projects/*/memory/`; `auto-observe.sh` writes to `~/.claude/knowledge/patterns.db`
- **Cartographer**: `ensure-cartography.sh` detects stale Tier 1 (`docs/CODEBASE_MAP.md`) and Tier 2 (per-folder `codemap.md`) mappings; `cartographer.py` maintains `.slim/` state directory
- **Claude monitor** (`claude-monitor/`): `ensure-claude-monitor.sh` installs SwiftBar plugin + launchd agent for usage tracking; detects `claude` binary across nodenv/nvm/n install methods
- **Config inheritance**: All scripts check `$CLAUDE_PLUGIN_ROOT` and source shared config; hooks emit structured JSON for Claude plugin to
