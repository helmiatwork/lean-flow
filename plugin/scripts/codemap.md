# plugin/scripts/

## Responsibility

`plugin/scripts/` contains PreToolUse/PostToolUse hooks and session lifecycle scripts that enforce workflow guardrails, auto-update documentation, compress output, and consolidate memory. These are the enforcement and automation layer of the lean-flow plugin system—blocking unsafe operations, injecting TDD discipline, and maintaining repository cartography without user intervention.

## Design

**Hook Pattern**: Each `block-*.sh` uses jq to inspect tool input and exit with code 2 (block) or 0 (pass); `auto-*.sh` use similar pattern but may emit `hookSpecificOutput` JSON to inject context or summaries.

**Cartography Dual-Tier**: `ensure-cartography.sh` orchestrates two levels—Tier 1 (`docs/CODEBASE_MAP.md`, git-log-based high-level atlas) and Tier 2 (per-folder `codemap.md` via `cartographer.py` file-hash tracking). `auto-update-codemaps.py` uses OAuth token from macOS keychain, falls back to env var, integrates Claude API to fill sections.

**Output Compression**: `auto-compress-output.sh` intercepts high-output commands (git log, test runs, grep -r) pre-execution, runs them directly, and uses haiku to summarize if >25 lines—zero cost for small output, transparent fallthrough.

**Memory Consolidation**: `auto-dream.sh` dual-gates on session count AND hours-elapsed, runs `auto-dream-prompt.md` in background via haiku, updates pattern database and memory files with aggressive pruning rules.

## Flow

1. **Session Start** → `ensure-cartography.sh` + `ensure-claude-monitor.sh` emit status messages (Tier 1/2 staleness, monitor install state)
2. **PreToolUse** → `block-*.sh` guards intercept commands; `auto-compress-output.sh` pre-executes high-output commands and summarizes
3. **PostToolUse** → `auto-update-codemaps.py` (triggered by git commit) reads `git diff-tree`, calls Claude to fill codemap sections; `enforce-tdd.sh` injects test reminders
4. **Session Stop** → `auto-observe.sh` logs session activity to patterns.db; `auto-dream.sh` (if dual-gate passes) consolidates memory in background
5. **Manual** → `cartographer.py` (standalone CLI) tracks file hashes, detects changes, initializes state in `.slim/cartography.json`

## Integration

- **Cartographer**: reads `.slim/cartography.json` state, outputs to per-folder `codemap.md`; `auto-update-codemaps.py` enhances via Claude API
- **Memory System**: `auto-dream.sh` targets `~/.claude/projects/*/memory/MEMORY.md` and `~/.claude/knowledge/patterns.db`
- **Monitor**: `ensure-claude-monitor.sh` installs SwiftBar plugin + launchd agent from `claude-monitor/` subdirectory
- **Config**: all scripts source `load-config.sh` for tunable gates (LEAN_FLOW_DREAM_SESSIONS, LEAN_FLOW_PROTECTED_BRANCHES, etc.)
- **CLI**: `claude` binary detected via PATH or common install paths (nodenv, nvm, homebrew); OAuth token via `security` key
