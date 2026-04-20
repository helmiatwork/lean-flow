# plugin/scripts/

## Responsibility
Automation hooks and utilities that enhance the Claude CLI environment without explicit user invocation. Scripts intercept tool calls (PreToolUse/PostToolUse), enforce policies, consolidate memory, detect code changes, monitor token usage, and auto-update documentation. Run via Claude plugin system on SessionStart/SessionStop or as git hooks.

## Design
**Hook-based architecture**: Scripts act as pluggable filters on tool execution (block, compress, inject context, or pass-through). **Config-driven gating**: `auto-dream.sh` and `block-protected-push.sh` load `LEAN_FLOW_*` settings from config to avoid hardcoding policy. **Token-aware**: `auto-compress-output.sh` detects high-output commands, runs them directly, and calls haiku to summarize rather than streaming megabytes. **Async background tasks**: `auto-dream.sh` and `auto-observe.sh` fork to background with timeouts to prevent session hangs. **Cartography state machine**: `cartographer.py` hashes files to detect changes; `auto-update-codemaps.py` leverages git diff-tree to trigger codemap generation only on modified directories.

## Flow
1. **SessionStart** → `ensure-cartography.sh`, `ensure-claude-monitor.sh` check preconditions (git repo, Python, SwiftBar) and emit system messages if updates needed.
2. **PreToolUse** (on every tool call) → `auto-compress-output.sh` intercepts high-output commands (git log, test suites, recursive grep), runs them directly, compresses via haiku if >25 lines, returns summary. Other PreToolUse blocks (secrets, identity, protected branches, wrong dirs) check command patterns and reject or ask.
3. **PostToolUse** (on Write/Edit) → `enforce-tdd.sh` detects implementation files without tests and injects reminder. `auto-update-codemaps.py` (via shell wrapper) runs post-commit to update codemap.md sections in changed directories.
4. **SessionStop** → `auto-dream.sh` (dual-gated by session count + hours) consolidates memory by running `auto-dream-prompt.md` task with haiku model in background.
5. **Background** → `auto-observe.sh` silently parses session logs and writes patterns to `~/.claude/knowledge/patterns.db` for future context retrieval.

## Integration
- **Plugin system**: Invoked via `~/.claude/plugins/plugin.json` hook declarations (SessionStart, SessionStop, PreToolUse, PostToolUse).
- **Config**: Reads `load-config.sh` for `LEAN_FLOW_*` settings (protected branches, dream gates, monitor enable).
- **Cartographer state**: Consults `.slim/cartography.json` (populated by `cartographer.py init`) to track file hashes and detect changes.
- **Memory system**: `auto-dream.sh` updates `~/.claude/projects/*/memory/MEMORY.md` and patterns.db; `auto-observe.sh` appends session observations to patterns.db.
- **Git hooks**: Scripts validate commits, pushes, and staged files; `auto-update-codemaps.py` triggers on HEAD commit.
- **macOS monitoring**: `ensure-claude-monitor.sh` installs SwiftBar plugin + launchd agent from `claude-monitor/` subdirectory.
