# plugin/scripts/

# plugin/scripts Codemap

## Responsibility
Provides session hooks (PreToolUse, PostToolUse, SessionStart, Stop) to enforce development workflows, optimize Claude's API usage, and maintain repository cartography. Gate unsafe operations (protected branch pushes, secret staging), compress large outputs, auto-consolidate memory, and trigger test-driven development patterns.

## Design
- **Hook-based architecture**: Each `.sh` script is a single PreToolUse/PostToolUse/SessionStart handler that reads JSON stdin, makes a decision, outputs JSON or exits with code 2 (block)
- **Config-driven gates**: `auto-dream.sh`, `block-protected-push.sh` load `load-config.sh` for session thresholds, branch names, monitor flags
- **Dual-layer cartography**: Tier 1 = `docs/CODEBASE_MAP.md` via git log; Tier 2 = per-directory `codemap.md` via `cartographer.py` (state in `.slim/`)
- **Token-efficient consolidation**: `auto-dream.sh` runs memory cleanup task (`auto-dream-prompt.md`) on dual gates (N sessions + M hours), uses Haiku model, locks via `~/.claude/dream-state/`
- **Silent observation**: `auto-observe.sh` logs session patterns to `~/.claude/knowledge/patterns.db` on Stop (zero API cost)

## Flow
1. **PreToolUse**: `auto-compress-output.sh` (intercept high-output commands), `block-*.sh` scripts (reject unsafe git/npm ops)
2. **PostToolUse**: `auto-update-codemaps.py` (update codemaps after commit), `enforce-tdd.sh` (remind user to write tests)
3. **SessionStart**: `ensure-cartography.sh` (check Tier 1/2 staleness), `ensure-claude-monitor.sh` (install SwiftBar monitor on macOS)
4. **Stop**: `auto-dream.sh` (conditionally trigger memory consolidation), `auto-observe.sh` (append session patterns to DB)
5. **Cartographer**: `cartographer.py init` (hash source files), `changes` (show affected dirs), `update` (refresh hashes after edits)

## Integration
- **Config**: Reads from `load-config.sh` (sets `LEAN_FLOW_PROTECTED_BRANCHES`, `LEAN_FLOW_DREAM_SESSIONS`, `LEAN_FLOW_DREAM_HOURS`, `LEAN_FLOW_ENABLE_MONITOR`)
- **Memory system**: `auto-dream.sh` → `auto-dream-prompt.md` → Claude consolidates `~/.claude/projects/*/memory/`
- **Monitor UI**: `ensure-claude-monitor.sh` installs `claude-monitor/` (SwiftBar plugin) + launchd plist
- **API optimization**: `auto-compress-output.sh` uses Haiku for summaries (saves tokens on large test/log outputs)
- **Git hooks**: Scripts block commits to protected branches, secrets, wrong-plan dirs; called by `.git/hooks/` or intercept via PreToolUse JSON
