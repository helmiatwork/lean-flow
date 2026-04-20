# plugin/scripts/

## Responsibility

`plugin/scripts/` contains hook handlers and automation tools that run transparently during Claude sessions. Scripts intercept tool calls (PreToolUse/PostToolUse), enforce guardrails (block secrets, protected branches, identity markers), update documentation (codemaps), consolidate memory, and monitor usage. All are zero-cost when conditions aren't met.

## Design

**Hook-based architecture**: Each script is a standalone bash/Python filter that reads JSON from stdin, decides to pass through (exit 0), block (exit 2), or transform (jq output). Dual-gated patterns (e.g., `auto-dream.sh` requires both session count AND hours elapsed) prevent redundant work. Config loaded from `load-config.sh` for centralized tuning. Cartographer uses git-aware pattern matching and state files (`.slim/cartography.json`) to track repo structure deltas without re-scanning.

## Flow

1. **Session hooks** (`ensure-*.sh`): Fire on SessionStart, emit system messages if cartography stale or monitor not installed
2. **Tool interception** (`block-*.sh`, `auto-compress-output.sh`): Triggered PreToolUse/PostToolUse, inspect command, allow/deny/rewrite
3. **Consolidation** (`auto-dream.sh`): Runs on SessionStop when gates pass (N sessions + N hours), spawns background Claude haiku task to prune memory
4. **Documentation** (`auto-update-codemaps.py`): PostToolUse on git commit, diffs changed dirs, calls Claude API to fill codemap stubs
5. **Observation** (`auto-observe.sh`): Silent pattern capture to `~/.claude/knowledge/patterns.db` from session logs

## Integration

- **Config**: All scripts source `load-config.sh` for `LEAN_FLOW_*` variables (protected branches, dream intervals, etc.)
- **Memory system**: `auto-dream.sh` and `auto-observe.sh` read/write `~/.claude/projects/`, `~/.claude/knowledge/patterns.db`
- **Cartographer**: `ensure-cartography.sh` invokes `cartographer.py` to detect Tier 2 codemaps needing updates
- **Claude monitor** (macOS): `ensure-claude-monitor.sh` installs SwiftBar plugin + launchd agent to feed usage data
- **Git/toolchain**: Hooks depend on git state, bash, jq, optional Python3; gracefully degrade if unavailable
