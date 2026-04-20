# plugin/scripts/

## Responsibility

The `plugin/scripts/` directory implements lean-flow's hook system and automation framework. It provides pre/post-tool interceptors (blockers, compressors, auto-updaters), session lifecycle hooks (cartography initialization, memory consolidation, usage monitoring), and repository mapping tools. These scripts enforce development patterns (TDD, git hygiene, secret protection) while transparently optimizing Claude's token usage and maintaining codebase documentation.

## Design

**Hook-based interceptors**: Bash scripts wrapping `jq` to parse tool inputs and emit structured decisions (`{"decision":"block"|"allow"|"ask"}`) or output augmentations. Each hook is single-responsibility (e.g., `block-protected-push.sh` only checks branch names; `auto-compress-output.sh` only triggers on high-output commands).

**Dual-gated automation** (`auto-dream.sh`, `ensure-cartography.sh`): SessionStart/Stop hooks use state files (`~/.claude/dream-state/`, `.slim/`) to prevent spam via session counts + time gates. Cartographer uses incremental hashing (`cartography.json`) to detect changes, avoiding full-repo scans.

**Config inheritance**: Scripts source `load-config.sh` for environment variables (e.g., `LEAN_FLOW_PROTECTED_BRANCHES`, `LEAN_FLOW_DREAM_SESSIONS`), enabling centralized policy without editing individual hooks.

**Token-aware compression**: `auto-compress-output.sh` identifies high-output commands (git log, test suites) and either truncates output or calls Claude Haiku to summarize before returning to the main model—zero cost for small output, asymptotically cheaper for large output.

## Flow

1. **PreToolUse hooks** (block-*.sh, auto-compress-output.sh): Intercept tool calls, read `tool_input`, decide block/allow/ask, emit JSON response or exit 0 to pass through.
2. **PostToolUse hooks** (auto-update-codemaps.sh, enforce-tdd.sh): Fire after tool execution; read changed files/output, optionally inject reminders or trigger updates.
3. **SessionStart** (ensure-cartography.sh, ensure-claude-monitor.sh): Check codebase state (git commits since last map, SwiftBar installation), emit status messages.
4. **SessionStop** (auto-dream.sh, auto-observe.sh): Consolidate memory (calls Claude Haiku via `--print` on `auto-dream-prompt.md`) and capture session patterns into SQLite DB.
5. **Git hooks** (via PostToolUse auto-update-codemaps.py): On commit, detect changed directories, read file contents, call Claude API to fill/refresh codemap.md sections.

## Integration

- **Config**: Sources `CLAUDE_PLUGIN_ROOT` and hook-specific env vars (e.g., `LEAN_FLOW_PROTECTED_BRANCHES` from load-config.sh).
- **Memory system**: `auto-dream.sh` reads/writes `~/.claude/projects/memory/`, `auto-observe.sh` populates `~/.claude/knowledge/patterns.db`.
- **Cartography**: `ensure-cartography.sh` triggers `cartographer.py` to sync `.slim/cartography.json`; `auto-update-codemaps.py` reads cartographer state and updates per-folder `codemap.md` files.
-
