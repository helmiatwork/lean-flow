# plugin/scripts/

## Responsibility

**plugin/scripts/** houses Git hooks, session lifecycle scripts, and automation plugins that enforce workflow constraints, optimize token usage, and consolidate project memory. It bridges Claude Code's tool execution with local repository state management and decision gates.

## Design

- **Hook-based architecture**: PreToolUse/PostToolUse/SessionStart/SessionStop scripts intercept tool calls and session events to enforce rules or optimize output
- **Dual-gate patterns**: `auto-dream.sh` uses both session count and time elapsed; `block-protected-push.sh` matches ref patterns precisely to avoid false positives
- **Stateless execution with minimal I/O**: Scripts read stdin JSON, emit JSON to stdout, exit with code 0 (pass), 2 (block), or skip silently
- **External tool delegation**: `auto-compress-output.sh` runs commands directly and summarizes via haiku-3.5; `auto-update-codemaps.py` calls Claude API with OAuth from macOS keychain
- **Pattern database**: `auto-observe.sh` writes session observations to `~/.claude/knowledge/patterns.db` (SQLite) for later memory consolidation by `auto-dream.sh`

## Flow

1. **SessionStart** → `check-dependencies.sh` audits required/recommended plugins; caches findings by hash to avoid repeat warnings
2. **SessionStop** → `auto-observe.sh` logs tool usage to patterns.db (silent, zero-cost); `auto-dream.sh` triggers memory consolidation if dual gates pass (N+ sessions AND N+ hours since last dream)
3. **PreToolUse** → `block-*.sh` scripts enforce guardrails (no protected-branch pushes, no secret files, no --no-verify); `auto-compress-output.sh` intercepts high-output commands (git log, test runs) and replaces with haiku summary
4. **PostToolUse** → `auto-update-codemaps.py` reads git diff-tree, updates codemap.md files; `delegate-task-retry.sh` parses Task tool errors and injects retry hints; `enforce-tdd.sh` reminds on implementation-without-test
5. **Post-commit** → `auto-update-codemaps.sh` wrapper invokes the Python codemap updater

## Integration

- **Settings** (`~/.claude/settings.json`): Hooks read `LEAN_FLOW_PROTECTED_BRANCHES`, `LEAN_FLOW_DREAM_SESSIONS`, `LEAN_FLOW_DREAM_HOURS` via `load-config.sh`
- **Auth**: `auto-update-codemaps.py` reads OAuth from macOS keychain (`security find-generic-password`) or `ANTHROPIC_API_KEY` env var
- **Memory system**: Feeds session observations and change logs to `~/.claude/knowledge/patterns.db` and `~/.claude/projects/*/memory/MEMORY.md`
- **Repository state**: Uses `git diff-tree`, `git branch`, `git rev-parse` to detect changed dirs and protected refs
- **subdirectory `claude-monitor/`**: Companion monitoring/alerting (status unclear from provided contents; likely session health metrics or hook diagnostics)
