# plugin/scripts/

## Responsibility
`plugin/scripts/` contains lean-flow automation hooks and utilities:
- **Pre/PostToolUse hooks**: intercept Claude tool calls to compress output, block dangerous operations, enforce TDD, update documentation
- **Session lifecycle**: memory consolidation (`auto-dream`), usage monitoring (`ensure-claude-monitor`), cartography checks
- **Git protection**: block commits with Claude identity, secrets, protected branch pushes, and --no-verify flags
- **Repository mapping**: `cartographer.py` tracks directory structure changes and manages per-folder `codemap.md` files

## Design
- **Hook pattern**: bash scripts read stdin JSON, emit decisions or structured output; Python for complex logic (OAuth, API calls, file parsing)
- **Dual-gating**: `auto-dream.sh` runs only after N sessions AND N hours to avoid redundant consolidation
- **Pattern matching**: `cartographer.py` uses pre-compiled regex for efficient glob matching against include/exclude/gitignore patterns
- **Fallback chains**: `ensure-claude-monitor.sh` detects Claude binary across nodenv/nvm/n installations; OAuth fetches from macOS keychain, falls back to env var
- **Zero-cost filters**: `auto-compress-output.sh` exits early for small output; TDD enforcement skips test/config files; cartography checks `.slim/cartography.json` before running expensive operations

## Flow
1. **SessionStart** → `ensure-cartography.sh`, `ensure-claude-monitor.sh` emit status messages
2. **PreToolUse** → `auto-compress-output.sh` intercepts high-output commands (git log, tests), runs them directly, summarizes via haiku if >25 lines; protection hooks (`block-*.sh`) veto dangerous git operations
3. **PostToolUse** → `auto-update-codemaps.py` reads git diff-tree, fetches changed directories, calls Claude API to generate codemap sections
4. **SessionStop** → `auto-dream.sh` runs memory consolidation via `auto-dream-prompt.md` after dual gates pass; `auto-observe.sh` silently captures session patterns to `~/.claude/knowledge/patterns.db`
5. **Background**: cartographer tracks file hashes in `.slim/cartography.json`; monitor publishes usage metrics to SwiftBar every 30s

## Integration
- **Hooks config**: load-config.sh injects LEAN_FLOW_* environment variables (DREAM_SESSIONS, DREAM_HOURS, PROTECTED_BRANCHES, MONITOR_ENABLED)
- **Claude API**: `auto-update-codemaps.py` uses oauth token (keychain → env var fallback) to call Claude API for codemap generation
- **Git integration**: reads commit metadata, diffs, branch state; blocks operations via exit code 2
- **Monitor subprocess**: `claude-monitor/` fetcher runs as launchd agent, publishes to SwiftBar plugin; referenced by `ensure-claude-monitor.sh`
- **Knowledge DB**: `auto-observe.sh` writes session observations to sqlite at `~/.claude/knowledge/patterns.db`; `cartographer.py` reads/manages `.slim/` state directory
