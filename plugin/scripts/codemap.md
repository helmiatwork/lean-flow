# plugin/scripts/

## Responsibility
Automation hooks and utilities that intercept Claude's tool use, enforce development practices, and maintain codebase documentation. Scripts run at key lifecycle events (PreToolUse, PostToolUse, SessionStart, SessionStop) to gate unsafe operations, consolidate memory, detect code changes, and auto-generate codemaps.

## Design
- **Hook architecture**: Each script processes JSON input from stdin, outputs JSON decisions (block/allow/ask). Portable across shells via jq for parsing.
- **Gate patterns**: Multi-stage gating (e.g., `auto-dream.sh` requires both N sessions *and* N hours elapsed). Lock files prevent concurrent execution.
- **Configuration via `load-config.sh`**: Centralized settings (protected branches, dream thresholds, monitor enable). Sourced by scripts that need runtime config.
- **Tier-based caching**: `cartographer.py` uses `.slim/cartography.json` state to track file hashes; `ensure-cartography.sh` reads it to detect changes without re-hashing.
- **Token-aware fallbacks**: `auto-compress-output.sh` uses haiku model if available, truncates if not. `ensure-claude-monitor.sh` detects claude binary across 5+ install methods.

## Flow
1. **PreToolUse hooks** (`block-*.sh`, `auto-compress-output.sh`): Intercept commands before execution. Block/allow based on regex or content rules. `auto-compress-output.sh` runs high-output commands directly, compresses via haiku if >25 lines.
2. **PostToolUse hooks** (`auto-update-codemaps.sh`/`.py`, `enforce-tdd.sh`): Fire after Write/Edit/Bash. `auto-update-codemaps.py` reads git diff-tree, calls Claude API to fill codemap sections. `enforce-tdd.sh` checks for test files, emits TDD reminders.
3. **SessionStart** (`ensure-cartography.sh`, `ensure-claude-monitor.sh`): Tier 1 checks docs/CODEBASE_MAP.md commit age; Tier 2 runs cartographer to detect changed directories. Monitor script idempotently installs SwiftBar plugin + launchd agent.
4. **SessionStop** (`auto-dream.sh`, `auto-observe.sh`): Dual-gated memory consolidation. `auto-observe.sh` silently logs session patterns to patterns.db. `auto-dream.sh` triggers memory cleanup after N sessions + N hours, runs haiku model in background with 5-min timeout.

## Integration
- **Config bridge**: `load-config.sh` (sourced by scripts needing runtime params like `LEAN_FLOW_PROTECTED_BRANCHES`, `LEAN_FLOW_DREAM_SESSIONS`).
- **Keychain/env fallback**: `auto-update-codemaps.py` tries macOS keychain (`Claude Code-credentials`), falls back to `ANTHROPIC_API_KEY` env var.
- **Git integration**: Scripts detect repo state via `git rev-parse`, read diffs via `git diff-tree`, use branch names. Cartographer maintains `.slim/` state directory.
- **Claude monitor ecosystem**: `ensure-claude-monitor.sh` installs SwiftBar plugin from `claude-monitor/` subdirectory, creates launchd agent for periodic token fetch.
- **Memory system**: `auto-
