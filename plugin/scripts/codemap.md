# plugin/scripts/

## Responsibility

`plugin/scripts/` contains git hooks, automation triggers, and workflow enforcement rules that run at key lifecycle points (SessionStart, PreToolUse, PostToolUse, git events). These scripts gate risky operations, optimize token usage, consolidate memory, auto-update documentation, and guide users toward TDD/planning patterns. They act as guardrails and efficiency multipliers without requiring explicit user action.

## Design

**Hook-triggered architecture**: Each script is a standalone bash/Python executable matching Claude Code's hook event model (SessionStart, PreToolUse, PostToolUse, git hooks). Scripts read JSON stdin, emit JSON stdout, use exit codes to signal decisions (0=pass, 1=error, 2=block).

**Token optimization**: `auto-compress-output.sh` intercepts high-output commands (git log, test runs, grep), executes them directly, and summarizes large output via Haiku API. `auto-observe.sh` silently logs session patterns to SQLite without API calls.

**Memory/doc automation**: `auto-dream.sh` triggers memory consolidation (via `auto-dream-prompt.md`) using dual gates (N sessions + N hours). `auto-update-codemaps.py` reads changed directories from git diff-tree, indexes file contents, and calls Claude API to regenerate codemap.md sections.

**Permission/safety blocks**: `block-*.sh` scripts enforce policy (no --no-verify flags, no direct pushes to protected branches, no secret files staged, no Claude identity in commits). `enforce-tdd.sh` reminds users to write tests after implementation.

**Cartography & change detection**: `cartographer.py` manages repository state snapshots (.slim/cartography.json) for tracking which directories changed, enabling granular codemap updates.

## Flow

1. **SessionStart**: `check-dependencies.sh` audits missing plugins/tools; emits systemMessage with install hints (cached by dep-key hash).
2. **PreToolUse**: Bash commands route through `auto-compress-output.sh` (intercept high-output, execute, compress); `block-*.sh` rules check for forbidden patterns (secrets, --no-verify, protected branch pushes).
3. **PostToolUse**: `delegate-task-retry.sh` detects Task tool failures and appends retry hints; `enforce-tdd.sh` reminds on implementation without tests; `auto-observe.sh` logs session events to patterns.db.
4. **Git commit/push**: `auto-update-codemaps.py` (invoked by `auto-update-codemaps.sh`) reads changed dirs, generates new codemap sections.
5. **Session stop**: `auto-dream.sh` checks dual gates (time elapsed + session count), triggers memory consolidation in background with 5-min timeout.

## Integration

- **Claude Code settings** (`~/.claude/settings.json`): `block-*.sh` hooks registered in permissions model; `check-dependencies.sh` reads to validate plugin/tool setup.
- **Knowledge system**: `auto-observe.sh` writes to `~/.claude/knowledge/patterns.db` (SQLite); `auto-dream.sh` reads from `~/.claude/dream-state/` and consolidates memory files.
- **Git workflow**: Hooks called via git config post-commit, pre-push (installed by ensure-* bootstrap); `cartographer.py` reads .gitignore and git metadata.
- **Claude API**: `auto-compress-output.sh
