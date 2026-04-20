# plugin/scripts/

## Responsibility
The `plugin/scripts/` directory provides automation hooks and utilities for the Claude lean-flow plugin system. It intercepts tool use events (PreToolUse/PostToolUse), enforces project policies (protected branches, TDD, no secrets), maintains memory/patterns via consolidation, and auto-generates documentation (codemaps). These scripts run silently in the background—zero cost on small operations, compressed output on large ones, policy blocks where needed.

## Design
**Hook-based architecture**: Each script targets a specific event (`PreToolUse`, `PostToolUse`, `SessionStart`, `SessionStop`) and returns early if conditions don't match. Scripts use `jq` to parse/emit JSON formatted responses (`{"decision":"block","reason":"..."}` or `{"hookSpecificOutput":...}`). **Token-aware compression** (`auto-compress-output.sh`): intercepts high-output commands (git log, test suites, find), executes them directly, compresses via Haiku if >25 lines. **Dual-gated consolidation** (`auto-dream.sh`): memory cleanup runs only after N sessions AND N hours elapsed, preventing thrash. **Pattern observation** (`auto-observe.sh`): passively extracts session metadata (tools used, duration, branch) to patterns.db without API calls.

## Flow
1. **Event entry**: PostToolUse/PreToolUse/SessionStart hooks invoke relevant scripts via plugin manifest
2. **Early exit guards**: Each script checks conditions (file extension, command pattern, repo state) and exits 0 if inapplicable
3. **Policy enforcement**: `block-*.sh` scripts check command strings against rules (no `--no-verify`, no protected branch pushes, no `.env` staging), return exit code 2 to block
4. **Auto-updates**: `auto-update-codemaps.py` reads git diff-tree after commits, selects affected dirs, calls Claude API to fill codemap.md sections
5. **Background tasks**: `auto-dream.sh` spawns consolidation in background with lock/timeout to prevent concurrent runs; `auto-observe.sh` reads session log, updates patterns.db silently
6. **Cartography tiers**: `ensure-cartography.sh` checks Tier 1 (CODEBASE_MAP.md staleness via git log) and Tier 2 (.slim/cartography.json changes via `cartographer.py`)

## Integration
- **Config**: Scripts source `load-config.sh` for `LEAN_FLOW_*` settings (protected branches, dream thresholds, monitor enable flag)
- **APIs**: `auto-update-codemaps.py` calls Anthropic API (via OAuth keychain or env var); `auto-compress-output.sh` calls Haiku via Claude CLI
- **Git hooks**: Scripts integrate as PostToolUse/PreToolUse handlers; read git state (diff-tree, rev-parse, branch) to detect changes
- **Storage**: Memory consolidation (`auto-dream.sh`) operates on `~/.claude/projects/*/memory/MEMORY.md`; patterns DB at `~/.claude/knowledge/patterns.db`; cartography state at `.slim/cartography.json`
- **SwiftBar monitor** (`ensure-claude-monitor.sh`, `claude-monitor/` subdir): macOS-only setup for usage metrics display via launchd daemon
