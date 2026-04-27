# plugin/scripts/

## Responsibility

`plugin/scripts/` contains pre/post-tool-use hooks and session lifecycle handlers that enforce project standards, optimize Claude's token usage, and maintain codebase documentation. Hooks intercept git operations (blocking unsafe patterns), compress verbose output, validate TDD practices, and auto-update codemaps. Session hooks consolidate memory, track patterns, and ensure cartography state is current.

## Design

- **Hook pattern**: Bash scripts read JSON from stdin, decide to block/allow/augment via exit code + JSON output
- **Config-driven**: Core scripts source `load-config.sh` for gate thresholds (LEAN_FLOW_PROTECTED_BRANCHES, LEAN_FLOW_DREAM_SESSIONS, etc.)
- **Safety-first gates**: Multi-layer checks (e.g., auto-dream requires both N sessions AND N hours elapsed) prevent accidental data loss
- **Async background tasks**: auto-dream, auto-observe, ensure-claude-monitor run backgrounded with lock files to avoid concurrent execution
- **Python fallback**: cartographer.py and auto-update-codemaps.py handle complex logic (file traversal, API calls, DB updates); Bash wrappers detect env and delegate

## Flow

1. **PreToolUse hooks** (auto-compress-output, block-*.sh): intercept tool calls, validate command safety, compress large output via haiku, block dangerous patterns (--no-verify, protected branch pushes, .env staging)
2. **PostToolUse hooks** (auto-update-codemaps, enforce-tdd): fire after Write/Edit/Bash, update documentation, remind on untested code
3. **SessionStart**: ensure-cartography checks if mapping is stale; ensure-claude-monitor installs SwiftBar plugin if missing
4. **SessionStop**: auto-dream checks dual gates (sessions + hours), runs memory consolidation in background, increments session counter
5. **Continuous observation**: auto-observe captures session logs to patterns.db (zero-token, async)

## Integration

- **Git hooks**: auto-update-codemaps listens for commits, extracts changed dirs via `git diff-tree`, regenerates codemap.md per dir
- **Cartographer state** (.slim/cartography.json): tracked by ensure-cartography; cartographer.py compares file hashes to detect changes
- **Memory system** (~/.claude/dream-state, ~/.claude/knowledge/patterns.db): auto-dream consolidates per auto-dream-prompt.md; auto-observe writes observations
- **Claude CLI**: auto-dream, ensure-claude-monitor, auto-compress-output invoke `claude` binary with --model and tool constraints
- **Config inheritance**: all scripts check CLAUDE_PLUGIN_ROOT env var to locate peer files (prompts, cartographer.py, load-config.sh)
- **macOS keychain integration** (auto-update-codemaps.py): fetches API token from secure storage; falls back to ANTHROPIC_API_KEY env var
