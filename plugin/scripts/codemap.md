# plugin/scripts/

## Responsibility
The `plugin/scripts/` directory contains pre/post-tool-use hooks and session lifecycle scripts that enforce development practices, optimize Claude's resource usage, and maintain project documentation. Hooks intercept tool execution (bash commands, file writes) to block unsafe operations, compress large outputs, and enforce testing discipline. Session scripts consolidate memory, detect repo changes, and initialize monitoring.

## Design
- **Hook pattern**: Each script reads JSON stdin, applies a guard condition (exit 0 to pass-through, exit 2 to block), and emits JSON output via jq. Scripts are stateless and composable.
- **Gating mechanisms**: `auto-dream.sh` uses dual gates (session count + elapsed time) to prevent thrashing. `block-protected-push.sh` patterns branch names from config. `cartographer.py` uses pre-compiled regex for efficient path matching.
- **Token optimization**: `auto-compress-output.sh` intercepts high-output commands (git log, test runs, grep -r), runs them directly, compresses via Haiku if >25 lines. `auto-observe.sh` silently logs session patterns to SQLite without API calls.
- **Config-driven**: `load-config.sh` (sourced by multiple scripts) sets `LEAN_FLOW_*` variables for protected branches, dream thresholds, monitor enablement.

## Flow
1. **PreToolUse hooks** (auto-compress-output, block-*): intercept tool calls, decide block/compress/pass-through, return decision via JSON.
2. **PostToolUse hooks** (auto-update-codemaps, enforce-tdd): trigger after Write/Edit/Bash, analyze changed files, emit context or reminders.
3. **SessionStart hooks** (ensure-cartography, ensure-claude-monitor): check repo state and install monitoring on first run.
4. **SessionStop hooks** (auto-observe, auto-dream): capture activity to patterns DB, conditionally run memory consolidation (dual-gated by session count + hours elapsed).
5. **Git integration**: `auto-update-codemaps.py` reads `git diff-tree` to find changed dirs, calls Claude API to fill codemap.md sections; `cartographer.py` maintains `.slim/cartography.json` hash state for change detection.

## Integration
- **lean-flow config**: Sources `load-config.sh` for `LEAN_FLOW_PROTECTED_BRANCHES`, `LEAN_FLOW_DREAM_SESSIONS`, `LEAN_FLOW_DREAM_HOURS`, `LEAN_FLOW_ENABLE_MONITOR`.
- **Claude CLI**: Invokes `claude` binary for Haiku summarization (auto-compress-output), memory consolidation (auto-dream), and API calls (auto-update-codemaps.py).
- **Git repo**: Reads `.gitignore`, `git diff-tree`, `git log`, `git branch` to detect changes and enforce branch policies.
- **macOS keychain**: `auto-update-codemaps.py` fetches OAuth token from keychain; `ensure-claude-monitor.sh` installs SwiftBar plugin + launchd agents.
- **Monolithic memory**: `auto-dream-prompt.md` guides consolidation of `~/.claude/projects/*/memory/MEMORY.md` and `~/.claude/knowledge/patterns.db`.
