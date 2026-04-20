# plugin/scripts/

## Responsibility
Plugin scripts directory contains lifecycle hooks, blocking rules, and automation tasks that intercept Claude tool use, enforce constraints, and consolidate memory/codemaps. Each script is a modular gate: some block unsafe operations (git/secrets), others compress output or trigger async updates.

## Design
Hook-based architecture: scripts are invoked at specific event points (PreToolUse, PostToolUse, SessionStart/Stop) via stdin JSON. Return codes and jq output control decision flow (block=2, ask=0, pass=exit 0). No central dispatcher — each hook is independent and idempotent. Configuration via `load-config.sh` for feature gates (protected branches, dream sessions, monitor toggle).

## Flow
**PreToolUse** (command interception): `auto-compress-output.sh` intercepts high-output commands, runs them directly, compresses large output via haiku, returns summary. `block-*.sh` scripts inspect command strings and reject unsafe patterns (--no-verify, protected branch pushes, .env staging, Claude identity markers).

**PostToolUse** (after writes): `auto-update-codemaps.py` detects changed directories from git diff-tree, reads file contents, calls Claude API to auto-generate codemap.md sections. `enforce-tdd.sh` detects implementation files without tests and injects TDD reminders.

**SessionStart**: `ensure-cartography.sh` checks Tier 1 (docs/CODEBASE_MAP.md commit drift) and Tier 2 (.slim/cartography.json folder changes) via `cartographer.py`. `ensure-claude-monitor.sh` installs SwiftBar usage monitor on macOS if enabled.

**SessionStop**: `auto-dream.sh` triggers dual-gated memory consolidation (N sessions AND N hours) using `auto-dream-prompt.md` with haiku model.

## Integration
- **Git hooks**: scripts read git state (diff-tree, branch, log) to detect changes and protect branches
- **Claude CLI**: `auto-dream.sh`, `auto-compress-output.sh`, `ensure-claude-monitor.sh` invoke claude binary for API calls or memory tasks
- **Knowledge DB**: `auto-observe.sh` and dream consolidation write to `~/.claude/knowledge/patterns.db`
- **Cartographer**: `cartographer.py` and `ensure-cartography.sh` manage `.slim/cartography.json` state and per-directory codemaps
- **Config**: all scripts source `load-config.sh` for environment variables (protected branches, dream gates, monitor toggle)
- **SwiftBar**: `claude-monitor/` subdirectory provides menubar plugin installer
