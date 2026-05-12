# plugin/scripts/

## Responsibility

`plugin/scripts/` contains hook handlers and automation scripts that gate, enhance, and consolidate Claude's tool use during sessions. These run as PreToolUse (block/transform commands), PostToolUse (inject guidance), and SessionStart/Stop (bootstrap/memory). The scripts enforce lean-flow rules (branch naming, PR templates, TDD), compress verbose output, intercept common errors, and maintain codebase documentation and pattern memory.

## Design

**Hook-based middleware pattern**: Each script targets a specific Claude hook (`PreToolUse` on Bash/Task/Write, `PostToolUse`, `SessionStart`, `SessionStop`) and reads structured JSON from stdin, outputting either pass-through JSON or a decision object (`{"decision":"block"}` or `hookSpecificOutput`).

**Token-aware**: `auto-compress-output.sh` detects high-output commands (git log, test runs) and summarizes via haiku instead of raw logs. `compact-nudge.js` reads context metrics and reminds at 30% threshold. `auto-observe.sh` captures session patterns to SQLite patterns.db without blocking.

**Config-driven opt-out**: Guards like `bash-guard.sh` and most hooks respect `LEAN_FLOW_*_DISABLED` env vars so users can selectively disable checks. Configuration loaded from `load-config.sh`.

**Error recovery**: `delegate-task-retry.sh` pattern-matches Task tool failures and emits actionable retry hints. `enforce-tdd.sh` injects test-driven workflow reminders when implementation files are written without tests.

## Flow

1. **PreToolUse (Bash)**: `bash-guard.sh` → blocks --no-verify, protected branch pushes, secret files, Claude identity in commits. `enforce-branch-naming.sh` validates branch names match `feature/|fix/|...` prefix. `block-wrong-plan-dir.sh` rejects plan saves to `docs/superpowers/plans/`.

2. **Tool execution**: Commands run (unblocked or transformed).

3. **PostToolUse**: `auto-compress-output.sh` (PreToolUse intercept) runs high-output commands directly, compresses summaries. `delegate-task-retry.sh` catches Task errors, appends fix hints. `enforce-tdd.sh` detects implementation writes without tests, injects TDD workflow reminder. `compact-nudge.js` fires at 30% context usage.

4. **SessionStart**: `check-dependencies.sh` audits required/recommended plugins (superpowers, jq, omni, gitnexus, rtk, knowledge-mcp), emits actionable system message once per session (cached by hash).

5. **SessionStop**: `auto-dream.sh` (dual-gated by sessions & hours) triggers memory consolidation via `auto-dream-prompt.md`, delegating to Claude in background with Haiku model and 300s timeout. `auto-observe.sh` silently captures session activity pattern to patterns.db.

6. **Git hooks** (via auto-commits): `auto-update-codemaps.py` reads changed directories from `git diff-tree HEAD`, generates codemap sections via Claude API, updates `codemap.md` files in affected dirs. `cartographer.py` initializes/tracks file hashes for change detection.

## Integration

- **Settings**: Hooks read `~/.claude/settings.json`, `~/.claude.json` for plugin & MCP server
