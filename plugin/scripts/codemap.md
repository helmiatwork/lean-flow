# plugin/scripts/

## Responsibility

`plugin/scripts/` provides lifecycle hooks and automation for the Claude Code lean-flow plugin system. It includes:
- **PreToolUse/PostToolUse hooks** for intercepting, blocking, or modifying tool execution (compression, secrets, protected branches, identity markers)
- **Session lifecycle scripts** that run on Start/Stop to manage cartography, memory consolidation, and monitoring
- **Cartography tools** for repository mapping and change detection
- **Configuration loading** via shared load-config.sh pattern

## Design

**Hook-based interception**: Scripts read JSON from stdin (hook payload), make yes/no/block decisions, and emit structured JSON responses. Each hook is independent and composable—multiple hooks can chain without orchestration.

**Dual-gated execution**: Session-based features (auto-dream, auto-observe) use both session count AND elapsed time gates to prevent thrashing; locks prevent concurrent runs.

**Tool detection & fallback**: Scripts detect available binaries (uv, python3, jq, claude) at runtime and degrade gracefully rather than fail. OAuth tokens fetched from macOS keychain, fallback to env vars.

**File-level codemaps**: `cartographer.py` and `auto-update-codemaps.py` maintain per-directory `codemap.md` files indexed by git diff; changes trigger async Claude API calls to fill sections.

## Flow

1. **Session Start** → `ensure-cartography.sh` checks Tier 1 (CODEBASE_MAP.md) and Tier 2 (.slim/cartography.json); `ensure-claude-monitor.sh` installs SwiftBar plugin
2. **Tool execution** → PreToolUse hooks (`block-*.sh`, `auto-compress-output.sh`) intercept; PostToolUse hooks (`enforce-tdd.sh`, `auto-update-codemaps.sh`) run after
3. **Large output** → `auto-compress-output.sh` routes through Haiku summarization; small output passes through
4. **Session Stop** → `auto-observe.sh` logs session activity; `auto-dream.sh` (if gates pass) runs memory consolidation prompt
5. **Repository changes** → `auto-update-codemaps.py` reads git diff-tree, identifies changed dirs, calls Claude API to update `codemap.md` sections

## Integration

- **claude-monitor/** subdirectory: SwiftBar plugin + launchd fetcher for real-time API usage display
- **Config loading**: All session/memory scripts source `load-config.sh` for LEAN_FLOW_* vars (protected branches, dream gates, monitor toggle)
- **API calls**: Keychain detection in `ensure-claude-monitor.sh` and `auto-update-codemaps.py`; model selection (Haiku for compression, default Claude for codemaps)
- **Git integration**: All scripts check `git rev-parse` for repo context; `cartographer.py` reads .gitignore; hooks inspect `git log`, `git diff-tree`, branch names
- **Session events**: Hooks receive JSON with `session_id`, `cwd`, `tool`, `tool_input`, hook event name for context-aware decisions
