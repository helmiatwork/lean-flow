# plugin/scripts/

## Responsibility
Hooks, automation, and utility scripts that enforce code quality, capture activity, consolidate memory, and maintain documentation. These run as PreToolUse/PostToolUse lifecycle hooks and SessionStart checks — providing guardrails, compression, and continuous mapping without blocking user workflows.

## Design
**Hook-based enforcement**: `block-*.sh` scripts validate git commands (no protected branch pushes, no secrets, no identity markers) and fail fast with exit code 2. **Async consolidation**: `auto-dream.sh` runs memory pruning on dual gates (session count + hours elapsed) to avoid token bloat. **Transparent optimization**: `auto-compress-output.sh` intercepts high-output commands (git log, tests, grep -r), runs them directly, compresses via haiku if >25 lines, returns summary—small output passes through untouched. **Continuous mapping**: `cartographer.py` diffs directory hashes against `.slim/cartography.json`, generates per-folder `codemap.md` sections via Claude API; `auto-update-codemaps.py` runs PostToolUse after commits. **Monitoring/MCP**: `ensure-*.sh` scripts idempotently install SwiftBar plugins and knowledge MCP server with launchd agents.

## Flow
1. **PreToolUse** (command validation): `block-*.sh` rules reject dangerous operations; `auto-compress-output.sh` intercepts read-heavy commands, compresses, returns exit 2 to skip normal execution.
2. **PostToolUse** (post-commit): `auto-update-codemaps.py` reads git diff-tree, identifies changed dirs, calls Claude to fill codemap sections.
3. **SessionStart**: `ensure-cartography.sh` / `ensure-claude-monitor.sh` / `ensure-knowledge-mcp.sh` check for initialization gaps; `cartographer.py changes` detects stale codemaps.
4. **SessionStop**: `auto-dream.sh` runs if session count ≥ threshold AND hours since last dream ≥ threshold, triggers haiku consolidation in background (timeout 300s).
5. **Background**: `auto-observe.sh` captures tool usage from session logs, writes patterns to `~/.claude/knowledge/patterns.db`.

## Integration
- **Config**: All scripts source `load-config.sh` for `LEAN_FLOW_*` vars (protected branches, dream gates, monitor enable).
- **Git hooks**: Called by Claude CLI as PreToolUse/PostToolUse; can exit 2 to block or skip, or emit JSON systemMessage.
- **APIs**: `auto-update-codemaps.py` / `cartographer.py` call Claude API (OAuth from keychain or `ANTHROPIC_API_KEY`); `auto-compress-output.sh` uses `claude` CLI.
- **State**: `.slim/cartography.json` (hash tracking), `~/.claude/dream-state/` (last-dream, session-count), `~/.claude/knowledge/patterns.db` (pattern DB), `/tmp/claude-sessions/` (activity logs).
- **macOS-specific**: `ensure-claude-monitor.sh` installs SwiftBar plugin + launchd agent; `auto-update-codemaps.py` reads OAuth from keychain fallback.
