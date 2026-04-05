# hooks/

## Responsibility

Claude Code lifecycle hooks. Handles session initialization (ensure MCP servers, plugins, permissions) and safety guards (block secret commits, prevent wrong plan dir, block identity overrides, block --no-verify).

## Design

Single `hooks.json` declares all hook registrations for SessionStart, PreToolUse, and PostToolUse events. Safety guards are bash scripts that exit non-zero to block the triggering action. Setup scripts (ensure-*.sh) are idempotent — safe to re-run each session.

## Flow

Claude Code reads hooks.json on startup. SessionStart hooks run sequentially to bootstrap the environment. PreToolUse hooks intercept Bash/Write/Edit tool calls and inspect arguments for secrets, protected branches, or disallowed flags before execution proceeds.

## Integration

Hooks reference `${CLAUDE_PLUGIN_ROOT}/scripts/` for the actual implementations. Registered in `~/.claude/settings.json` via the lean-flow install process. Scripts depend on standard CLI tools (git, jq, grep) — no external dependencies.
