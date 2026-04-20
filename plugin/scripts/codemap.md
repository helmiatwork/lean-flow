# plugin/scripts/

## Responsibility
`plugin/scripts/` implements the lean-flow plugin system — a collection of git hooks, session lifecycle handlers, and background agents that enforce TDD, manage memory consolidation, auto-update documentation, and monitor API usage. All scripts are designed to be zero-cost when inactive (early exit) and operate silently in the background.

## Design
- **Hook-based execution**: Scripts use `PreToolUse` and `PostToolUse` hooks (jq-parsed JSON input) to intercept git commands, file writes, and tool invocations. Each block/enforce script exits early (0) if conditions don't match.
- **Dual-gated background tasks**: `auto-dream.sh` and `auto-observe.sh` use lock files and timestamp gates to prevent concurrent runs and only activate after N sessions or N hours.
- **Cartographer state machine**: `cartographer.py` maintains `.slim/cartography.json` to track file hashes and changed directories; `auto-update-codemaps.py` uses git diff-tree to detect affected directories and regenerates codemap.md via Claude API with OAuth keychain fallback.
- **Config inheritance**: Scripts source `load-config.sh` for centralized settings (`LEAN_FLOW_PROTECTED_BRANCHES`, `LEAN_FLOW_DREAM_SESSIONS`, etc.).
- **Portable shell**: Uses POSIX bash with platform-aware stat (`Darwin` vs Linux), jq for JSON, and Python 3 as fallback logic engine.

## Flow
1. **Session Start** → `ensure-cartography.sh` checks Tier 1 (docs/CODEBASE_MAP.md age) and Tier 2 (cartographer changes); `ensure-claude-monitor.sh` installs SwiftBar plugin + launchd agent (macOS).
2. **Tool Use** → Block scripts (`block-*.sh`) intercept git/gh commands; `auto-compress-output.sh` catches high-output commands and summarizes via Haiku model.
3. **Post Write/Edit** → `enforce-tdd.sh` detects new code files and prompts for test coverage; `auto-update-codemaps.py` regenerates codemap.md for changed directories via Claude API.
4. **Session Stop** → `auto-observe.sh` silently logs session patterns to patterns.db; `auto-dream.sh` consolidates memory files and prunes pattern DB after dual gates (session count + time elapsed).
5. **Background** → `claude-monitor/` fetcher runs via launchd, posting usage stats to SwiftBar menu.

## Integration
- **Git hooks**: Scripts hook into lean-flow plugin framework; block rules gate commits to protected branches, secrets, and identity markers.
- **Claude API**: `auto-update-codemaps.py` and `auto-compress-output.sh` call Claude (Opus for codemaps, Haiku for compression) with OAuth tokens from macOS keychain.
- **Project state**: Reads/writes `.slim/cartography.json` (cartographer state), `~/.claude/dream-state/` (memory consolidation locks), `~/.claude/knowledge/patterns.db` (session observations).
- **Config**: All scripts respect `CLAUDE_PLUGIN_ROOT` env var and load centralized config from `load-config.sh` (not shown but sourced by multiple hooks).
