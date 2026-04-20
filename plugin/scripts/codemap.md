# plugin/scripts/

## Responsibility
Automation hooks and utilities that enforce code quality, update documentation, manage session state, and monitor API usage. Runs before/after tool execution and on session boundaries to maintain codebase health without user intervention.

## Design
**Hook-based architecture**: Scripts integrate via PreToolUse (block/intercept), PostToolUse (trigger), and SessionStart/Stop lifecycle hooks. Each script is a small, focused enforcer with minimal dependencies (bash + jq for speed).

**Tiered blocking**: `block-*.sh` files use regex matching on git commands to prevent unsafe patterns (direct pushes to protected branches, secret file staging, identity markers). Non-blocking hooks (`auto-*.sh`) either exit silently or emit JSON directives.

**Background consolidation**: `auto-dream.sh` uses dual-gate logic (session count + time elapsed) to trigger memory consolidation asynchronously, preventing session hangs.

**Documentation automation**: `cartographer.py` tracks file hashes and diffs to identify changed directories; `auto-update-codemaps.py` calls Claude API to fill in `codemap.md` sections per changed directory after commits.

## Flow
1. **PreToolUse** (before execution): `block-*.sh` intercept dangerous commands and return exit code 2 to deny; `auto-compress-output.sh` checks command type, pre-executes read-heavy commands, compresses large output via Haiku.
2. **PostToolUse** (after execution): `auto-update-codemaps.py` runs after `git commit`, reads changed dirs from `git diff-tree`, calls Claude to auto-fill `codemap.md` sections; `enforce-tdd.sh` reminds on implementation writes without tests.
3. **SessionStart**: `ensure-cartography.sh` and `ensure-claude-monitor.sh` check for initialized state (`.slim/cartography.json`, SwiftBar plugin), emit warnings if missing or stale.
4. **SessionStop**: `auto-observe.sh` silently logs session activity to `patterns.db`; `auto-dream.sh` triggers background consolidation if gates pass (waits for next session).

## Integration
- **Git hooks**: `block-*.sh` and `auto-update-codemaps.sh` integrate via git post-receive or pre-commit patterns; `cartographer.py` reads `.git/` and `.gitignore` to track repo state.
- **Claude API**: `auto-update-codemaps.py` fetches OAuth token from macOS keychain or `ANTHROPIC_API_KEY` env var; `auto-dream.sh` calls Claude Haiku to consolidate memory.
- **macOS SwiftBar/launchd**: `ensure-claude-monitor.sh` installs `claude-usage.3m.sh` plugin and `claude-usage-fetch.sh` background fetcher to track API usage in menu bar.
- **Config**: `load-config.sh` (sourced by multiple scripts) sets `LEAN_FLOW_PROTECTED_BRANCHES`, `LEAN_FLOW_DREAM_SESSIONS`, `LEAN_FLOW_DREAM_HOURS`, `LEAN_FLOW_ENABLE_MONITOR`.
- **Session logging**: `/tmp/claude-sessions/{SESSION_ID}.log` fed to `auto-observe.sh` for pattern extraction; `claude-monitor/` subdir contains fetcher and display plugins.
