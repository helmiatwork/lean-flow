# plugin/scripts/

## Responsibility

Plugin scripts directory contains hook handlers and automation tools that integrate with the Claude CLI and lean-flow system. Scripts intercept tool execution (PreToolUse/PostToolUse), enforce development practices (TDD, git safety), maintain repository mappings, consolidate memory, and monitor API usage. These are the "guard rails" and "background workers" of the lean-flow environment.

## Design

**Hook-based architecture**: Scripts are invoked by hook events (SessionStart, PreToolUse, PostToolUse, SessionStop) and communicate via JSON stdin/stdout. Each script is single-purpose and idempotent.

**Gate patterns**: `auto-dream.sh` and `block-protected-push.sh` use dual gates (session count + time elapsed, or branch name + push target) to prevent tool spam.

**Pattern matching**: `cartographer.py` and `PatternMatcher` class use pre-compiled regex for efficient glob-to-path matching against gitignore and custom include/exclude patterns.

**Lazy initialization**: Scripts like `ensure-cartography.sh` and `ensure-claude-monitor.sh` check preconditions and silently skip if unmet (no Python, no repo, disabled in config).

## Flow

1. **Session lifecycle**: SessionStart runs `ensure-cartography.sh`, `ensure-claude-monitor.sh`. SessionStop triggers `auto-dream.sh` (if dual gates pass) and `auto-observe.sh` (captures session patterns).

2. **Pre-tool blocking**: `block-*.sh` scripts inspect `jq -r '.tool_input.command'`, reject unsafe ops (--no-verify, secrets, protected branches), return JSON decision.

3. **Post-tool capture & update**: `auto-compress-output.sh` intercepts high-output commands, summarizes via haiku. `auto-update-codemaps.py` reads git diff-tree, scans changed directories, calls Claude API to fill codemap.md sections. `enforce-tdd.sh` reminds to write tests.

4. **Background memory consolidation**: `auto-dream.sh` runs `auto-dream-prompt.md` via Claude Haiku, prunes duplicates and stale memories from `~/.claude/projects/*/memory/`.

## Integration

- **Hook framework**: Invoked by `claude` CLI's hook system; communicates via JSON on stdin/stdout.
- **Git integration**: `auto-update-codemaps.py`, `block-protected-push.sh`, `auto-observe.sh` call `git diff-tree`, `git branch`, `git log`, `git rev-parse`.
- **Config system**: Scripts source `load-config.sh` for `LEAN_FLOW_*` environment variables (protected branches, dream gates, monitor enable).
- **Knowledge system**: `auto-observe.sh` and `auto-dream.sh` read/write `~/.claude/knowledge/patterns.db` and `~/.claude/projects/*/memory/`.
- **Cartographer**: `ensure-cartography.sh` invokes `cartographer.py` to detect changed dirs and verify codemap state.
- **macOS ecosystem**: `ensure-claude-monitor.sh` installs SwiftBar plugin, launchd agent, and fetcher for API usage tracking.
