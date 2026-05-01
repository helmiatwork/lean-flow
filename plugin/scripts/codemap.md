# plugin/scripts/

## Responsibility
`plugin/scripts/` contains hooks and automation for the lean-flow plugin system. Scripts intercept Claude's tool calls (PreToolUse/PostToolUse), enforce project policies (blocked branches, secret files, TDD), maintain memory (auto-dream consolidation), and update documentation (codemaps). They run as git hooks, session events, and daemon tasks with zero output cost when not needed.

## Design
Scripts follow a gated/layered pattern: early exits for non-matching conditions, then decision logic, then side effects. Three categories: (1) **Blockers** (`block-*.sh`) — validate commands, exit 2 to deny; (2) **Automators** (`auto-*.sh`, `auto-*.py`) — update docs, compress output, consolidate memory on idle gates; (3) **Checkers** (`ensure-*.sh`, `cartographer.py`) — detect stale maps, prompt on SessionStart. Heavy lifting (codemap updates, pattern DB, session observation) delegates to Python with timeouts and fallbacks. Config loaded from `load-config.sh` (dual-gate sessions, protected branch names, monitor enable flag).

## Flow
- **PreToolUse**: `block-*.sh` reject dangerous commands (no-verify, protected branch push, secrets); `auto-compress-output.sh` intercepts high-output commands, runs them, compresses via haiku if >25 lines, returns jq exit 2.
- **PostToolUse**: `enforce-tdd.sh` checks if test exists for written code, injects reminder; `auto-update-codemaps.py` reads changed dirs from git diff-tree, generates section descriptions via Claude API.
- **SessionStart**: `ensure-cartography.sh` compares Tier 1 (docs/CODEBASE_MAP.md commit count) and Tier 2 (.slim/cartography.json folder changes), emits prompt if stale; `ensure-claude-monitor.sh` installs macOS SwiftBar + launchd daemon for usage tracking.
- **SessionStop**: `auto-dream.sh` dual-gates on session count + elapsed time, triggers `auto-dream-prompt.md` consolidation (prune memory, decay pattern scores) in background.
- **Silent background**: `auto-observe.sh` reads session log, extracts tool counts + key commands, writes observation to patterns.db (no API call).

## Integration
- Reads/writes: git (diff-tree, log, branch, rev-parse), filesystem (codemap.md, .slim/cartography.json, ~/.claude/projects/*, ~/.claude/knowledge/patterns.db), macOS keychain (ANTHROPIC_API_KEY fallback).
- Calls Claude API via `auto-update-codemaps.py` (oauth token detection) and `auto-dream.sh` (haiku model for consolidation).
- Depends on `cartographer.py` (pattern matching, file hashing for change detection) and `claude-monitor/` subdirectory (SwiftBar plugin + fetcher daemon).
- Triggered by: git hooks (pre-commit, post-commit, pre-push), env var `CLAUDE_PLUGIN_ROOT`, jq for JSON parsing, `load-config.sh` for user settings.
