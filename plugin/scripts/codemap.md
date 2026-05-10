# plugin/scripts/

## Responsibility
Automation hooks and utilities that intercept Claude's tool use to enforce project rules, optimize tokens, and maintain documentation. Covers git safety (blocks unsafe commits/pushes), output compression, memory consolidation, codemap updates, and repository change tracking.

## Design
**Hook-based architecture**: Bash/Python scripts run as PreToolUse/PostToolUse handlers, intercepting commands before execution. **Guard pattern**: `bash-guard.sh` unifies all checks with opt-out env vars (`LEAN_FLOW_*_DISABLED`); individual `block-*.sh` scripts isolate concerns (branch delete, secrets, identity). **State management**: `auto-dream.sh` uses dual gates (session count + time elapsed) to trigger memory consolidation; `cartographer.py` tracks file hashes to detect changes; `auto-observe.sh` logs session events to SQLite pattern database.

## Flow
**PreToolUse** → `bash-guard.sh` / `block-*.sh` reject unsafe git/gh commands (--no-verify, protected branches, secrets, Claude identity, PR comments) or `auto-compress-output.sh` intercepts high-output commands, runs them directly, compresses via Haiku if >25 lines. **PostToolUse** → `auto-update-codemaps.py` reads changed directories from `git diff-tree`, generates/updates `codemap.md` via Claude API. **Background**: `auto-dream.sh` (on session stop) triggers memory consolidation prompt; `auto-observe.sh` silently logs tool usage patterns. **Cartographer**: `init` creates file hashes, `changes` shows diffs, `update` commits state.

## Integration
Hooked into Claude CLI via `~/.claude/plugins/` (CLAUDE_PLUGIN_ROOT). Reads git state via `git diff-tree`, `git branch`. Uses `ANTHROPIC_API_KEY` or macOS keychain for API calls. Writes to `~/.claude/dream-state/`, `~/.claude/knowledge/patterns.db`, `.slim/cartography.json`. Config loaded from `load-config.sh` (sets LEAN_FLOW_* env vars). Depends on `jq` for JSON parsing, `python3` for heavy lifting. Codemaps integrated with repo structure (one per directory); project-doctor/ subdirectory handles post-commit diagnostics.
