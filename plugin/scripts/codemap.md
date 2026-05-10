# plugin/scripts/

## Responsibility

`plugin/scripts/` contains **PreToolUse/PostToolUse hooks** that intercept and shape Claude's tool execution. Hooks gate dangerous operations (protected branch pushes, secret commits), auto-compress large outputs, enforce project conventions (branch naming, plan storage), consolidate memory on session stop, and update codemaps after commits. They also detect and guide recovery from Task delegation failures.

## Design

**Hook-per-concern pattern**: Each script is a single, focused PreToolUse or PostToolUse handler (e.g., `block-protected-push.sh`, `auto-compress-output.sh`). Most read stdin JSON, apply regex/jq filters to the command or response, and emit JSON control decisions (`exit 0` = allow, `exit 2` = block, `exit 1` = escalate).

**Utility scripts** (`check-dependencies.sh`, `cartographer.py`, `auto-update-codemaps.py`) run at SessionStart or post-commit to audit setup and sync documentation. **Memory consolidation** (`auto-dream.sh`, `auto-dream-prompt.md`) uses dual gating (session count + time elapsed) to batch pattern cleanup without token waste.

**Config injection**: Most hooks source `load-config.sh` for settings like `LEAN_FLOW_PROTECTED_BRANCHES`, `LEAN_FLOW_DREAM_SESSIONS`, avoiding hardcoded values.

## Flow

1. **PreToolUse hooks** (enforce-branch-naming, block-*) intercept commands before execution, emit block/allow decisions or guidance.
2. **auto-compress-output** (PreToolUse) detects high-output Bash commands (git log, pytest, find), runs them directly, summarizes large output via Haiku, returns compressed result.
3. **PostToolUse hooks** (delegate-task-retry, auto-update-codemaps) fire after tool completion: detect errors (Task param validation, git issues), append corrective hints, update docs on commit.
4. **SessionStart** (check-dependencies) audits required/recommended tools (jq, superpowers, omni, GitNexus) and emits install guidance.
5. **SessionStop** (auto-dream.sh) checks dual gates (N+ sessions AND N+ hours), runs memory consolidation in background via Haiku for pruning patterns.db and MEMORY.md.

## Integration

- **Settings**: Hooks read `~/.claude/settings.json` (permissions) and `~/.claude.json` (MCP servers); `check-dependencies.sh` validates wiring.
- **Git workflow**: Hooks enforce naming (`enforce-branch-naming`), block unsafe operations (`block-protected-push`, `block-no-verify`, `block-secret-commits`), and trigger codemap updates (`auto-update-codemaps.py` via PostToolUse on commit).
- **Memory system**: `auto-dream.sh` manages `~/.claude/patterns.db` and `MEMORY.md` via Haiku consolidation. `auto-observe.sh` (PostToolUse, SessionStop) captures session patterns.
- **Subdirectories**: `claude-monitor/` and `project-doctor/` contain related monitoring/repair tooling (not detailed in this codemap).
- **cartographer.py**: Standalone tool for repo mapping; used by codemaps workflow to track file hashes and detect changes.
